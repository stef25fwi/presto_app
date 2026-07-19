import 'dart:async';

import 'package:app_settings/app_settings.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/notification_service.dart';
import '../utils/friendly_snackbar.dart';
import 'account_notifications_card.dart';

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
    if (!value || _isBlocked) {
      await _openSystemSettings();
      return;
    }

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
    return AccountNotificationsCard(
      loading: _loading,
      busy: _busy,
      authorized: _isAuthorized,
      blocked: _isBlocked,
      badgeLabel: badge.label,
      badgeColor: badge.color,
      badgeIcon: badge.icon,
      onToggle: _onToggle,
      onOpenSettings: _openSystemSettings,
    );
  }
}
