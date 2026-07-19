import 'dart:async';

import 'package:app_settings/app_settings.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/notification_service.dart';
import '../utils/friendly_snackbar.dart';
import 'account_notifications_status_chip.dart';

const Color _kOrange = Color(0xFFFF6600);

typedef AccountNotificationStatusLoader = Future<AuthorizationStatus> Function();
typedef AccountNotificationAction = Future<void> Function();
typedef AccountNotificationPermissionRequester = Future<bool> Function();
typedef AccountNotificationFailureMessage = String Function();

/// Carte « Notifications » de la page Mon compte.
///
/// Affiche l'état des notifications (Activées / Bloquées / Désactivées) et
/// permet de les activer. Pour gérer/désactiver/débloquer, le toggle ouvre
/// directement les réglages système (la permission OS ne peut pas être
/// modifiée depuis l'app). Le test de réception vit dans l'espace admin.
class AccountNotificationsTile extends StatefulWidget {
  const AccountNotificationsTile({
    super.key,
    this.statusLoader,
    this.ensureDeviceRegistered,
    this.requestPushPermission,
    this.activationFailureMessage,
    this.openSystemSettings,
  });

  final AccountNotificationStatusLoader? statusLoader;
  final AccountNotificationAction? ensureDeviceRegistered;
  final AccountNotificationPermissionRequester? requestPushPermission;
  final AccountNotificationFailureMessage? activationFailureMessage;
  final AccountNotificationAction? openSystemSettings;

  @override
  State<AccountNotificationsTile> createState() =>
      _AccountNotificationsTileState();
}

class _AccountNotificationsTileState extends State<AccountNotificationsTile> {
  final NotificationService _service = NotificationService();

  AuthorizationStatus? _status;
  bool _loading = true;
  bool _busy = false;

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
      final loader = widget.statusLoader;
      final status = loader != null
          ? await loader()
          : (await _service.getPermissionSettings()).authorizationStatus;
      if (!mounted) return;
      setState(() {
        _status = status;
        _loading = false;
      });
      if (_isAuthorized) {
        // Best-effort : garantir que le token est enregistré côté serveur même
        // si la permission avait été accordée dans une session précédente.
        final ensureRegistered =
            widget.ensureDeviceRegistered ?? _service.ensureDeviceRegistered;
        unawaited(ensureRegistered());
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _onToggle(bool value) async {
    if (_busy) return;

    // Désactiver, ou débloquer une permission refusée : impossible depuis
    // l'app → on ouvre directement les réglages système.
    if (!value || _isBlocked) {
      await _openSystemSettings();
      return;
    }

    // Première activation : on demande la permission OS.
    setState(() => _busy = true);
    try {
      final requestPermission =
          widget.requestPushPermission ?? _service.requestPushPermission;
      final activated = await requestPermission();
      await _load();
      if (!mounted) return;
      if (activated) {
        showSuccessSnackBar(
          context,
          'Notifications activées sur cet appareil.',
        );
      } else {
        final failureMessage = widget.activationFailureMessage ??
            _service.pushActivationFailureMessage;
        showErrorSnackBar(context, failureMessage());
      }
    } catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Erreur d’activation : $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openSystemSettings() async {
    final override = widget.openSystemSettings;
    if (override != null) {
      try {
        await override();
      } catch (_) {
        if (!mounted) return;
        await _showSystemSettingsFallback();
      }
      return;
    }

    if (kIsWeb) {
      await _showInfoDialog(
        title: 'Réglages des notifications',
        message: 'Sur le web, gère les notifications dans les réglages de ton '
            'navigateur (icône cadenas ou ⚙️ à gauche de la barre d’adresse) '
            '→ Notifications.',
      );
      return;
    }
    try {
      await AppSettings.openAppSettings(type: AppSettingsType.notification);
    } catch (_) {
      if (!mounted) return;
      await _showSystemSettingsFallback();
    }
  }

  Future<void> _showSystemSettingsFallback() {
    return _showInfoDialog(
      title: 'Réglages des notifications',
      message: 'Ouvre les réglages de ton téléphone → Notifications → iliprestō '
          'pour gérer les autorisations.',
    );
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
                  AccountNotificationsStatusChip(
                    label: badge.label,
                    color: badge.color,
                    icon: badge.icon,
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
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _loading ? null : _openSystemSettings,
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
