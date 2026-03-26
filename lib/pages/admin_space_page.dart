import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/friendly_snackbar.dart';

import '../constants.dart';

class AdminSpacePage extends StatefulWidget {
  const AdminSpacePage({super.key});

  @override
  State<AdminSpacePage> createState() => _AdminSpacePageState();
}

enum MicroIaMode { google, whisper, hybride }

enum MicroIaAudioQuality { low, medium, high }

String microIaAudioQualityToRcValue(MicroIaAudioQuality q) {
  switch (q) {
    case MicroIaAudioQuality.low:
      return "LOW";
    case MicroIaAudioQuality.medium:
      return "MEDIUM";
    case MicroIaAudioQuality.high:
      return "HIGH";
  }
}

MicroIaAudioQuality microIaAudioQualityFromRcValue(String v) {
  switch (v.toUpperCase()) {
    case "LOW":
      return MicroIaAudioQuality.low;
    case "HIGH":
      return MicroIaAudioQuality.high;
    default:
      return MicroIaAudioQuality.medium;
  }
}

class MicroIaTranscriptionPage extends StatefulWidget {
  const MicroIaTranscriptionPage({super.key});

  @override
  State<MicroIaTranscriptionPage> createState() =>
      _MicroIaTranscriptionPageState();
}

class _MicroIaTranscriptionPageState extends State<MicroIaTranscriptionPage> {
  static const Color prestoOrange = Color(0xFFFF6600);
  static const Color prestoBlue = Color(0xFF1A73E8);

  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  bool _loading = true;
  bool _saving = false;

