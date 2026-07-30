part of '../ad_placeholder_images_admin_page.dart';

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
