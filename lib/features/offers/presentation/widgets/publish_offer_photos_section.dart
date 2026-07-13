import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../widgets/photo_selector_tile.dart';

/// Section de sélection des photos de l'écran de publication.
///
/// Le widget reste purement présentational : la sélection, le remplacement et
/// la suppression des fichiers sont orchestrés par [PublishOfferPage]. Cette
/// séparation limite les rebuilds de la page et permet de tester la grille sans
/// initialiser Firebase ou les services IA.
class PublishOfferPhotosSection extends StatelessWidget {
  const PublishOfferPhotosSection({
    super.key,
    required this.visibleTileCount,
    required this.maximumPhotos,
    required this.selectedPhotos,
    required this.selectedPhotoBytes,
    required this.onPhotoTap,
    required this.onPhotoLongPress,
    required this.onPhotoRemove,
  });

  final int visibleTileCount;
  final int maximumPhotos;
  final List<XFile> selectedPhotos;
  final List<Uint8List?> selectedPhotoBytes;
  final ValueChanged<int> onPhotoTap;
  final ValueChanged<int> onPhotoLongPress;
  final ValueChanged<int> onPhotoRemove;

  @override
  Widget build(BuildContext context) {
    final photoLabel = maximumPhotos > 1 ? 'photos' : 'photo';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text(
              "Photos de l'offre",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '(optionnel, $maximumPhotos $photoLabel maximum)',
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: visibleTileCount,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.8,
          ),
          itemBuilder: (context, index) {
            final hasPhoto = index < selectedPhotos.length;
            return PhotoSelectorTile(
              label: 'Photo ${index + 1}',
              file: hasPhoto ? selectedPhotos[index] : null,
              bytes: hasPhoto && index < selectedPhotoBytes.length
                  ? selectedPhotoBytes[index]
                  : null,
              onTap: () => onPhotoTap(index),
              onLongPress: () => onPhotoLongPress(index),
              onRemove: hasPhoto ? () => onPhotoRemove(index) : null,
            );
          },
        ),
      ],
    );
  }
}
