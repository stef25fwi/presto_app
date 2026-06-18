import 'package:flutter/material.dart';

/// Banner affiché en haut de l'écran en mode offline
class OfflineBanner extends StatelessWidget {
  final bool isVisible;

  const OfflineBanner({
    super.key,
    required this.isVisible,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return Material(
      color: Colors.grey.shade800,
      elevation: 4,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(
              Icons.cloud_off,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Mode hors ligne',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Consultation uniquement • Les actions d\'écriture sont désactivées',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.info_outline,
              color: Colors.white70,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

/// Wrapper pour afficher un message quand une action est tentée hors ligne
class OfflineActionGuard extends StatelessWidget {
  final bool isOnline;
  final VoidCallback onAction;
  final String offlineMessage;
  final Widget child;

  const OfflineActionGuard({
    super.key,
    required this.isOnline,
    required this.onAction,
    this.offlineMessage = 'Cette action nécessite une connexion Internet.',
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (isOnline) {
          onAction();
        } else {
          _showOfflineDialog(context);
        }
      },
      child: child,
    );
  }

  void _showOfflineDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cloud_off, color: Colors.orange),
            SizedBox(width: 12),
            Text('Mode hors ligne'),
          ],
        ),
        content: Text(offlineMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

/// Badge "Hors ligne" pour les boutons
class OfflineBadge extends StatelessWidget {
  final bool isOnline;

  const OfflineBadge({
    super.key,
    required this.isOnline,
  });

  @override
  Widget build(BuildContext context) {
    if (isOnline) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off,
            size: 14,
            color: Colors.orange.shade700,
          ),
          const SizedBox(width: 4),
          Text(
            'Hors ligne',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.orange.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