  MicroIaMode _mode = MicroIaMode.hybride;
  MicroIaAudioQuality _audioQuality = MicroIaAudioQuality.medium;
  bool _fallback = true;
  double _quality = 0.62;
  bool _ultraFastEnabled = false;
  final List<String> _languages = ['fr-FR'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final callable = _functions.httpsCallable(
        'adminGetMicroIaConfig',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
      );
      final res = await callable.call<dynamic>({});
      final data = Map<String, dynamic>.from(res.data as Map);

      final modeStr = (data['mode'] ?? 'HYBRID').toString().toUpperCase();
      final fallback = data['fallbackEnabled'] == true;
      final threshold = (data['qualityThreshold'] as num?)?.toDouble() ?? 0.62;
      final lang = (data['languageCode'] ?? 'fr-FR').toString().trim();
      final audioQualityStr = (data['audioQuality'] ??
              data['audio_quality'] ??
              data['microia_audio_quality'] ??
              'MEDIUM')
          .toString();
      final ultraFast = (data['ultraFastEnabled'] ??
              data['microia_ultra_fast_enabled'] ??
              data['microia_ultrafast_enabled'] ??
              data['microia_ultra_fast'] ??
              false) ==
          true;

      setState(() {
        _mode = _modeFromRemote(modeStr);
        _fallback = fallback;
        _quality = threshold.clamp(0.0, 1.0);
        _audioQuality = microIaAudioQualityFromRcValue(audioQualityStr);
        _ultraFastEnabled = ultraFast;
        _languages
          ..clear()
          ..add(lang.isEmpty ? 'fr-FR' : lang);
      });
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      if (e.code == 'permission-denied' || e.code == 'unauthenticated') {
        _snack('Accès admin requis.');
        Navigator.of(context).maybePop();
        return;
      }
      _snack(e.message ?? 'Erreur admin');
    } catch (e) {
      if (!mounted) return;
      _snack('Erreur admin: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  MicroIaMode _modeFromRemote(String mode) {
    switch (mode) {
      case 'GOOGLE_ONLY':
        return MicroIaMode.google;
      case 'WHISPER_ONLY':
        return MicroIaMode.whisper;
      case 'HYBRID':
      default:
        return MicroIaMode.hybride;
    }
  }

  String _modeToRemote(MicroIaMode mode) {
    switch (mode) {
      case MicroIaMode.google:
        return 'GOOGLE_ONLY';
      case MicroIaMode.whisper:
        return 'WHISPER_ONLY';
      case MicroIaMode.hybride:
        return 'HYBRID';
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final callable = _functions.httpsCallable(
        'adminSetMicroIaConfig',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );

      final lang = _languages.isNotEmpty ? _languages.first.trim() : 'fr-FR';

      final res = await callable.call<dynamic>({
        'mode': _modeToRemote(_mode),
        'fallbackEnabled': _fallback,
        'qualityThreshold': _quality,
        'languageCode': lang.isEmpty ? 'fr-FR' : lang,
        'microia_audio_quality': microIaAudioQualityToRcValue(_audioQuality),
        'ultraFastEnabled': _ultraFastEnabled,
      });

      final data = (res.data is Map)
          ? Map<String, dynamic>.from(res.data as Map)
          : <String, dynamic>{};

      final modeStr = (data['mode'] ?? _modeToRemote(_mode)).toString();
      final fallback = data['fallbackEnabled'] == true;
      final threshold =
          (data['qualityThreshold'] as num?)?.toDouble() ?? _quality;
      final languageCode = (data['languageCode'] ?? lang).toString();
      final audioQualityStr = (data['audioQuality'] ??
              data['audio_quality'] ??
              data['microia_audio_quality'] ??
              microIaAudioQualityToRcValue(_audioQuality))
          .toString();
      final ultraFast = (data['ultraFastEnabled'] ??
              data['microia_ultra_fast_enabled'] ??
              data['microia_ultrafast_enabled'] ??
              data['microia_ultra_fast'] ??
              _ultraFastEnabled) ==
          true;

      setState(() {
        _mode = _modeFromRemote(modeStr.toUpperCase());
        _fallback = fallback;
        _quality = threshold.clamp(0.0, 1.0);
        _audioQuality = microIaAudioQualityFromRcValue(audioQualityStr);
        _ultraFastEnabled = ultraFast;
        _languages
          ..clear()
          ..add(languageCode.trim().isEmpty ? 'fr-FR' : languageCode.trim());
      });

      _snack('Enregistré (Remote Config)');
    } on FirebaseFunctionsException catch (e) {
      _snack(e.message ?? 'Erreur admin');
    } catch (e) {
      _snack('Erreur admin: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    showSuccessSnackBar(context, msg);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        titleSpacing: 16,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: 'Retour',
        ),
        title: const Text(
          'Micro-IA — Transcription',
          style: kPrestoAppBarTitleStyle,
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(prestoOrange),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: _MicroIaCard(
                  prestoOrange: prestoOrange,
                  prestoBlue: prestoBlue,
                  mode: _mode,
                  audioQuality: _audioQuality,
                  fallback: _fallback,
                  quality: _quality,
                  ultraFastEnabled: _ultraFastEnabled,
                  languages: _languages,
                  onModeChanged: (m) => setState(() => _mode = m),
                  onUltraFastChanged: (v) =>
                      setState(() => _ultraFastEnabled = v),
                  onAudioQualityChanged: (q) async {
                    final prev = _audioQuality;
                    setState(() => _audioQuality = q);

                    try {
                      final callable = _functions.httpsCallable(
                        'adminSetMicroIaConfig',
                        options: HttpsCallableOptions(
                            timeout: const Duration(seconds: 30)),
                      );

                      final lang = _languages.isNotEmpty
                          ? _languages.first.trim()
                          : 'fr-FR';

                      await callable.call<dynamic>({
                        'mode': _modeToRemote(_mode),
                        'fallbackEnabled': _fallback,
                        'qualityThreshold': _quality,
                        'languageCode': lang.isEmpty ? 'fr-FR' : lang,
                        'audio_quality': microIaAudioQualityToRcValue(q),
                        'ultraFastEnabled': _ultraFastEnabled,
                      });
                    } on FirebaseFunctionsException catch (e) {
                      if (mounted) setState(() => _audioQuality = prev);
                      _snack(e.message ?? 'Erreur admin');
                    } catch (e) {
                      if (mounted) setState(() => _audioQuality = prev);
                      _snack('Erreur admin: $e');
                    }
                  },
                  onFallbackChanged: (v) => setState(() => _fallback = v),
                  onQualityChanged: (v) => setState(() => _quality = v),
                  onAddLanguage: () =>
                      _snack('Ajouter une langue (à brancher)'),
                  onRemoveLanguage: (code) =>
                      setState(() => _languages.remove(code)),
                  onSave: _saving ? null : _save,
                  saving: _saving,
                ),
              ),
      ),
    );
  }
}

