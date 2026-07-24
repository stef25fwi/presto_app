import 'dart:async';
import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../features/admin_videomaker/video_maker_models.dart';
import '../features/admin_videomaker/video_maker_page_operations.dart';
import '../features/admin_videomaker/video_maker_widgets.dart';
import '../utils/friendly_snackbar.dart';

class AdminVideoMakerPage extends StatefulWidget {
  final VideoMakerVideosLoader? loadVideos;
  final VideoMakerGenerator? generateVideo;
  final VideoMakerImagePicker? pickImage;
  final VideoMakerVideoOpener? openVideo;
  final VideoMakerVideoSharer? shareVideo;
  final VideoMakerVideoDeleter? deleteVideo;

  const AdminVideoMakerPage({
    super.key,
    this.loadVideos,
    this.generateVideo,
    this.pickImage,
    this.openVideo,
    this.shareVideo,
    this.deleteVideo,
  });

  @override
  State<AdminVideoMakerPage> createState() => _AdminVideoMakerPageState();
}

class _AdminVideoMakerPageState extends State<AdminVideoMakerPage> {
  final _apiKeyController = TextEditingController();
  final _promptController = TextEditingController();
  final _imagePicker = ImagePicker();
  final Set<String> _sharingVideoIds = <String>{};
  final Set<String> _deletingVideoIds = <String>{};

