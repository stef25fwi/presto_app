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

  final ImagePicker _picker = ImagePicker();

  bool _isUploading = false;

  Future<void> _pickAndUploadImages() async {
    if (_isUploading) return;

    final files = await _picker.pickMultiImage(imageQuality: 92);

    if (files.isEmpty) return;

    setState(() {
      _isUploading = true;
    });

    try {
      for (final file in files) {
        await AdPlaceholderImageService.uploadImage(
          file: file,
          target: _target,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            files.length == 1
                ? 'Image ajoutée aux placeholders.'
                : '${files.length} images ajoutées aux placeholders.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur pendant l'ajout : $error"),
          backgroundColor: Colors.red,
        ),
      );
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image supprimée.')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Suppression impossible : $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFFF6600);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Gestion images placeholders'),
        backgroundColor: orange,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: orange,
        foregroundColor: Colors.white,
        onPressed: _isUploading ? null : _pickAndUploadImages,
        icon: _isUploading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.add_photo_alternate_outlined),
        label:
            Text(_isUploading ? 'Conversion...' : 'Ajouter + convertir WebP'),
      ),
      body: StreamBuilder<List<AdPlaceholderImage>>(
        stream: AdPlaceholderImageService.watchAll(target: _target),
        builder: (context, snapshot) {
          final images = snapshot.data ?? <AdPlaceholderImage>[];
          final visibleCount = images.where((image) => image.isVisible).length;

          if (snapshot.connectionState == ConnectionState.waiting &&
              images.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Card(
                elevation: 0,
                color: const Color(0xFFFFF3EA),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.image_search_outlined,
                        color: orange,
                        size: 30,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Ces images alimentent les placeholders AdBanner de la page “Je consulte”. "
                          "Format conseillé : image horizontale, idéalement en WebP, largeur idéale 1920 px, minimum 1600 px, ratio recommandé 16:9, poids cible inférieur à 450 Ko. "
                          "WebP est conseillé pour les meilleures performances. Pour éviter l'erreur build web, la conversion client automatique est désactivée : ajoute directement une image WebP si possible. "
                          "Les images activées sont visibles dans le carrousel. "
                          "S'il n'y a aucune image active ici, l'application utilise les images embarquées comme fallback.",
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '$visibleCount image(s) active(s) sur ${images.length}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 12),
              if (images.isEmpty)
                const _EmptyPlaceholderAdminState()
              else
                ...images.map(
                  (image) => _AdminPlaceholderImageCard(
                    image: image,
                    onVisibilityChanged: (value) =>
                        AdPlaceholderImageService.setVisible(
                      id: image.id,
                      isVisible: value,
                    ),
                    onDelete: () => _confirmDelete(image),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

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
              'Aucune image admin pour le moment.',
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

class _AdminPlaceholderImageCard extends StatelessWidget {
  const _AdminPlaceholderImageCard({
    required this.image,
    required this.onVisibilityChanged,
    required this.onDelete,
  });

  final AdPlaceholderImage image;
  final ValueChanged<bool> onVisibilityChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: image.isVisible
              ? const Color(0xFFFF6600).withValues(alpha: 0.35)
              : Colors.grey.shade300,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.network(
              image.imageUrl,
              fit: BoxFit.contain,
              alignment: Alignment.center,
              errorBuilder: (_, __, ___) => const ColoredBox(
                color: Color(0xFFF2F4F7),
                child: Center(
                  child: Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
          ),
          ListTile(
            title: Text(
              image.isVisible ? 'Visible dans les AdBanner' : 'Masquée',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: const Text('Page concernée : Je consulte'),
            leading: Switch(
              value: image.isVisible,
              onChanged: onVisibilityChanged,
            ),
            trailing: IconButton(
              tooltip: 'Supprimer',
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: onDelete,
            ),
          ),
        ],
      ),
    );
  }
}
