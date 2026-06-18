import 'package:flutter/material.dart';

class AccountBuildVersionPanel extends StatelessWidget {
  final String platformLabel;
  final String modeLabel;
  final String version;
  final String buildNumber;
  final String repository;
  final String sha;
  final String tag;
  final String branch;
  final String buildTimeUtc;
  final VoidCallback onCopySha;
  final ValueChanged<String> onCopySnapshot;

  const AccountBuildVersionPanel({
    super.key,
    required this.platformLabel,
    required this.modeLabel,
    required this.version,
    required this.buildNumber,
    required this.repository,
    required this.sha,
    required this.tag,
    required this.branch,
    required this.buildTimeUtc,
    required this.onCopySha,
    required this.onCopySnapshot,
  });

  @override
  Widget build(BuildContext context) {
    final shortSha = (sha.length > 12) ? sha.substring(0, 12) : sha;
    final hasStamp = sha.isNotEmpty && sha != 'local';
    final infoLines = <String>[
      'version: $version',
      'build: $buildNumber',
      'commit: $sha',
      'commit_short: $shortSha',
      'branch: ${branch.trim().isEmpty ? '(null)' : branch.trim()}',
      'tag: ${tag.trim().isEmpty ? '(null)' : tag.trim()}',
      'repo: ${repository.trim().isEmpty ? '(null)' : repository.trim()}',
      'platform: $platformLabel',
      'mode: $modeLabel',
      'built_at_utc: ${buildTimeUtc.trim().isEmpty ? '(null)' : buildTimeUtc.trim()}',
      'stamp: ${hasStamp ? 'OK' : 'LOCAL'}',
    ];
    final snapshotText = infoLines.join('\n');

    return Container(
      decoration: BoxDecoration(
        color: hasStamp
            ? Colors.green.withValues(alpha: 0.06)
            : Colors.red.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasStamp
              ? Colors.green.withValues(alpha: 0.25)
              : Colors.red.withValues(alpha: 0.25),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '🧩 Build visible en production',
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
            snapshotText,
            style: const TextStyle(
              fontSize: 12,
              height: 1.28,
              color: Colors.black87,
              fontWeight: FontWeight.w700,
            ),
          ),
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
              Expanded(
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    TextButton.icon(
                      onPressed: onCopySha,
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text(
                        'Copier commit',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF1A73E8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => onCopySnapshot(snapshotText),
                      icon: const Icon(Icons.copy_all_rounded, size: 16),
                      label: const Text(
                        'Copier snapshot',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF1A73E8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
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