Map<String, dynamic> _stringKeyMap(dynamic value) {
  if (value is Map) {
    return value.map(
      (key, entry) => MapEntry(key.toString(), entry),
    );
  }
  return <String, dynamic>{};
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _formatAdminTimestamp(int? millis) {
  if (millis == null || millis <= 0) return 'inconnue';
  final dt = DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
}

enum _EmailDashboardWindow { hour1, day1, day7 }

extension _EmailDashboardWindowX on _EmailDashboardWindow {
  String get label {
    switch (this) {
      case _EmailDashboardWindow.hour1:
        return '1 h';
      case _EmailDashboardWindow.day1:
        return '24 h';
      case _EmailDashboardWindow.day7:
        return '7 j';
    }
  }

  Duration get duration {
    switch (this) {
      case _EmailDashboardWindow.hour1:
        return const Duration(hours: 1);
      case _EmailDashboardWindow.day1:
        return const Duration(hours: 24);
      case _EmailDashboardWindow.day7:
        return const Duration(days: 7);
    }
  }
}

class _EmailDashboardStats {
  final int sent;
  final int delivered;
  final int bounced;
  final int complained;
  final int failed;
  final int sampledLogs;
  final Map<String, Map<String, int>> byProvider;
  final Map<String, Map<String, int>> byTemplate;

  const _EmailDashboardStats({
    required this.sent,
    required this.delivered,
    required this.bounced,
    required this.complained,
    required this.failed,
    required this.sampledLogs,
    required this.byProvider,
    required this.byTemplate,
  });

  double get deliveryRate => sent > 0 ? delivered / sent : 0.0;
  double get bounceRate => sent > 0 ? bounced / sent : 0.0;
  double get complaintRate => sent > 0 ? complained / sent : 0.0;

  static _EmailDashboardStats fromLogs(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    int sent = 0;
    int delivered = 0;
    int bounced = 0;
    int complained = 0;
    int failed = 0;
    final byProvider = <String, Map<String, int>>{};
    final byTemplate = <String, Map<String, int>>{};

    void incrementBucket(
      Map<String, Map<String, int>> target,
      String key,
      String status,
    ) {
      final bucket = target.putIfAbsent(
        key,
        () => <String, int>{
          'sent': 0,
          'delivered': 0,
          'bounced': 0,
          'complained': 0,
          'failed': 0,
        },
      );
      bucket[status] = (bucket[status] ?? 0) + 1;
    }

    for (final doc in docs) {
      final data = doc.data();
      final status = (data['status'] ?? '').toString().trim();
      final provider = (data['provider'] ?? 'unknown').toString().trim();
      final template = (data['template_code'] ?? 'unknown').toString().trim();

      switch (status) {
        case 'sent':
          sent += 1;
        case 'delivered':
          delivered += 1;
        case 'bounced':
          bounced += 1;
        case 'complained':
          complained += 1;
        case 'failed':
          failed += 1;
        default:
          continue;
      }

      incrementBucket(byProvider, provider.isEmpty ? 'unknown' : provider, status);
      incrementBucket(byTemplate, template.isEmpty ? 'unknown' : template, status);
    }

    return _EmailDashboardStats(
      sent: sent,
      delivered: delivered,
      bounced: bounced,
      complained: complained,
      failed: failed,
      sampledLogs: docs.length,
      byProvider: byProvider,
      byTemplate: byTemplate,
    );
  }
}

class EmailDashboardPage extends StatefulWidget {
  const EmailDashboardPage({super.key});

  @override
  State<EmailDashboardPage> createState() => _EmailDashboardPageState();
}

class _EmailDashboardPageState extends State<EmailDashboardPage> {
  _EmailDashboardWindow _window = _EmailDashboardWindow.hour1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        titleSpacing: 16,
        title: const Text(
          'Dashboard email',
          style: kPrestoAppBarTitleStyle,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  for (final window in _EmailDashboardWindow.values) ...[
                    _WindowChip(
                      label: window.label,
                      selected: _window == window,
                      onTap: () => setState(() => _window = window),
                    ),
                    if (window != _EmailDashboardWindow.values.last)
                      const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            Expanded(
              child: _EmailDashboardContent(window: _window),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmailDashboardContent extends StatelessWidget {
  final _EmailDashboardWindow window;

  const _EmailDashboardContent({required this.window});

  static const Color prestoOrange = Color(0xFFFF6600);
  static const Color prestoBlue = Color(0xFF1A73E8);

  @override
  Widget build(BuildContext context) {
    final threshold = DateTime.now()
        .subtract(window.duration)
        .millisecondsSinceEpoch;
    final logsStream = FirebaseFirestore.instance
        .collection('email_logs')
        .where('created_at', isGreaterThanOrEqualTo: threshold)
        .orderBy('created_at', descending: true)
        .limit(1000)
        .snapshots();
    final jobsStream = FirebaseFirestore.instance
        .collection('email_jobs')
        .where('updated_at', isGreaterThanOrEqualTo: threshold)
        .orderBy('updated_at', descending: true)
        .limit(60)
        .snapshots();
    final ticketsStream = FirebaseFirestore.instance
        .collection('support_tickets')
        .orderBy('updated_at', descending: true)
        .limit(60)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: logsStream,
      builder: (context, logsSnapshot) {
        if (logsSnapshot.hasError) {
          return _AdminInfoState(
            icon: Icons.warning_amber_rounded,
            title: 'Lecture impossible',
            message:
                'Les logs email ne sont pas accessibles. Vérifie les droits admin ou les index Firestore.',
            color: Colors.red.shade700,
          );
        }

        if (logsSnapshot.connectionState == ConnectionState.waiting &&
            !logsSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final stats = _EmailDashboardStats.fromLogs(logsSnapshot.data?.docs ?? []);

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: jobsStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _AdminInfoState(
                icon: Icons.warning_amber_rounded,
                title: 'Lecture impossible',
                message:
                    'Les jobs email ne sont pas accessibles. Vérifie les droits admin ou les index Firestore.',
                color: Colors.red.shade700,
              );
            }

            final deadLetters = (snapshot.data?.docs ?? [])
              .where((doc) => (doc.data()['status'] ?? '').toString() == 'dead_letter')
                .toList();

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: ticketsStream,
              builder: (context, ticketsSnapshot) {
                if (ticketsSnapshot.hasError) {
                  return _AdminInfoState(
                    icon: Icons.warning_amber_rounded,
                    title: 'Lecture impossible',
                    message:
                        'Les tickets support ne sont pas accessibles. Vérifie les droits admin.',
                    color: Colors.red.shade700,
                  );
                }

                final tickets = (ticketsSnapshot.data?.docs ?? [])
                    .where((doc) => _toInt(doc.data()['updated_at']) >= threshold)
                    .toList();
                final openTickets = tickets
                  .where((doc) => (doc.data()['status'] ?? 'open').toString() == 'open')
                    .length;
                final hasAlert = deadLetters.isNotEmpty ||
                    stats.failed > 0 ||
                    stats.bounceRate >= 0.05 ||
                    stats.complaintRate >= 0.01;

                final providerEntries = stats.byProvider.entries.toList()
              ..sort((a, b) {
                return (b.value['sent'] ?? 0).compareTo(a.value['sent'] ?? 0);
              });
                final templateEntries = stats.byTemplate.entries.toList()
              ..sort((a, b) {
                return (b.value['sent'] ?? 0).compareTo(a.value['sent'] ?? 0);
              });

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CardShell(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: (hasAlert ? Colors.red : prestoBlue)
                                          .withOpacity(0.10),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      hasAlert
                                          ? Icons.warning_amber_rounded
                                          : Icons.verified_rounded,
                                      color: hasAlert
                                          ? Colors.red.shade700
                                          : prestoBlue,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          hasAlert
                                              ? 'Livrabilité à surveiller'
                                              : 'Cockpit email temps réel',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 18,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Fenêtre ${window.label} • ${stats.sampledLogs} logs • maj ${_formatAdminTimestamp(DateTime.now().millisecondsSinceEpoch)}',
                                          style: const TextStyle(
                                            color: Colors.black54,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  _DashboardPill(
                                    label: 'Taux délivré',
                                    value:
                                        '${(stats.deliveryRate * 100).toStringAsFixed(1)}%',
                                    color: Colors.green.shade700,
                                  ),
                                  _DashboardPill(
                                    label: 'Bounce',
                                    value:
                                        '${(stats.bounceRate * 100).toStringAsFixed(1)}%',
                                    color: stats.bounceRate >= 0.05
                                        ? Colors.red.shade700
                                        : prestoBlue,
                                  ),
                                  _DashboardPill(
                                    label: 'Plaintes',
                                    value:
                                        '${(stats.complaintRate * 100).toStringAsFixed(1)}%',
                                    color: stats.complaintRate >= 0.01
                                        ? Colors.red.shade700
                                        : prestoBlue,
                                  ),
                                  _DashboardPill(
                                    label: 'Dead letters',
                                    value: '${deadLetters.length}',
                                    color: deadLetters.isNotEmpty
                                        ? Colors.red.shade700
                                        : prestoOrange,
                                  ),
                                  _DashboardPill(
                                    label: 'Tickets ouverts',
                                    value: '$openTickets',
                                    color: openTickets > 0
                                        ? prestoOrange
                                        : prestoBlue,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _ActionCard(
                              icon: Icons.warning_rounded,
                              title: 'Dead letters',
                              subtitle:
                                  '${deadLetters.length} job(s) en échec terminal',
                              color: Colors.red.shade700,
                              onTap: () => _showDeadLettersSheet(
                                context,
                                deadLetters,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ActionCard(
                              icon: Icons.support_agent_rounded,
                              title: 'Tickets support',
                              subtitle:
                                  '$openTickets ouvert(s) sur ${tickets.length}',
                              color: prestoBlue,
                              onTap: () => _showSupportTicketsSheet(
                                context,
                                tickets,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.45,
                        children: [
                          _MetricCard(
                            label: 'Envoyés',
                            value: '${stats.sent}',
                            icon: Icons.send_rounded,
                            color: prestoBlue,
                          ),
                          _MetricCard(
                            label: 'Délivrés',
                            value: '${stats.delivered}',
                            icon: Icons.mark_email_read_rounded,
                            color: Colors.green.shade700,
                          ),
                          _MetricCard(
                            label: 'Bounces',
                            value: '${stats.bounced}',
                            icon: Icons.report_gmailerrorred_rounded,
                            color: Colors.red.shade700,
                          ),
                          _MetricCard(
                            label: 'Plaintes',
                            value: '${stats.complained}',
                            icon: Icons.feedback_rounded,
                            color: Colors.amber.shade800,
                          ),
                          _MetricCard(
                            label: 'Échecs',
                            value: '${stats.failed}',
                            icon: Icons.error_outline_rounded,
                            color: Colors.red.shade700,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Par provider',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (providerEntries.isEmpty)
                        const _SimpleAdminEmpty(
                          message: 'Aucun provider remonté sur cette fenêtre.',
                        )
                      else
                        ...providerEntries.map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _BreakdownCard(
                              title: entry.key,
                              data: entry.value,
                              accent: prestoBlue,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      const Text(
                        'Top templates',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (templateEntries.isEmpty)
                        const _SimpleAdminEmpty(
                          message: 'Aucun template remonté sur cette fenêtre.',
                        )
                      else
                        ...templateEntries.take(8).map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _BreakdownCard(
                              title: entry.key,
                              data: entry.value,
                              accent: prestoOrange,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

void _showDeadLettersSheet(
  BuildContext context,
  List<QueryDocumentSnapshot<Map<String, dynamic>>> deadLetters,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _BottomSheetScaffold(
      title: 'Dead letters',
      child: deadLetters.isEmpty
          ? const _SimpleAdminEmpty(
              message: 'Aucun dead letter sur la fenêtre sélectionnée.',
            )
          : Column(
              children: deadLetters
                  .map(
                    (doc) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _AdminListTile(
                        title: (doc.data()['template_code'] ?? doc.id).toString(),
                        subtitle:
                            'Raison: ${(doc.data()['dead_letter_reason'] ?? 'indisponible').toString()}\nMaj: ${_formatAdminTimestamp(_toInt(doc.data()['updated_at']))}',
                        trailing: _StatusBadge(
                          label: 'dead_letter',
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
    ),
  );
}

void _showSupportTicketsSheet(
  BuildContext context,
  List<QueryDocumentSnapshot<Map<String, dynamic>>> tickets,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _BottomSheetScaffold(
      title: 'Tickets support',
      child: tickets.isEmpty
          ? const _SimpleAdminEmpty(
              message: 'Aucun ticket support sur la fenêtre sélectionnée.',
            )
          : Column(
              children: tickets
                  .take(20)
                  .map(
                    (doc) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _AdminListTile(
                        title: (doc.data()['ticket_number'] ??
                                doc.data()['subject'] ??
                                doc.id)
                            .toString(),
                        subtitle:
                            '${(doc.data()['subject'] ?? 'Sans sujet').toString()}\n${(doc.data()['category'] ?? 'general_support').toString()} • ${_formatAdminTimestamp(_toInt(doc.data()['updated_at']))}',
                        trailing: _StatusBadge(
                          label: (doc.data()['status'] ?? 'open').toString(),
                          color: (doc.data()['status'] ?? 'open').toString() == 'open'
                              ? const Color(0xFFFF6600)
                              : const Color(0xFF1A73E8),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
    ),
  );
}

class _AdminSpacePageState extends State<AdminSpacePage> {
  static const Color prestoOrange = Color(0xFFFF6600);
  static const Color prestoBlue = Color(0xFF1A73E8);

  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  bool _userStatsLoading = true;
  Map<String, dynamic>? _userStats;

  @override
  void initState() {
    super.initState();
    _loadUserStats();
  }

  Future<void> _loadUserStats() async {
    setState(() => _userStatsLoading = true);
    try {
      final callable = _functions.httpsCallable(
        'adminGetUserStats',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
      );
      final res = await callable.call<dynamic>({});
      final data = (res.data is Map)
          ? Map<String, dynamic>.from(res.data as Map)
          : <String, dynamic>{};
      if (!mounted) return;
      setState(() {
        _userStats = data;
      });
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      showSuccessSnackBar(context, e.message ?? 'Erreur stats utilisateurs');
    } catch (e) {
      if (!mounted) return;
      showSuccessSnackBar(context, 'Erreur stats utilisateurs: $e');
    } finally {
      if (mounted) setState(() => _userStatsLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    final totalAccounts = (_userStats?['totalAccounts'] as num?)?.toInt();
    final onlineUsers = (_userStats?['onlineUsers'] as num?)?.toInt();
    final proLogins = (_userStats?['proLogins'] as num?)?.toInt();
    final windowMinutes = (_userStats?['windowMinutes'] as num?)?.toInt();

    final usersSubtitle = _userStatsLoading
        ? 'Chargement…'
        : (totalAccounts == null || onlineUsers == null || proLogins == null)
            ? '—'
            : 'Total: $totalAccounts\nEn ligne: $onlineUsers (${windowMinutes ?? 5} min)\nConnexions Pro: $proLogins';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        titleSpacing: 16,
        title: const Text(
          'Espace admin',
          style: kPrestoAppBarTitleStyle,
        ),
        actions: [
          _AdminChip(
            label: 'Admin',
            onTap: () {},
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gestion & configuration',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                "Paramètres système, modération et outils d’administration.",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 14),
              _ProfileCard(
                prestoBlue: prestoBlue,
                uid: user?.uid ?? '(non connecté)',
                role: 'Admin',
                lastLoginLabel: user?.metadata.lastSignInTime == null
                    ? 'Dernière connexion : (inconnue)'
                    : 'Dernière connexion : ${user!.metadata.lastSignInTime!.toLocal().toIso8601String()}',
                onCopyUid: () async {
                  await Clipboard.setData(ClipboardData(text: user?.uid ?? ''));
                  if (!context.mounted) return;
                  showSuccessSnackBar(context, 'UID copié');
                },
              ),
              const SizedBox(height: 14),
              GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: 150,
                ),
                children: [
                  _KpiTile(
                    icon: Icons.group_rounded,
                    title: 'Utilisateurs',
                    subtitle: usersSubtitle,
                    badge: null,
                    iconColor: prestoBlue,
                  ),
                  const _KpiTile(
                    icon: Icons.campaign_rounded,
                    title: 'Offres',
                    subtitle: '—',
                    badge: null,
                    iconColor: prestoOrange,
                  ),
                  const _KpiTile(
                    icon: Icons.chat_bubble_rounded,
                    title: 'Messages',
                    subtitle: '—',
                    badge: null,
                    iconColor: prestoBlue,
                  ),
                  const _KpiTile(
                    icon: Icons.verified_user_rounded,
                    title: 'Modération',
                    subtitle: '—',
                    badge: null,
                    iconColor: prestoBlue,
                  ),
                  const _KpiTile(
                    icon: Icons.workspace_premium_rounded,
                    title: 'Premium',
                    subtitle: '—',
                    badge: null,
                    iconColor: prestoOrange,
                  ),
                  _EmailSummaryTile(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const EmailDashboardPage(),
                        ),
                      );
                    },
                  ),
                  _KpiTile(
                    icon: Icons.tune_rounded,
                    title: 'Remote Config',
                    subtitle: 'Réglages IA',
                    badge: null,
                    iconColor: prestoBlue,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const MicroIaTranscriptionPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _AdminChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.black12),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: Colors.grey.shade200,
              child: const Icon(Icons.person_rounded,
                  size: 16, color: Colors.black54),
            ),
            const SizedBox(width: 8),
            const Text(
              'Admin',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final Color prestoBlue;
  final String uid;
  final String role;
  final String lastLoginLabel;
  final VoidCallback onCopyUid;

  const _ProfileCard({
    required this.prestoBlue,
    required this.uid,
    required this.role,
    required this.lastLoginLabel,
    required this.onCopyUid,
  });

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.grey.shade200,
                  child:
                      const Icon(Icons.person_rounded, color: Colors.black54),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Profil admin',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_rounded,
                          size: 16, color: Colors.green.shade700),
                      const SizedBox(width: 6),
                      Text(
                        'Actif',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.fingerprint_rounded,
                    size: 18, color: Colors.black54),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    uid,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onCopyUid,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copier'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black87,
                    side: const BorderSide(color: Colors.black12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: prestoBlue.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: prestoBlue.withOpacity(0.20)),
                  ),
                  child: Text(
                    role,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: prestoBlue,
                    ),
                  ),
                ),
                Text(
                  lastLoginLabel,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminInfoState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color color;

  const _AdminInfoState({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _CardShell(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 42, color: color),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SimpleAdminEmpty extends StatelessWidget {
  final String message;

  const _SimpleAdminEmpty({required this.message});

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          message,
          style: const TextStyle(
            color: Colors.black54,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _WindowChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _WindowChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFF6600) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFFFF6600) : Colors.black12,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomSheetScaffold extends StatelessWidget {
  final String title;
  final Widget child;

  const _BottomSheetScaffold({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF6F7F9),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 14),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminListTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget trailing;

  const _AdminListTile({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _EmailSummaryTile extends StatelessWidget {
  final VoidCallback onTap;

  const _EmailSummaryTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('system_settings')
        .doc('email_dashboard_current')
        .snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final metrics = _stringKeyMap(data?['metrics']);
        final sent = _toInt(metrics['sent']);
        final failed = _toInt(metrics['failed']);
        final deadLetters = _toInt(data?['recent_dead_letters']);
        final hours = _toInt(data?['window_hours']);

        final subtitle = snapshot.hasError
            ? 'Accès snapshot\nà vérifier'
            : data == null
                ? 'Aucun snapshot\ndisponible'
                : '${hours > 0 ? hours : 1} h\nEnvoyés: $sent\nÉchecs: $failed\nDL: $deadLetters';

        return _KpiTile(
          icon: Icons.mark_email_unread_rounded,
          title: 'Emails',
          subtitle: subtitle,
          badge: null,
          iconColor: const Color(0xFFFF6600),
          onTap: onTap,
        );
      },
    );
  }
}

class _DashboardPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _DashboardPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 26),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 24,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  final String title;
  final Map<String, dynamic> data;
  final Color accent;

  const _BreakdownCard({
    required this.title,
    required this.data,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final sent = _toInt(data['sent']);
    final delivered = _toInt(data['delivered']);
    final bounced = _toInt(data['bounced']);
    final complained = _toInt(data['complained']);
    final failed = _toInt(data['failed']);

    return _CardShell(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _DashboardPill(label: 'sent', value: '$sent', color: accent),
                _DashboardPill(
                  label: 'delivered',
                  value: '$delivered',
                  color: Colors.green.shade700,
                ),
                _DashboardPill(
                  label: 'bounced',
                  value: '$bounced',
                  color: Colors.red.shade700,
                ),
                _DashboardPill(
                  label: 'complained',
                  value: '$complained',
                  color: Colors.amber.shade800,
                ),
                _DashboardPill(
                  label: 'failed',
                  value: '$failed',
                  color: Colors.red.shade700,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final Color iconColor;
  final VoidCallback? onTap;

  const _KpiTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Stack(
            children: [
              if (badge != null)
                Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 28, color: iconColor),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Flexible(
                    child: Text(
                      subtitle,
                      softWrap: true,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MicroIaCard extends StatelessWidget {
  final Color prestoOrange;
  final Color prestoBlue;

  final MicroIaMode mode;
  final MicroIaAudioQuality audioQuality;
  final bool fallback;
  final double quality;
  final bool ultraFastEnabled;
  final List<String> languages;

  final ValueChanged<MicroIaMode> onModeChanged;
  final ValueChanged<bool> onUltraFastChanged;
  final ValueChanged<MicroIaAudioQuality> onAudioQualityChanged;
  final ValueChanged<bool> onFallbackChanged;
  final ValueChanged<double> onQualityChanged;
  final VoidCallback onAddLanguage;
  final ValueChanged<String> onRemoveLanguage;
  final VoidCallback? onSave;
  final bool saving;

  const _MicroIaCard({
    required this.prestoOrange,
    required this.prestoBlue,
    required this.mode,
    required this.audioQuality,
    required this.fallback,
    required this.quality,
    required this.ultraFastEnabled,
    required this.languages,
    required this.onModeChanged,
    required this.onUltraFastChanged,
    required this.onAudioQualityChanged,
    required this.onFallbackChanged,
    required this.onQualityChanged,
    required this.onAddLanguage,
    required this.onRemoveLanguage,
    required this.onSave,
    required this.saving,
  });

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Expanded(
                  child: Text(
                    'Micro-IA — Transcription',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Icon(Icons.more_horiz_rounded, color: Colors.black45),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (_, constraints) {
                final isWide = constraints.maxWidth >= 360;
                final padding = isWide ? 6.0 : 4.0;

                return Container(
                  padding: EdgeInsets.all(padding),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _SegButton(
                          label: 'Google STT',
                          selected: mode == MicroIaMode.google,
                          selectedColor: prestoOrange,
                          onTap: () => onModeChanged(MicroIaMode.google),
                        ),
                        const SizedBox(width: 6),
                        _SegButton(
                          label: 'Whisper',
                          selected: mode == MicroIaMode.whisper,
                          selectedColor: prestoOrange,
                          onTap: () => onModeChanged(MicroIaMode.whisper),
                        ),
                        const SizedBox(width: 6),
                        _SegButton(
                          label: 'Hybride',
                          selected: mode == MicroIaMode.hybride,
                          selectedColor: prestoOrange,
                          onTap: () => onModeChanged(MicroIaMode.hybride),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.bolt_rounded,
                                size: 18,
                                color: ultraFastEnabled
                                    ? prestoOrange
                                    : Colors.black54,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Ultra',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Transform.scale(
                                scale: 0.85,
                                child: Switch(
                                  value: ultraFastEnabled,
                                  activeColor: prestoOrange,
                                  onChanged: onUltraFastChanged,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              "Qualité audio",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (_, constraints) {
                final isWide = constraints.maxWidth >= 360;
                final padding = isWide ? 6.0 : 4.0;

                return Container(
                  padding: EdgeInsets.all(padding),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Row(
                    children: [
                      _SegButton(
                        label: 'Basse',
                        selected: audioQuality == MicroIaAudioQuality.low,
                        selectedColor: prestoOrange,
                        onTap: () =>
                            onAudioQualityChanged(MicroIaAudioQuality.low),
                      ),
                      const SizedBox(width: 6),
                      _SegButton(
                        label: 'Moyenne',
                        selected: audioQuality == MicroIaAudioQuality.medium,
                        selectedColor: prestoOrange,
                        onTap: () =>
                            onAudioQualityChanged(MicroIaAudioQuality.medium),
                      ),
                      const SizedBox(width: 6),
                      _SegButton(
                        label: 'Haute',
                        selected: audioQuality == MicroIaAudioQuality.high,
                        selectedColor: prestoOrange,
                        onTap: () =>
                            onAudioQualityChanged(MicroIaAudioQuality.high),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: prestoBlue.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.autorenew_rounded,
                      color: prestoBlue, size: 18),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fallback',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "Tente un autre provider si la qualité est faible",
                        style: TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: fallback,
                  onChanged: onFallbackChanged,
                  activeColor: prestoOrange,
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Qualité minimum',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: quality.clamp(0.0, 1.0),
                    min: 0,
                    max: 1,
                    divisions: 100,
                    activeColor: prestoOrange,
                    onChanged: onQualityChanged,
                  ),
                ),
                SizedBox(
                  width: 56,
                  child: Text(
                    quality.toStringAsFixed(2),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                    ),
                  ),
                )
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final code in languages)
                  _LangChip(
                    code: code,
                    onRemove: () => onRemoveLanguage(code),
                  ),
                _AddChip(onTap: onAddLanguage),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: onSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: prestoOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Enregistrer les changements'),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.green.shade700),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Config publiée (Remote Config)',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                    ),
                  ),
                )
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              '• Prise en compte quasi immédiate côté Functions',
              style: TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  const _SegButton({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? selectedColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: selected ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}

class _LangChip extends StatelessWidget {
  final String code;
  final VoidCallback onRemove;

  const _LangChip({required this.code, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            code,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(999),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.close_rounded, size: 16, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddChip extends StatelessWidget {
  final VoidCallback onTap;

  const _AddChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.black12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, size: 18, color: Colors.black87),
            SizedBox(width: 6),
            Text(
              'Ajouter',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  final Widget child;
  const _CardShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 8),
            color: Colors.black.withOpacity(0.08),
          ),
        ],
      ),
      child: child,
    );
  }
}
