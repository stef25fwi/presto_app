import 'package:flutter/material.dart';

import 'video_maker_models.dart';
import 'video_maker_page_operations.dart';

const videoMakerOrange = Color(0xFFFF6600);
const videoMakerBlue = Color(0xFF1A73E8);
const videoMakerText = Color(0xFF111827);
const videoMakerMuted = Color(0xFF6B7280);
const videoMakerBorder = Color(0xFFE5E7EB);
const videoMakerBackground = Color(0xFFF7F8FA);

class VideoMakerGeneratorCard extends StatelessWidget {
  final TextEditingController apiKeyController;
  final TextEditingController promptController;
  final bool hideApiKey;
  final bool generating;
  final String aspectRatio;
  final List<VideoMakerSelectedImage> images;
  final VoidCallback onToggleApiKey;
  final ValueChanged<String> onAspectRatioChanged;
  final VoidCallback? onPickImages;
  final ValueChanged<int>? onRemoveImage;
  final VoidCallback? onGenerate;

  const VideoMakerGeneratorCard({
    super.key,
    required this.apiKeyController,
    required this.promptController,
    required this.hideApiKey,
    required this.generating,
    required this.aspectRatio,
    required this.images,
    required this.onToggleApiKey,
    required this.onAspectRatioChanged,
    required this.onPickImages,
    required this.onRemoveImage,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    return VideoMakerPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: _VideoMakerIcon(),
            title: Text(
              'Créer une vidéo avec VEO',
              style: TextStyle(
                color: videoMakerText,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            subtitle: Text(
              'VEO 3.1 • jusqu’à 3 images de référence • 8 secondes • audio natif',
              style: TextStyle(
                color: videoMakerMuted,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: apiKeyController,
            obscureText: hideApiKey,
            enableSuggestions: false,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'Clé API Gemini / VEO',
              hintText: 'Optionnelle si VEO_API_KEY est configurée',
              helperText: 'Utilisée uniquement pour cet appel, jamais enregistrée.',
              helperMaxLines: 2,
              prefixIcon: const Icon(Icons.key_rounded),
              suffixIcon: IconButton(
                tooltip: hideApiKey ? 'Afficher la clé' : 'Masquer la clé',
                onPressed: onToggleApiKey,
                icon: Icon(
                  hideApiKey
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: promptController,
            minLines: 5,
            maxLines: 9,
            maxLength: 4000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Prompt vidéo',
              hintText: 'Décrivez la scène, les mouvements, la caméra, la lumière, le style et le son…',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment<String>(
                value: '9:16',
                icon: Icon(Icons.stay_current_portrait_rounded),
                label: Text('9:16 Réseaux'),
              ),
              ButtonSegment<String>(
                value: '16:9',
                icon: Icon(Icons.crop_landscape_rounded),
                label: Text('16:9 Paysage'),
              ),
            ],
            selected: {aspectRatio},
            onSelectionChanged: generating
                ? null
                : (selection) => onAspectRatioChanged(selection.first),
          ),
          const SizedBox(height: 14),
          _MultiImageField(
            images: images,
            onPick: onPickImages,
            onRemove: onRemoveImage,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: videoMakerOrange,
                minimumSize: const Size.fromHeight(54),
              ),
              onPressed: onGenerate,
              icon: generating
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.3,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.movie_filter_rounded),
              label: Text(
                generating ? 'Génération VEO en cours…' : 'Générer et enregistrer',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          if (generating) ...[
            const SizedBox(height: 10),
            const Text(
              'La création peut durer plusieurs minutes. Le résultat sera automatiquement enregistré dans la bibliothèque.',
              style: TextStyle(
                color: videoMakerMuted,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class VideoMakerLibrary extends StatelessWidget {
  final List<GeneratedVideo> videos;
  final bool loading;
  final ValueChanged<GeneratedVideo> onDownload;
  final ValueChanged<GeneratedVideo> onShare;
  final ValueChanged<GeneratedVideo> onDelete;

  const VideoMakerLibrary({
    super.key,
    required this.videos,
    required this.loading,
    required this.onDownload,
    required this.onShare,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _LibraryHeader(count: videos.length, loading: loading),
        const SizedBox(height: 12),
        if (loading && videos.isEmpty)
          const _LoadingLibrary()
        else if (videos.isEmpty)
          const _EmptyLibrary()
        else
          for (final video in videos)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _VideoCard(
                video: video,
                onDownload: () => onDownload(video),
                onShare: () => onShare(video),
                onDelete: () => onDelete(video),
              ),
            ),
      ],
    );
  }
}

class VideoMakerPanel extends StatelessWidget {
  final Widget child;

  const VideoMakerPanel({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: videoMakerBorder),
      ),
      child: child,
    );
  }
}

class _VideoMakerIcon extends StatelessWidget {
  const _VideoMakerIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: videoMakerOrange.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(
        Icons.movie_creation_outlined,
        color: videoMakerOrange,
      ),
    );
  }
}

class _MultiImageField extends StatelessWidget {
  final List<VideoMakerSelectedImage> images;
  final VoidCallback? onPick;
  final ValueChanged<int>? onRemove;

  const _MultiImageField({
    required this.images,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Images de référence',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            Text(
              '${images.length}/$maxVideoMakerReferenceImages',
              style: const TextStyle(
                color: videoMakerMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Ajoutez jusqu’à 3 images d’une personne, d’un produit ou d’éléments à conserver dans la vidéo.',
          style: TextStyle(color: videoMakerMuted, height: 1.35),
        ),
        const SizedBox(height: 10),
        if (images.isNotEmpty)
          SizedBox(
            height: 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final image = images[index];
                return SizedBox(
                  width: 102,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.memory(
                            image.bytes,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const ColoredBox(
                              color: videoMakerBackground,
                              child: Icon(Icons.image_not_supported_outlined),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: IconButton.filledTonal(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Retirer ${image.name}',
                          onPressed: onRemove == null ? null : () => onRemove!(index),
                          icon: const Icon(Icons.close_rounded, size: 18),
                        ),
                      ),
                      Positioned(
                        left: 5,
                        right: 5,
                        bottom: 5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.62),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            image.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        if (images.isNotEmpty) const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: images.length >= maxVideoMakerReferenceImages ? null : onPick,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: Text(
            images.isEmpty ? 'Choisir plusieurs images' : 'Ajouter d’autres images',
          ),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        ),
      ],
    );
  }
}

class _LibraryHeader extends StatelessWidget {
  final int count;
  final bool loading;

  const _LibraryHeader({required this.count, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bibliothèque vidéo',
                style: TextStyle(
                  color: videoMakerText,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'Toutes les créations sont conservées dans Firebase Storage.',
                style: TextStyle(color: videoMakerMuted),
              ),
            ],
          ),
        ),
        if (loading)
          const SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          )
        else
          Chip(label: Text('$count')),
      ],
    );
  }
}

