import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:presto_app/services/ad_placeholder_image_service.dart';

part 'ad_placeholder_images/ad_placeholder_images_received_widgets.dart';
part 'ad_placeholder_images/ad_placeholder_images_preview_widgets.dart';
part 'ad_placeholder_images/ad_placeholder_images_grid_tile_widgets.dart';
part 'ad_placeholder_images/ad_placeholder_images_list_widgets.dart';

class AdPlaceholderImagesAdminPage extends StatefulWidget {
  const AdPlaceholderImagesAdminPage({super.key});

  @override
  State<AdPlaceholderImagesAdminPage> createState() =>
      _AdPlaceholderImagesAdminPageState();
}

class _AdPlaceholderImagesAdminPageState
    extends State<AdPlaceholderImagesAdminPage> {
  static const Map<String, String> _targets = {
    'consult_offers': 'Page Je consulte — placeholders annonces',
    'subscription_alerts_banner': 'Page abonnement — alertes nouvelle annonce',
  };
  String _target = 'consult_offers';
  static const _orange = Color(0xFFFF6600);

  final ImagePicker _picker = ImagePicker();

  bool _isUploading = false;
  bool _isReordering = false;
  bool _isSavingOrder = false;

  Uint8List? _uploadPreviewBytes;
  String? _uploadPreviewFileName;
  double? _uploadProgress;
  double? _conversionProgress;
  String _uploadStatus = '';
  int _currentUploadIndex = 0;
  int _totalUploadCount = 0;

  // Snapshot local pour le réordre (manipulé avant sauvegarde).
  List<AdPlaceholderImage>? _reorderBuffer;
  List<AdPlaceholderImage> _lastLoadedImages = const <AdPlaceholderImage>[];

  Future<void> _pickAndUploadImages() async {
    if (_isUploading) return;

    final files = await _picker.pickMultiImage(imageQuality: 92);
    if (files.isEmpty) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
      _conversionProgress = 0;
      _uploadStatus = 'Lecture du fichier sélectionné…';
      _currentUploadIndex = 0;
      _totalUploadCount = files.length;
    });

    try {
      for (var index = 0; index < files.length; index++) {
        final file = files[index];
        final bytes = await file.readAsBytes();

        if (!mounted) return;
        setState(() {
          _uploadPreviewBytes = bytes;
          _uploadPreviewFileName = file.name;
          _currentUploadIndex = index + 1;
          _conversionProgress = 0.45;
          _uploadProgress = 0;
          _uploadStatus =
              'Préparation de l’image ${index + 1}/${files.length}…';
        });

        if (!mounted) return;
        setState(() {
          _conversionProgress = 1;
          _uploadStatus =
              'Conversion vérifiée · upload Firebase Storage ${index + 1}/${files.length}…';
        });

        await AdPlaceholderImageService.uploadImage(
          file: file,
          target: _target,
          onUploadProgress: (progress) {
            if (!mounted) return;
            setState(() {
              _uploadProgress = progress;
              _uploadStatus =
                  'Téléchargement ${index + 1}/${files.length} · ${(progress * 100).round()} %';
            });
          },
        );
      }

      if (!mounted) return;
      setState(() {
        _uploadProgress = 1;
        _conversionProgress = 1;
        _uploadStatus = files.length == 1
            ? 'Terminé · image ajoutée aux placeholders.'
            : 'Terminé · ${files.length} images ajoutées aux placeholders.';
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(files.length == 1
            ? 'Image ajoutée aux placeholders.'
            : '${files.length} images ajoutées aux placeholders.'),
      ));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _uploadStatus = "Erreur pendant l'ajout : $error";
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Erreur pendant l'ajout : $error"),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _confirmDelete(AdPlaceholderImage image) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette image ?'),
        content: const Text(
          'Elle ne sera plus disponible dans les placeholders AdBanner.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await AdPlaceholderImageService.deleteImage(image);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Image supprimée.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Suppression impossible : $error'),
        backgroundColor: Colors.red,
      ));
    }
  }

  void _openViewer(String imageUrl) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 6,
              child: Center(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white,
                    size: 64,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEditSlideDialog(AdPlaceholderImage image) async {
    final titleController = TextEditingController(text: image.title ?? '');
    final descriptionController =
        TextEditingController(text: image.description ?? '');
    final linkUrlController = TextEditingController(text: image.linkUrl ?? '');

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Modifier le slide'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Aperçu image actuelle
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 120,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          image.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const ColoredBox(
                            color: Color(0xFFF2F4F7),
                            child: Center(
                                child: Icon(Icons.broken_image_outlined)),
                          ),
                        ),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black38,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.zoom_in_rounded,
                                color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Bouton remplacer image
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _replaceSlideImage(image).then((_) {
                      if (mounted) Navigator.pop(context);
                    }),
                    icon: const Icon(Icons.image_search_outlined, size: 18),
                    label: const Text('Remplacer l\'image'),
                  ),
                ),
                const SizedBox(height: 16),
                // Titre
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Titre (optionnel)',
                    hintText: 'Ex: Travaux de maison',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  maxLines: 1,
                ),
                const SizedBox(height: 12),
                // Description
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Description (optionnel)',
                    hintText: 'Description courte du service',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                // URL de lien
                TextField(
                  controller: linkUrlController,
                  decoration: InputDecoration(
                    labelText: 'URL (optionnel)',
                    hintText: 'https://exemple.com',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  maxLines: 1,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _orange),
              onPressed: () async {
                try {
                  await AdPlaceholderImageService.updateSlideProperties(
                    id: image.id,
                    title: titleController.text,
                    description: descriptionController.text,
                    linkUrl: linkUrlController.text,
                  );
                  if (!mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Slide mis à jour.')),
                  );
                } catch (error) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erreur: $error'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );

    titleController.dispose();
    descriptionController.dispose();
    linkUrlController.dispose();
  }

  Future<void> _replaceSlideImage(AdPlaceholderImage image) async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
    );
    if (file == null) return;

    if (!mounted) return;

    bool isProcessing = false;
    double uploadProgress = 0;
    String uploadStatus = 'Préparation…';

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Remplacer l\'image'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isProcessing) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(value: uploadProgress),
                const SizedBox(height: 12),
                Text(
                  uploadStatus,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ] else ...[
                const Text('Êtes-vous sûr de vouloir remplacer cette image ?'),
              ],
            ],
          ),
          actions: [
            if (!isProcessing)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
            if (!isProcessing)
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _orange),
                onPressed: () async {
                  setState(() {
                    isProcessing = true;
                    uploadStatus = 'Téléchargement…';
                    uploadProgress = 0;
                  });

                  try {
                    await AdPlaceholderImageService.replaceSlideImage(
                      id: image.id,
                      currentImage: image,
                      newFile: file,
                      target: _target,
                      onUploadProgress: (progress) {
                        if (mounted) {
                          setState(() {
                            uploadProgress = progress;
                            uploadStatus =
                                'Téléchargement… ${(progress * 100).round()}%';
                          });
                        }
                      },
                    );

                    if (!mounted) return;
                    setState(() {
                      uploadStatus = 'Image remplacée !';
                      uploadProgress = 1;
                    });

                    await Future.delayed(const Duration(milliseconds: 500));
                    if (!mounted) return;
                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Image remplacée.')),
                    );
                  } catch (error) {
                    if (!mounted) return;
                    setState(() {
                      isProcessing = false;
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Erreur: $error'),
                        backgroundColor: Colors.red,
                      ),
                    );

                    if (!mounted) return;
                    Navigator.pop(context);
                  }
                },
                child: const Text('Confirmer'),
              ),
          ],
        ),
      ),
    );
  }

  void _enterReorderMode(List<AdPlaceholderImage> images) {
    setState(() {
      _isReordering = true;
      _reorderBuffer = List.of(images);
    });
  }

  Future<void> _saveReorder() async {
    final buffer = _reorderBuffer;
    if (buffer == null) return;
    setState(() => _isSavingOrder = true);
    try {
      await AdPlaceholderImageService.reorderImages(
        buffer.map((img) => img.id).toList(),
      );
      if (!mounted) return;
      setState(() {
        _isReordering = false;
        _reorderBuffer = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ordre sauvegardé.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur sauvegarde : $error'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _isSavingOrder = false);
    }
  }

  void _cancelReorder() {
    setState(() {
      _isReordering = false;
      _reorderBuffer = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
            _isReordering ? 'Réorganiser les images' : 'Gestion Placeholders'),
        backgroundColor: const Color(0xFF1A73E8),
        foregroundColor: Colors.white,
        elevation: 2,
        actions: _isReordering
            ? [
                if (_isSavingOrder)
                  const Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  )
                else ...[
                  TextButton(
                    onPressed: _cancelReorder,
                    child: const Text('Annuler',
                        style: TextStyle(color: Colors.white)),
                  ),
                  TextButton(
                    onPressed: _saveReorder,
                    child: const Text(
                      'Enregistrer',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ]
            : [],
      ),
      floatingActionButton: _isReordering
          ? null
          : FloatingActionButton.extended(
              onPressed: _isUploading ? null : _pickAndUploadImages,
              backgroundColor: _orange,
              foregroundColor: Colors.white,
              icon: _isUploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.add_photo_alternate_rounded),
              label: Text(
                _isUploading ? 'Upload en cours…' : 'Ajouter des images',
              ),
            ),
      body: Column(
        children: [
          if (!_isReordering)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: DropdownButtonFormField<String>(
                initialValue: _target,
                decoration: InputDecoration(
                  labelText: 'Emplacement de l’image',
                  prefixIcon: const Icon(Icons.web_asset_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                items: _targets.entries
                    .map(
                      (entry) => DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(),
                onChanged: _isUploading
                    ? null
                    : (value) {
                        if (value == null || value == _target) return;
                        setState(() {
                          _target = value;
                          _lastLoadedImages = const <AdPlaceholderImage>[];
                          _reorderBuffer = null;
                        });
                      },
              ),
            ),
          // Widget upload — toujours visible, indépendant de l'état Firestore
          if (_isUploading || _uploadPreviewBytes != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _SelectedAdPlaceholderPreview(
                fileBytes: _uploadPreviewBytes,
                fileName: _uploadPreviewFileName ?? 'Image placeholder',
                uploadProgress: _uploadProgress,
                conversionProgress: _conversionProgress,
                status: _uploadStatus,
                isUploading: _isUploading,
                currentIndex: _currentUploadIndex,
                totalCount: _totalUploadCount,
                onClear: _isUploading
                    ? null
                    : () {
                        setState(() {
                          _uploadPreviewBytes = null;
                          _uploadPreviewFileName = null;
                          _uploadProgress = null;
                          _conversionProgress = null;
                          _uploadStatus = '';
                          _currentUploadIndex = 0;
                          _totalUploadCount = 0;
                        });
                      },
              ),
            ),
          Expanded(
            child: StreamBuilder<List<AdPlaceholderImage>>(
              stream: AdPlaceholderImageService.watchAll(target: _target),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _buildErrorState(snapshot.error!);
                }

                final latestStreamImages =
                    snapshot.data ?? const <AdPlaceholderImage>[];
                if (latestStreamImages.isNotEmpty) {
                  _lastLoadedImages = latestStreamImages;
                }

                // En mode réordre on utilise le buffer local, pas le stream.
                final streamImages = latestStreamImages.isNotEmpty
                    ? latestStreamImages
                    : _lastLoadedImages;
                final images = _isReordering
                    ? (_reorderBuffer ?? streamImages)
                    : streamImages;

                final visibleCount =
                    streamImages.where((img) => img.isVisible).length;

                if (snapshot.connectionState == ConnectionState.waiting &&
                    streamImages.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                return _isReordering
                    ? _buildReorderList(images)
                    : _buildGridView(context, images, visibleCount);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 260),
      children: [
        _buildToolsChips(),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  color: Colors.red.shade600, size: 40),
              const SizedBox(height: 12),
              Text(
                'Erreur de chargement\n$error',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade700, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToolsChips() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: const [
          _PlaceholderToolChip(
            icon: Icons.add_photo_alternate_rounded,
            label: 'Ajouter image(s)',
          ),
          _PlaceholderToolChip(
            icon: Icons.edit_rounded,
            label: 'Modifier slide',
          ),
          _PlaceholderToolChip(
            icon: Icons.visibility_rounded,
            label: 'Afficher / masquer',
          ),
          _PlaceholderToolChip(
            icon: Icons.swap_vert_rounded,
            label: 'Réorganiser',
          ),
          _PlaceholderToolChip(
            icon: Icons.delete_rounded,
            label: 'Supprimer',
          ),
        ],
      ),
    );
  }

  Widget _buildGridView(
    BuildContext context,
    List<AdPlaceholderImage> images,
    int visibleCount,
  ) {
    final activeImages = images.where((img) => img.isVisible).toList();
    final spotlightImage = activeImages.isNotEmpty
        ? activeImages.first
        : images.isNotEmpty
            ? images.first
            : null;
    final activePositionById = <String, int>{
      for (var i = 0; i < activeImages.length; i++) activeImages[i].id: i + 1,
    };

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 260),
      children: [
        // Carte info
        Card(
          elevation: 0,
          color: const Color(0xFFFFF3EA),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.image_search_outlined,
                    color: _orange, size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _target == 'subscription_alerts_banner'
                        ? "Cette image remplace l’encart bleu de la section « Mes alertes Nouvelle annonce ». "
                            "Format conseillé : horizontal, ratio 16:7, 1600 px min."
                        : "Ces images alimentent les placeholders AdBanner de la page « Je consulte ». "
                            "Format conseillé : horizontale, WebP, 1920 px min, ratio 16:9, < 450 Ko. "
                            "S'il n'y a aucune image active, l'app utilise ses images embarquées.",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (spotlightImage != null) ...[
          _LatestPlaceholderReceivedCard(
            image: spotlightImage,
            totalCount: images.length,
            activeCount: visibleCount,
            onOpen: () => _openViewer(spotlightImage.imageUrl),
          ),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    visibleCount == 0
                        ? '⚠️  Aucune image active sur ${images.length}'
                        : visibleCount == 1
                            ? '✅ 1 image active sur ${images.length}'
                            : '✅ $visibleCount images actives sur ${images.length}',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  _buildToolsChips(),
                  const SizedBox(height: 12),
                  Text(
                    '✏️ Modifier · 👁️ Cocher pour afficher · 🔍 Zoom · 🗑️ Supprimer',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.black54, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            if (images.isNotEmpty)
              Tooltip(
                message: 'Réorganiser l\'ordre des images par glisser-déposer',
                child: FilledButton.icon(
                  onPressed: () => _enterReorderMode(images),
                  style: FilledButton.styleFrom(
                    backgroundColor: _orange,
                  ),
                  icon: const Icon(Icons.swap_vert_rounded, size: 18),
                  label: const Text('Réorganiser'),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (images.isEmpty)
          const _EmptyPlaceholderAdminState()
        else
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 16 / 11,
            children: images
                .map(
                  (image) => _AdminPlaceholderImageTile(
                    image: image,
                    activePosition: activePositionById[image.id],
                    activeTotal: visibleCount,
                    onTapImage: () => _openViewer(image.imageUrl),
                    onVisibilityChanged: (value) =>
                        AdPlaceholderImageService.setVisible(
                      id: image.id,
                      isVisible: value,
                    ),
                    onDelete: () => _confirmDelete(image),
                    onEdit: () => _openEditSlideDialog(image),
                  ),
                )
                .toList(),
          ),
        const SizedBox(height: 140),
      ],
    );
  }

  Widget _buildReorderList(List<AdPlaceholderImage> images) {
    return ReorderableListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 260),
      itemCount: images.length,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) newIndex--;
          final item = _reorderBuffer!.removeAt(oldIndex);
          _reorderBuffer!.insert(newIndex, item);
        });
      },
      itemBuilder: (context, index) {
        final image = images[index];
        return _ReorderTile(
          key: ValueKey(image.id),
          image: image,
          index: index,
          onTapImage: () => _openViewer(image.imageUrl),
        );
      },
    );
  }
}
