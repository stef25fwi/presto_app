import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

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

  const AdminVideoMakerPage({
    super.key,
    this.loadVideos,
    this.generateVideo,
    this.pickImage,
    this.openVideo,
    this.shareVideo,
  });

  @override
  State<AdminVideoMakerPage> createState() => _AdminVideoMakerPageState();
}

class _AdminVideoMakerPageState extends State<AdminVideoMakerPage> {
  final _apiKeyController = TextEditingController();
  final _promptController = TextEditingController();
  final _imagePicker = ImagePicker();
  final Set<String> _sharingVideoIds = <String>{};

  List<GeneratedVideo> _videos = const [];
  Uint8List? _imageBytes;
  String? _imageName;
  String? _imageMimeType;
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

  Future<void> _pickImage() async {
    try {
      final image = await (widget.pickImage?.call() ??
          pickVideoMakerImageFromGallery(_imagePicker));
      if (image == null) return;

      final bytes = image.bytes;
      if (bytes.isEmpty || bytes.length > maxVideoMakerImageBytes) {
        throw const FormatException(
          'L’image doit être valide et peser moins de 5 Mo.',
        );
      }
      final mimeType = image.mimeType;
      if (!supportedVideoMakerImageMimeTypes.contains(mimeType)) {
        throw const FormatException(
          'Utilisez une image JPG, PNG, WEBP, HEIC ou HEIF.',
        );
      }
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _imageName = image.name;
        _imageMimeType = mimeType;
      });
    } on FormatException catch (error) {
      if (mounted) {
        showErrorSnackBar(context, error.message);
      }
    } catch (_) {
      if (mounted) {
        showErrorSnackBar(context, 'Impossible de sélectionner cette image.');
      }
    }
  }

  void _removeImage() {
    setState(() {
      _imageBytes = null;
      _imageName = null;
      _imageMimeType = null;
    });
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
      final imageBytes = _imageBytes;
      final parameters = <String, Object?>{
        'prompt': prompt,
        'model': 'veo-3.1-generate-preview',
        'aspectRatio': _aspectRatio,
        'durationSeconds': '8',
        'resolution': '720p',
        if (apiKey.isNotEmpty) 'apiKey': apiKey,
        if (imageBytes != null) 'imageBase64': base64Encode(imageBytes),
        if (_imageMimeType != null) 'imageMimeType': _imageMimeType,
      };
      await (widget.generateVideo?.call(parameters) ??
          generateVideoWithFunctions(parameters));
      if (!mounted) return;
      showSuccessSnackBar(
        context,
        'Vidéo VEO générée et ajoutée à la bibliothèque.',
      );
      await _loadVideos(showFailure: false);
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        showErrorSnackBar(
          context,
          friendlyVideoMakerFunctionError(error),
        );
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
      if (mounted) {
        setState(() => _generating = false);
      }
    }
  }

  Future<void> _loadVideos({bool showFailure = true}) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final videos = await (widget.loadVideos?.call() ??
          loadVideosWithFunctions());
      if (mounted) {
        setState(() => _videos = videos);
      }
    } catch (_) {
      if (mounted && showFailure) {
        showErrorSnackBar(
          context,
          'Impossible de charger la bibliothèque de vidéos.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
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
            tooltip: 'Actualiser',
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
                      imageBytes: _imageBytes,
                      imageName: _imageName,
                      onToggleApiKey: () {
                        setState(() => _hideApiKey = !_hideApiKey);
                      },
                      onAspectRatioChanged: (value) {
                        setState(() => _aspectRatio = value);
                      },
                      onPickImage: _generating ? null : _pickImage,
                      onRemoveImage: _generating ? null : _removeImage,
                      onGenerate: _generating ? null : _generateVideo,
                    ),
                    const SizedBox(height: 20),
                    VideoMakerLibrary(
                      videos: _videos,
                      loading: _loading,
                      onDownload: _downloadVideo,
                      onShare: _shareVideo,
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