  List<GeneratedVideo> _videos = const [];
  final List<VideoMakerSelectedImage> _images = <VideoMakerSelectedImage>[];
  String _aspectRatio = '9:16';
  bool _hideApiKey = true;
  bool _generating = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadVideos());
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final selected = await (widget.pickImage?.call() ??
          pickVideoMakerImagesFromGallery(_imagePicker));
      if (selected.isEmpty) return;

      final available = maxVideoMakerReferenceImages - _images.length;
      if (available <= 0) {
        throw const FormatException(
          'Vous pouvez ajouter au maximum 3 images de référence.',
        );
      }

      final accepted = <VideoMakerSelectedImage>[];
      for (final image in selected.take(available)) {
        if (image.bytes.isEmpty || image.bytes.length > maxVideoMakerImageBytes) {
          throw FormatException(
            '${image.name} doit être valide et peser moins de 5 Mo.',
          );
        }
        if (!supportedVideoMakerImageMimeTypes.contains(image.mimeType)) {
          throw FormatException(
            '${image.name} : utilisez JPG, PNG, WEBP, HEIC ou HEIF.',
          );
        }
        accepted.add(image);
      }

      if (!mounted) return;
      setState(() => _images.addAll(accepted));
      if (selected.length > available) {
        showPrestoSnackBar(
          context,
          'Seules les $available premières images ont été ajoutées.',
        );
      }
    } on FormatException catch (error) {
      if (mounted) showErrorSnackBar(context, error.message);
    } catch (_) {
      if (mounted) {
        showErrorSnackBar(context, 'Impossible de sélectionner ces images.');
      }
    }
  }

  void _removeImage(int index) {
    if (index < 0 || index >= _images.length) return;
    setState(() => _images.removeAt(index));
  }

  Future<void> _generateVideo() async {
    if (_generating) return;
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      showErrorSnackBar(context, 'Ajoutez un prompt avant de générer.');
      return;
    }
    if (prompt.length > 4000) {
      showErrorSnackBar(
        context,
        'Le prompt ne doit pas dépasser 4 000 caractères.',
      );
      return;
    }

    setState(() => _generating = true);
    try {
      final apiKey = _apiKeyController.text.trim();
      final parameters = <String, Object?>{
        'prompt': prompt,
        'model': 'veo-3.1-generate-preview',
        'aspectRatio': _aspectRatio,
        'durationSeconds': '8',
        'resolution': '720p',
        if (apiKey.isNotEmpty) 'apiKey': apiKey,
        if (_images.isNotEmpty)
          'referenceImages': _images
              .map(
                (image) => <String, Object?>{
                  'base64': base64Encode(image.bytes),
                  'mimeType': image.mimeType,
                  'name': image.name,
                },
              )
              .toList(growable: false),
      };
      await (widget.generateVideo?.call(parameters) ??
          generateVideoWithFunctions(parameters));
      if (!mounted) return;
      showSuccessSnackBar(
        context,
        'Vidéo VEO générée et enregistrée dans la bibliothèque.',
      );
      setState(() => _images.clear());
      await _loadVideos(showFailure: false);
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        showErrorSnackBar(context, friendlyVideoMakerFunctionError(error));
      }
    } catch (_) {
      if (mounted) {
        showErrorSnackBar(
          context,
          'La génération a échoué. Vérifiez la clé API et réessayez.',
        );
      }
    } finally {
      _apiKeyController.clear();
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _loadVideos({bool showFailure = true}) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final videos = await (widget.loadVideos?.call() ?? loadVideosWithFunctions());
      if (mounted) setState(() => _videos = videos);
    } on FirebaseFunctionsException catch (error) {
      if (mounted && showFailure) {
        showErrorSnackBar(context, friendlyVideoMakerFunctionError(error));
      }
    } catch (_) {
      if (mounted && showFailure) {
        showErrorSnackBar(
          context,
          'Impossible de charger la bibliothèque de vidéos.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _downloadVideo(GeneratedVideo video) async {
    final uri = Uri.tryParse(video.publicUrl ?? '');
    final opened = uri != null &&
        await (widget.openVideo?.call(uri) ?? openGeneratedVideo(uri));
    if (!opened && mounted) {
      showErrorSnackBar(context, 'Impossible d’ouvrir cette vidéo.');
    }
  }

  Future<void> _shareVideo(GeneratedVideo video) async {
    final url = video.publicUrl;
    if (url == null || url.isEmpty) {
      showErrorSnackBar(
        context,
        'La vidéo ne possède pas encore de lien partageable.',
      );
      return;
    }
    if (!_sharingVideoIds.add(video.id)) return;

    final box = context.findRenderObject() as RenderBox?;
    final shareOrigin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    try {
      final attached = await (widget.shareVideo?.call(video, shareOrigin) ??
          shareGeneratedVideo(video, shareOrigin));
      if (!attached && mounted) {
        showPrestoSnackBar(
          context,
          'Le fichier n’a pas pu être joint : le lien vidéo a été partagé.',
        );
      }
    } finally {
      _sharingVideoIds.remove(video.id);
    }
  }

  Future<void> _deleteVideo(GeneratedVideo video) async {
    if (_deletingVideoIds.contains(video.id)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer cette vidéo ?'),
        content: const Text(
          'La vidéo sera supprimée de la bibliothèque, de Firestore et de Firebase Storage. Cette action est définitive.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    _deletingVideoIds.add(video.id);
    try {
      await (widget.deleteVideo?.call(video.id) ??
          deleteVideoWithFunctions(video.id));
      if (!mounted) return;
      setState(() {
        _videos = _videos.where((item) => item.id != video.id).toList();
      });
      showSuccessSnackBar(context, 'Vidéo supprimée de la bibliothèque.');
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        showErrorSnackBar(context, friendlyVideoMakerFunctionError(error));
      }
    } catch (_) {
      if (mounted) {
        showErrorSnackBar(context, 'Impossible de supprimer cette vidéo.');
      }
    } finally {
      _deletingVideoIds.remove(video.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: videoMakerBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: videoMakerBlue,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Videomaker',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualiser la bibliothèque',
            onPressed: _loading ? null : () => _loadVideos(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadVideos(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 36),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    VideoMakerGeneratorCard(
                      apiKeyController: _apiKeyController,
                      promptController: _promptController,
                      hideApiKey: _hideApiKey,
                      generating: _generating,
                      aspectRatio: _aspectRatio,
                      images: List.unmodifiable(_images),
                      onToggleApiKey: () {
                        setState(() => _hideApiKey = !_hideApiKey);
                      },
                      onAspectRatioChanged: (value) {
                        setState(() => _aspectRatio = value);
                      },
                      onPickImages: _generating ? null : _pickImages,
                      onRemoveImage: _generating ? null : _removeImage,
                      onGenerate: _generating ? null : _generateVideo,
                    ),
                    const SizedBox(height: 20),
                    VideoMakerLibrary(
                      videos: _videos,
                      loading: _loading,
                      onDownload: _downloadVideo,
                      onShare: _shareVideo,
                      onDelete: _deleteVideo,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