class _VideoCard extends StatelessWidget {
  final GeneratedVideo video;
  final VoidCallback onDownload;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  const _VideoCard({
    required this.video,
    required this.onDownload,
    required this.onShare,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final ready = video.status == 'ready' && video.publicUrl != null;
    final details = <String>[
      video.aspectRatio,
      '${video.durationSeconds}s',
      video.resolution,
      if (video.referenceImageCount > 0)
        '${video.referenceImageCount} image${video.referenceImageCount > 1 ? 's' : ''}',
      if (video.sizeBytes != null) formatVideoMakerBytes(video.sizeBytes!),
    ];
    return VideoMakerPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: videoMakerBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  ready
                      ? Icons.play_circle_outline_rounded
                      : video.status == 'failed'
                          ? Icons.error_outline_rounded
                          : Icons.hourglass_top_rounded,
                  color: video.status == 'failed' ? Colors.redAccent : videoMakerBlue,
                  size: 40,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatusChip(status: video.status),
                    const SizedBox(height: 8),
                    Text(
                      video.prompt,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: videoMakerText,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Supprimer de la bibliothèque',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${details.join(' • ')} • ${formatVideoMakerDate(video.createdAt)}',
            style: const TextStyle(
              color: videoMakerMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (video.referenceImageNames.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              video.referenceImageNames.join(' • '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: videoMakerMuted, fontSize: 12),
            ),
          ],
          if (video.errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              video.errorMessage!,
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (ready) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDownload,
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Ouvrir'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onShare,
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('Partager'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color color;
    switch (status) {
      case 'ready':
        label = 'Prête';
        color = const Color(0xFF138A46);
        break;
      case 'failed':
        label = 'Échec';
        color = Colors.redAccent;
        break;
      default:
        label = 'En cours';
        color = videoMakerBlue;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _LoadingLibrary extends StatelessWidget {
  const _LoadingLibrary();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 42),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context) {
    return const VideoMakerPanel(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Icon(Icons.video_library_outlined, size: 44, color: videoMakerMuted),
            SizedBox(height: 10),
            Text(
              'Aucune vidéo générée',
              style: TextStyle(
                color: videoMakerText,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Votre première création VEO apparaîtra ici automatiquement.',
              textAlign: TextAlign.center,
              style: TextStyle(color: videoMakerMuted),
            ),
          ],
        ),
      ),
    );
  }
}
