import 'package:flutter/material.dart';

import 'models/admin_messaging_settings_model.dart';
import 'services/admin_messaging_settings_service.dart';

class AdminMessagingSettingsPage extends StatefulWidget {
  final bool canEdit;
  final AdminMessagingSettingsService? service;

  const AdminMessagingSettingsPage({
    super.key,
    required this.canEdit,
    this.service,
  });

  @override
  State<AdminMessagingSettingsPage> createState() =>
      _AdminMessagingSettingsPageState();
}

class _AdminMessagingSettingsPageState
    extends State<AdminMessagingSettingsPage> {
  late final AdminMessagingSettingsService _service;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? AdminMessagingSettingsService();
    _ensureDefaults();
  }

  Future<void> _ensureDefaults() async {
    await _service.ensureDefaults();
    if (mounted) setState(() => _initialized = true);
  }

  Future<void> _save(AdminMessagingSettingsModel settings) async {
    await _service.save(settings);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Paramètres messagerie enregistrés.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: StreamBuilder<AdminMessagingSettingsModel>(
        stream: _service.watchSettings(),
        builder: (context, snapshot) {
          if (!_initialized && snapshot.data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final settings = snapshot.data ??
              const AdminMessagingSettingsModel(
                enabled: true,
                allowImages: true,
                allowVoice: true,
                allowDocuments: true,
                maxFileSizeMb: 25,
                maxMessagesPerHour: 60,
                maxConversationsPerDay: 20,
                retentionDays: 365,
                notificationPreviewEnabled: false,
                moderationMode: 'hybrid',
                riskThreshold: 70,
                autoBlockThreshold: 90,
              );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!widget.canEdit) const _SettingsReadOnlyBanner(),
              if (!widget.canEdit) const SizedBox(height: 16),
              _SettingsSwitchTile(
                title: 'Messagerie activée',
                value: settings.enabled,
                enabled: widget.canEdit,
                onChanged: (value) => _save(settings.copyWith(enabled: value)),
              ),
              _SettingsSwitchTile(
                title: 'Autoriser les images',
                value: settings.allowImages,
                enabled: widget.canEdit,
                onChanged: (value) =>
                    _save(settings.copyWith(allowImages: value)),
              ),
              _SettingsSwitchTile(
                title: 'Autoriser les vocaux',
                value: settings.allowVoice,
                enabled: widget.canEdit,
                onChanged: (value) =>
                    _save(settings.copyWith(allowVoice: value)),
              ),
              _SettingsSwitchTile(
                title: 'Autoriser les documents',
                value: settings.allowDocuments,
                enabled: widget.canEdit,
                onChanged: (value) =>
                    _save(settings.copyWith(allowDocuments: value)),
              ),
              _SettingsNumberTile(
                title: 'Taille max fichier (Mo)',
                value: settings.maxFileSizeMb,
              ),
              _SettingsNumberTile(
                title: 'Messages max / heure',
                value: settings.maxMessagesPerHour,
              ),
              _SettingsNumberTile(
                title: 'Conversations max / jour',
                value: settings.maxConversationsPerDay,
              ),
              _SettingsNumberTile(
                title: 'Rétention (jours)',
                value: settings.retentionDays,
              ),
              _SettingsNumberTile(
                title: 'Seuil risque',
                value: settings.riskThreshold,
              ),
              _SettingsNumberTile(
                title: 'Seuil auto-blocage',
                value: settings.autoBlockThreshold,
              ),
              _SettingsNumberTile(
                title: 'Mode modération',
                value: settings.moderationMode,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SettingsReadOnlyBanner extends StatelessWidget {
  const _SettingsReadOnlyBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1D4ED8).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: const Color(0xFF1D4ED8).withValues(alpha: 0.18)),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_outline_rounded, color: Color(0xFF1D4ED8)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Lecture seule: seuls les superadmins peuvent modifier les paramètres globaux de messagerie.',
              style: TextStyle(
                color: Color(0xFF1D4ED8),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  final String title;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchTile({
    required this.title,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Material(
        color: Colors.transparent,
        child: SwitchListTile(
          value: value,
          onChanged: enabled ? onChanged : null,
          title: Text(title),
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

class _SettingsNumberTile extends StatelessWidget {
  final String title;
  final Object value;

  const _SettingsNumberTile({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            '$value',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
