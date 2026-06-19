import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/notification_service.dart';
import '../utils/friendly_snackbar.dart';

const Color _kOrange = Color(0xFFFF6600);

/// Carte « Notifications » de la page Mon compte.
///
/// Permet à l'utilisateur de vérifier que les notifications sont autorisées,
/// de les activer, et d'envoyer une notification test pour confirmer que le
/// téléphone les reçoit (y compris sur l'écran verrouillé), comme les autres
/// applications.
class AccountNotificationsTile extends StatefulWidget {
  const AccountNotificationsTile({super.key});

  @override
  State<AccountNotificationsTile> createState() =>
      _AccountNotificationsTileState();
}

class _AccountNotificationsTileState extends State<AccountNotificationsTile> {
  final NotificationService _service = NotificationService();

  AuthorizationStatus? _status;
  bool _loading = true;
  bool _busy = false;
  bool _testing = false;

  bool get _isAuthorized =>
      _status == AuthorizationStatus.authorized ||
      _status == AuthorizationStatus.provisional;

  bool get _isBlocked => _status == AuthorizationStatus.denied;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final settings = await _service.getPermissionSettings();
      if (!mounted) return;
      setState(() {
        _status = settings.authorizationStatus;
        _loading = false;
      });
      if (_isAuthorized) {
        // Best-effort : garantir que le token est enregistré côté serveur même
        // si la permission avait été accordée dans une session précédente.
        unawaited(_service.ensureDeviceRegistered());
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _onToggle(bool value) async {
    if (_busy) return;

    if (!value) {
      // Impossible de révoquer la permission OS depuis l'app : on guide.
      await _showInfoDialog(
        title: 'Désactiver les notifications',
        message:
            'Pour désactiver les notifications iliprestō, ouvre les réglages '
            'de ton téléphone (ou de ton navigateur) → Notifications → '
            'iliprestō, puis désactive-les.',
      );
      return;
    }

    if (_isBlocked) {
      await _showInfoDialog(
        title: 'Notifications bloquées',
        message:
            'Les notifications sont bloquées au niveau du système. Ouvre les '
            'réglages de ton téléphone (ou de ton navigateur) → Notifications '
            '→ iliprestō et autorise-les, puis reviens ici.',
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final activated = await _service.requestPushPermission();
      await _load();
      if (!mounted) return;
      if (activated) {
        showSuccessSnackBar(context, 'Notifications activées sur cet appareil.');
      } else {
        showErrorSnackBar(context, _service.pushActivationFailureMessage());
      }
    } catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Erreur d’activation : $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendTest() async {
    if (_testing) return;
    setState(() => _testing = true);
    try {
      // S'assure d'abord que cet appareil a bien un token enregistré.
      final registration = await _service.ensureDeviceRegistered();
      if (registration != DeviceRegistrationResult.registered) {
        if (!mounted) return;
        showErrorSnackBar(context, _registrationIssueMessage(registration));
        return;
      }
      final count = await _service.sendSelfTestNotification();
      if (!mounted) return;
      showSuccessSnackBar(
        context,
        'Notification test envoyée à $count appareil(s). Verrouille ton écran : '
        'tu devrais la voir apparaître dans quelques secondes.',
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      final message = error.code == 'failed-precondition'
          ? 'Aucun appareil enregistré. Active d’abord les notifications ci-dessus.'
          : (error.message ?? 'Envoi du test impossible.');
      showErrorSnackBar(context, message);
    } catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Envoi du test impossible : $error');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  String _registrationIssueMessage(DeviceRegistrationResult result) {
    switch (result) {
      case DeviceRegistrationResult.permissionMissing:
        return 'Active d’abord les notifications ci-dessus.';
      case DeviceRegistrationResult.noToken:
        return kIsWeb
            ? 'Recharge la page (Ctrl+Maj+R) puis réessaie : le navigateur n’a '
                'pas encore de jeton de notification.'
            : 'Impossible d’obtenir un jeton de notification sur cet appareil. '
                'Réessaie.';
      case DeviceRegistrationResult.registrationFailed:
        return 'Échec de l’enregistrement de l’appareil. Vérifie ta connexion '
            'et réessaie.';
      case DeviceRegistrationResult.registered:
        return '';
    }
  }

  Future<void> _showInfoDialog({
    required String title,
    required String message,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }

  ({String label, Color color, IconData icon}) get _statusBadge {
    if (_isAuthorized) {
      return (
        label: 'Activées',
        color: const Color(0xFF12B76A),
        icon: Icons.check_circle_rounded,
      );
    }
    if (_isBlocked) {
      return (
        label: 'Bloquées',
        color: const Color(0xFFD92D20),
        icon: Icons.block_rounded,
      );
    }
    return (
      label: 'Désactivées',
      color: Colors.grey.shade600,
      icon: Icons.notifications_off_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final badge = _statusBadge;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications_active_rounded,
                    color: _kOrange),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Notifications',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (_loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  _StatusChip(
                      label: badge.label, color: badge.color, icon: badge.icon),
              ],
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: _kOrange,
              title: const Text(
                'Recevoir les notifications',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                _isAuthorized
                    ? 'Nouveaux messages, réponses à tes annonces et alertes.'
                    : _isBlocked
                        ? 'Bloquées dans les réglages système.'
                        : 'Active-les pour ne rien manquer.',
              ),
              value: _isAuthorized,
              onChanged: (_loading || _busy) ? null : _onToggle,
              secondary: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
            ),
            const Divider(height: 18),
            Text(
              'Vérifie que ton téléphone reçoit bien les notifications, même '
              'écran verrouillé, comme les autres applications.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.black54),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed:
                    (!_isAuthorized || _testing) ? null : _sendTest,
                icon: _testing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(
                  _testing
                      ? 'Envoi en cours...'
                      : 'Envoyer une notification test',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
