import 'package:flutter/material.dart';

import '../app/app_runtime_config.dart';

class AudioPipelineBadge extends StatelessWidget {
  const AudioPipelineBadge({super.key});

  Color _colorFor(String value) {
    switch (value.toUpperCase()) {
      case 'STREAM':
        return Colors.green;
      case 'HYBRID':
        return Colors.blue;
      case 'CHUNK':
        return Colors.orange;
      case 'DISABLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = PrestoRemoteConfig.audioPipeline;
    final color = _colorFor(value);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.graphic_eq, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            value.isEmpty ? 'UNKNOWN' : value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
