import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:presto_app/services/ad_placeholder_image_service.dart';

class AdPlaceholderImagesAdminPage extends StatefulWidget {
  const AdPlaceholderImagesAdminPage({super.key});

  @override
  State<AdPlaceholderImagesAdminPage> createState() =>
      _AdPlaceholderImagesAdminPageState();
}

class _AdPlaceholderImagesAdminPageState
    extends State<AdPlaceholderImagesAdminPage> {
  static const String _target = 'consult_offers';
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
        title: Text(_isReordering
            ? 'Réorganiser les images'
            : 'Gestion images placeholders'),
        backgroundColor: const Color(0xFF1A73E8),
        foregroundColor: Colors.white,
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
                    child: const Text('Enregistrer',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                ],
              ]
            : null,
      ),
      floatingActionButton: _isReordering
          ? null
          : FloatingActionButton.extended(
              backgroundColor: _orange,
              foregroundColor: Colors.white,
              onPressed: _isUploading ? null : _pickAndUploadImages,
              icon: _isUploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.add_photo_alternate_outlined),
              label: Text(_isUploading ? 'Upload...' : 'Ajouter'),
            ),
      body: StreamBuilder<List<AdPlaceholderImage>>(
        stream: AdPlaceholderImageService.watchAll(target: _target),
        builder: (context, snapshot) {
          // En mode réordre on utilise le buffer local, pas le stream.
          final streamImages = snapshot.data ?? <AdPlaceholderImage>[];
          final images =
              _isReordering ? (_reorderBuffer ?? streamImages) : streamImages;

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
    );
  }

  Widget _buildGridView(
    BuildContext context,
    List<AdPlaceholderImage> images,
    int visibleCount,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
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
                    "Ces images alimentent les placeholders AdBanner de la page « Je consulte ». "
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
        if (_uploadPreviewBytes != null || _isUploading) ...[
          _SelectedAdPlaceholderPreview(
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
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$visibleCount image(s) active(s) sur ${images.length}',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Coche pour afficher · Appuie sur l\'image pour l\'agrandir',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.black54),
                  ),
                ],
              ),
            ),
            if (images.isNotEmpty)
              TextButton.icon(
                onPressed: () => _enterReorderMode(images),
                icon: const Icon(Icons.swap_vert_rounded, size: 18),
                label: const Text('Réorganiser'),
                style: TextButton.styleFrom(foregroundColor: _orange),
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
                    onTapImage: () => _openViewer(image.imageUrl),
                    onVisibilityChanged: (value) =>
                        AdPlaceholderImageService.setVisible(
                      id: image.id,
                      isVisible: value,
                    ),
                    onDelete: () => _confirmDelete(image),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  Widget _buildReorderList(List<AdPlaceholderImage> images) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
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

class _SelectedAdPlaceholderPreview extends StatelessWidget {
  const _SelectedAdPlaceholderPreview({
    required this.fileBytes,
    required this.fileName,
    required this.uploadProgress,
    required this.conversionProgress,
    required this.status,
    required this.isUploading,
    required this.currentIndex,
    required this.totalCount,
    required this.onClear,
  });

  final Uint8List? fileBytes;
  final String fileName;
  final double? uploadProgress;
  final double? conversionProgress;
  final String status;
  final bool isUploading;
  final int currentIndex;
  final int totalCount;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final bytes = fileBytes;
    final uploadValue = uploadProgress?.clamp(0.0, 1.0);
    final conversionValue = conversionProgress?.clamp(0.0, 1.0);
    final uploadPercent =
        uploadValue == null ? null : (uploadValue * 100).round();
    final title = totalCount > 1 && currentIndex > 0
        ? '$fileName · $currentIndex/$totalCount'
        : fileName;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 96,
              height: 68,
              child: bytes == null
                  ? const ColoredBox(
                      color: Color(0xFFFFF1E8),
                      child: Center(
                        child: Icon(
                          Icons.image_search_rounded,
                          color: Color(0xFFFF6600),
                        ),
                      ),
                    )
                  : Image.memory(
                      bytes,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) => const ColoredBox(
                        color: Color(0xFFFFF1E8),
                        child: Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: Color(0xFFFF6600),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  status.trim().isEmpty
                      ? 'Prévisualisation locale avant upload Firebase Storage'
                      : status,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                _PlaceholderProgressLine(
                  label: 'Conversion',
                  value: conversionValue,
                  color: const Color(0xFFFF6600),
                ),
                const SizedBox(height: 6),
                _PlaceholderProgressLine(
                  label: uploadPercent == null
                      ? 'Téléchargement'
                      : 'Téléchargement $uploadPercent %',
                  value: uploadValue,
                  color: const Color(0xFF1A73E8),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      isUploading
                          ? Icons.cloud_upload_outlined
                          : Icons.check_circle_rounded,
                      size: 16,
                      color: isUploading
                          ? const Color(0xFF1A73E8)
                          : const Color(0xFF16A34A),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isUploading
                            ? 'Traitement en cours…'
                            : 'Visualiseur prêt',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF1A73E8),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (onClear != null) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Masquer le visualiseur',
              onPressed: onClear,
              icon: const Icon(
                Icons.close_rounded,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlaceholderProgressLine extends StatelessWidget {
  const _PlaceholderProgressLine({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double? value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final normalized = value?.clamp(0.0, 1.0);

    return Row(
      children: [
        SizedBox(
          width: 104,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: normalized,
              backgroundColor: const Color(0xFFE5E7EB),
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Tile grille ──────────────────────────────────────────────────────────────

class _AdminPlaceholderImageTile extends StatelessWidget {
  const _AdminPlaceholderImageTile({
    required this.image,
    required this.onTapImage,
    required this.onVisibilityChanged,
    required this.onDelete,
  });

  final AdPlaceholderImage image;
  final VoidCallback onTapImage;
  final ValueChanged<bool> onVisibilityChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFFF6600);
    final selected = image.isVisible;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? orange : Colors.grey.shade300,
          width: selected ? 2.5 : 1,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Image — tap pour viewer
          GestureDetector(
            onTap: onTapImage,
            child: Image.network(
              image.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const ColoredBox(
                color: Color(0xFFF2F4F7),
                child: Center(child: Icon(Icons.broken_image_outlined)),
              ),
            ),
          ),
          // Voile pour images masquées
          if (!selected) Container(color: Colors.white.withValues(alpha: 0.5)),
          // Icône zoom (centre)
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
          // Checkbox visibilité (haut droite)
          Positioned(
            top: 6,
            right: 6,
            child: GestureDetector(
              onTap: () => onVisibilityChanged(!selected),
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: selected ? orange : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? orange : Colors.grey.shade400,
                    width: 2,
                  ),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 4),
                  ],
                ),
                child: selected
                    ? const Icon(Icons.check, size: 18, color: Colors.white)
                    : null,
              ),
            ),
          ),
          // Bouton supprimer (bas droite)
          Positioned(
            bottom: 4,
            right: 4,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: IconButton(
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                tooltip: 'Supprimer',
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: onDelete,
              ),
            ),
          ),
          // Badge état (bas gauche)
          Positioned(
            left: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                selected ? 'Affichée' : 'Masquée',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tile liste de réordre ────────────────────────────────────────────────────

class _ReorderTile extends StatelessWidget {
  const _ReorderTile({
    super.key,
    required this.image,
    required this.index,
    required this.onTapImage,
  });

  final AdPlaceholderImage image;
  final int index;
  final VoidCallback onTapImage;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // Poignée drag
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child:
                Icon(Icons.drag_handle_rounded, color: Colors.grey, size: 26),
          ),
          // Aperçu image
          GestureDetector(
            onTap: onTapImage,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 72,
                height: 50,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      image.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const ColoredBox(
                        color: Color(0xFFF2F4F7),
                        child: Icon(Icons.broken_image_outlined, size: 20),
                      ),
                    ),
                    const Center(
                      child: Icon(Icons.zoom_in_rounded,
                          color: Colors.white70, size: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Numéro d'ordre + état
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Position ${index + 1}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: image.isVisible
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    image.isVisible ? 'Affichée' : 'Masquée',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: image.isVisible
                          ? Colors.green.shade700
                          : Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── État vide ────────────────────────────────────────────────────────────────

class _EmptyPlaceholderAdminState extends StatelessWidget {
  const _EmptyPlaceholderAdminState();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.collections_outlined, size: 44, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'Aucune image pour le moment.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 6),
            Text(
              'Ajoute des images avec le bouton en bas à droite. '
              'En attendant, les images assets actuelles restent visibles.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
