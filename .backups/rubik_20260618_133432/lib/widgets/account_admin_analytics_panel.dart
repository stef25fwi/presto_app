import 'package:flutter/material.dart';

class AccountAnalyticsMetricItem {
  final String icon;
  final String label;
  final String subtitle;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final String value;
  final String? hint;
  final Color color;

  const AccountAnalyticsMetricItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.enabled,
    required this.onToggle,
    required this.value,
    this.hint,
    required this.color,
  });
}

class AccountAdminAnalyticsPanel extends StatelessWidget {
  final bool enabled;
  final bool verboseLogs;
  final String sessionLabel;
  final int errorsCount;
  final List<AccountAnalyticsMetricItem> metrics;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<bool> onVerboseChanged;
  final VoidCallback onReset;

  const AccountAdminAnalyticsPanel({
    super.key,
    required this.enabled,
    required this.verboseLogs,
    required this.sessionLabel,
    required this.errorsCount,
    required this.metrics,
    required this.onEnabledChanged,
    required this.onVerboseChanged,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.teal.withOpacity(0.25)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '📊 Analytics / Monitoring (session)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Colors.teal,
                ),
              ),
              const Spacer(),
              Switch(
                value: enabled,
                onChanged: onEnabledChanged,
                activeColor: Colors.teal,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
          Text(
            'Session: $sessionLabel • erreurs: $errorsCount',
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          for (int index = 0; index < metrics.length; index++) ...[
            _AccountAnalyticsMetricRow(item: metrics[index]),
            if (index < metrics.length - 1) const SizedBox(height: 8),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.refresh),
                label: const Text(
                  'Reset',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  const Text(
                    'Logs',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.black54,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Switch(
                    value: verboseLogs,
                    onChanged: onVerboseChanged,
                    activeColor: Colors.teal,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccountAnalyticsMetricRow extends StatelessWidget {
  final AccountAnalyticsMetricItem item;

  const _AccountAnalyticsMetricRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final statusColor = item.enabled ? item.color : Colors.grey;

    return Container(
      decoration: BoxDecoration(
        color: item.enabled
            ? statusColor.withOpacity(0.07)
            : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.25)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Text(item.icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  item.subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (item.hint != null && item.hint!.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.hint!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.black45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                item.value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: statusColor,
                ),
              ),
              const SizedBox(height: 2),
              Switch(
                value: item.enabled,
                onChanged: item.onToggle,
                activeColor: statusColor,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
