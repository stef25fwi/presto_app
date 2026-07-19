import 'package:flutter/material.dart';

import 'account_notifications_status_chip.dart';

const Color _kOrange = Color(0xFFFF6600);

class AccountNotificationsCard extends StatelessWidget {
  const AccountNotificationsCard({
    super.key,
    required this.loading,
    required this.busy,
    required this.authorized,
    required this.blocked,
    required this.badgeLabel,
    required this.badgeColor,
    required this.badgeIcon,
    required this.onToggle,
    required this.onOpenSettings,
  });

  final bool loading;
  final bool busy;
  final bool authorized;
  final bool blocked;
  final String badgeLabel;
  final Color badgeColor;
  final IconData badgeIcon;
  final ValueChanged<bool> onToggle;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFB8BEC7), width: 2),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications_active_rounded, color: _kOrange),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Notifications',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
                if (loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  AccountNotificationsStatusChip(
                    label: badgeLabel,
                    color: badgeColor,
                    icon: badgeIcon,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              visualDensity: VisualDensity.compact,
              activeThumbColor: _kOrange,
              title: const Text(
                'Recevoir les notifications',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                authorized
                    ? 'Nouveaux messages, réponses à tes annonces et alertes.'
                    : blocked
                        ? 'Bloquées dans les réglages système.'
                        : 'Active-les pour ne rien manquer.',
              ),
              value: authorized,
              onChanged: (loading || busy) ? null : onToggle,
              secondary: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: loading ? null : onOpenSettings,
                icon: const Icon(Icons.settings_outlined, size: 18),
                label: const Text('Gérer dans les réglages système'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
