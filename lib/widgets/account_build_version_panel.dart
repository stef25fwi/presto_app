import 'package:flutter/material.dart';

class AccountBuildVersionPanel extends StatelessWidget {
  final String platformLabel;
  final String modeLabel;
  final String sha;
  final String tag;
  final String branch;
  final String buildTimeUtc;
  final VoidCallback onCopySha;

  const AccountBuildVersionPanel({
    super.key,
    required this.platformLabel,
    required this.modeLabel,
    required this.sha,
    required this.tag,
    required this.branch,
    required this.buildTimeUtc,
    required this.onCopySha,
  });

  @override
  Widget build(BuildContext context) {
    final shortSha = (sha.length > 12) ? sha.substring(0, 12) : sha;
    final hasStamp = sha.isNotEmpty && sha != 'local';
    final stampLine = [
      if (tag.trim().isNotEmpty) 'tag: ${tag.trim()}',
      if (branch.trim().isNotEmpty) 'branch: ${branch.trim()}',
      if (buildTimeUtc.trim().isNotEmpty) 'build: ${buildTimeUtc.trim()} UTC',
    ].join(' • ');

    return Container(
      decoration: BoxDecoration(
        color: hasStamp
            ? Colors.green.withOpacity(0.06)
            : Colors.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasStamp
              ? Colors.green.withOpacity(0.25)
              : Colors.red.withOpacity(0.25),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '🧩 Version affichée',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: hasStamp ? Colors.green.shade800 : Colors.red.shade700,
                ),
              ),
              const Spacer(),
              Text(
                '$platformLabel • $modeLabel',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.black54,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            'sha: $shortSha',
            style: const TextStyle(
              fontSize: 12,
              height: 1.2,
              color: Colors.black87,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (stampLine.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              stampLine,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (!hasStamp) ...[
            const SizedBox(height: 6),
            const Text(
              '⚠️ Build stamp non renseigné (utilise --dart-define).',
              style: TextStyle(
                fontSize: 11,
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: onCopySha,
                icon: const Icon(Icons.copy, size: 16),
                label: const Text(
                  'Copier SHA',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF1A73E8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
              ),
              const Spacer(),
              Text(
                hasStamp ? 'OK' : 'LOCAL',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: hasStamp ? Colors.green.shade800 : Colors.red.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
