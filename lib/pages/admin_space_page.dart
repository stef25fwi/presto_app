import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:presto_app/admin/listings/admin_listings_management_page.dart';
import 'package:presto_app/admin/messaging/admin_messaging_dashboard_page.dart';
import 'admin_hero_slides_page.dart';
import 'admin_messaging_moderation_page.dart';
import 'admin_photo_reviews_page.dart';
import 'admin_typography_page.dart';
import 'admin_monitoring_health_page.dart';
import '../models/admin_access_state.dart';
import '../utils/friendly_snackbar.dart';
import '../constants.dart';
import '../features/micro_ia/micro_ia_service.dart';
import '../features/subscriptions/subscription_widgets.dart';
import '../services/admin_access_resolver.dart';
import '../services/admin_broadcast_service.dart';
import '../services/firebase_functions_region.dart';
import '../services/notification_service.dart';
import 'package:presto_app/pages/admin/widgets/payment_info_audio_admin_section.dart';
import 'package:presto_app/pages/admin/ad_placeholder_images_admin_page.dart';

class AdminSpacePage extends StatefulWidget {
  const AdminSpacePage({super.key});

  @override
  State<AdminSpacePage> createState() => _AdminSpacePageState();
}

class _AdminMetricDomain {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> metrics;

  const _AdminMetricDomain({
    required this.title,
    required this.icon,
    required this.color,
    required this.metrics,
  });
}

class _FirebaseDeployDiagnosticRule {
  final String title;
  final IconData icon;
  final Color color;
  final String summary;
  final String action;
  final List<String> needles;

  const _FirebaseDeployDiagnosticRule({
    required this.title,
    required this.icon,
    required this.color,
    required this.summary,
    required this.action,
    required this.needles,
  });
}

const String _kFirestoreRulesDeployCommand =
    'firebase deploy --project presto-app-74abe --only firestore:rules';

const List<_FirebaseDeployDiagnosticRule> _kFirebaseDeployDiagnosticRules = [
  _FirebaseDeployDiagnosticRule(
    title: 'Authentification Firebase CLI',
    icon: Icons.login_rounded,
    color: Color(0xFF1A73E8),
    summary: 'Le terminal n’est plus authentifié ou la session CLI a expiré.',
    action:
        'Relance firebase login, vérifie le compte actif puis réessaie le déploiement.',
    needles: [
      'firebase login',
      'authentication error',
      'not logged in',
      'reauth',
      'login required',
    ],
  ),
  _FirebaseDeployDiagnosticRule(
    title: 'Permissions projet insuffisantes',
    icon: Icons.admin_panel_settings_rounded,
    color: Color(0xFFD93025),
    summary:
        'Le compte connecté n’a pas les droits nécessaires sur le projet Firebase.',
    action:
        'Vérifie l’owner du projet presto-app-74abe, les rôles IAM et le compte Google utilisé par la CLI.',
    needles: [
      'permission denied',
      'permission-denied',
      'insufficient permissions',
      'caller does not have permission',
      'http error: 403',
    ],
  ),
  _FirebaseDeployDiagnosticRule(
    title: 'Projet ou configuration Firebase invalide',
    icon: Icons.folder_off_rounded,
    color: Color(0xFFF29900),
    summary:
        'La CLI ne retrouve pas le projet, firebase.json ou la cible attendue.',
    action:
        'Vérifie le dossier courant, le project id, firebase.json et le chemin vers firestore.rules.',
    needles: [
      'failed to get firebase project',
      'project not found',
      'no currently active project',
      'firebase.json',
      'firestore.rules',
      'not in a firebase app directory',
    ],
  ),
  _FirebaseDeployDiagnosticRule(
    title: 'Erreur de syntaxe ou compilation des rules',
    icon: Icons.rule_folder_rounded,
    color: Color(0xFF8E24AA),
    summary:
        'Le fichier firestore.rules ne compile pas ou contient une règle invalide.',
    action:
        'Relis firestore.rules, corrige la ligne signalée puis relance uniquement les rules.',
    needles: [
      'error parsing firestore.rules',
      'compilation errors',
      'syntax error',
      'invalid rules',
      'ruleset',
    ],
  ),
  _FirebaseDeployDiagnosticRule(
    title: 'Réseau ou service Google indisponible',
    icon: Icons.cloud_off_rounded,
    color: Color(0xFF00897B),
    summary:
        'Le poste n’a pas réussi à joindre l’API Firebase ou Google Cloud.',
    action:
        'Teste la connectivité, relance plus tard si les API sont dégradées, puis réessaie le deploy.',
    needles: [
      'failed host lookup',
      'socketexception',
      'network error',
      'econnreset',
      'service unavailable',
      'etimedout',
      'deadline-exceeded',
    ],
  ),
  _FirebaseDeployDiagnosticRule(
    title: 'Quota, billing ou API Google Cloud',
    icon: Icons.account_balance_wallet_rounded,
    color: Color(0xFF6D4C41),
    summary:
        'Le projet n’a pas accès à la ressource requise ou a atteint une limite.',
    action:
        'Contrôle billing, quotas, APIs activées et l’état du projet dans Google Cloud Console.',
    needles: [
      'quota',
      'billing',
      'resource exhausted',
      'api has not been used',
      'enable it by visiting',
    ],
  ),
];

enum _MessagingModerationMode {
  visibleThenRetract,
  hiddenUntilValidated,
  hybrid,
}

_MessagingModerationMode _messagingModerationModeFromFirestoreValue(
  String value,
) {
  switch (value.trim().toLowerCase()) {
    case 'visible_then_retract':
      return _MessagingModerationMode.visibleThenRetract;
    case 'hidden_until_validated':
      return _MessagingModerationMode.hiddenUntilValidated;
    case 'hybrid':
      return _MessagingModerationMode.hybrid;
    default:
      return _MessagingModerationMode.hybrid;
  }
}

extension on _MessagingModerationMode {
  String get firestoreValue {
    switch (this) {
      case _MessagingModerationMode.visibleThenRetract:
        return 'visible_then_retract';
      case _MessagingModerationMode.hiddenUntilValidated:
        return 'hidden_until_validated';
      case _MessagingModerationMode.hybrid:
        return 'hybrid';
    }
  }

  String get label {
    switch (this) {
      case _MessagingModerationMode.visibleThenRetract:
        return 'Visible puis retrait';
      case _MessagingModerationMode.hiddenUntilValidated:
        return 'Masqué avant validation';
      case _MessagingModerationMode.hybrid:
        return 'Hybride';
    }
  }

  String get description {
    switch (this) {
      case _MessagingModerationMode.visibleThenRetract:
        return 'Le message part tout de suite, puis est retiré si la modération détecte un contenu interdit.';
      case _MessagingModerationMode.hiddenUntilValidated:
        return 'Le contenu reste masqué tant que la vérification texte ou image n a pas validé le message.';
      case _MessagingModerationMode.hybrid:
        return 'Les contenus sains restent fluides, les cas moyens ou risqués sont masqués ou basculés en revue.';
    }
  }
}

class _MessagingModerationConfigService {
  _MessagingModerationConfigService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _configRef =>
      _firestore.collection('appConfig').doc('marketplace');

  Stream<_MessagingModerationMode> watchMode({bool ensureExists = false}) {
    if (ensureExists) {
      unawaited(ensureDefaultConfigExists());
    }

    return _configRef.snapshots().map((snapshot) {
      final moderation = snapshot.data()?['moderation'];
      final rawMode = moderation is Map
          ? (moderation['messagingMode'] ?? '').toString()
          : '';
      return _messagingModerationModeFromFirestoreValue(rawMode);
    });
  }

  Future<void> ensureDefaultConfigExists({String? updatedBy}) async {
    final snapshot = await _configRef.get();
    final data = snapshot.data();
    final moderation = data?['moderation'];
    final hasMode = moderation is Map &&
        (moderation['messagingMode'] ?? '').toString().trim().isNotEmpty;
    if (hasMode) {
      return;
    }

    await _configRef.set(<String, dynamic>{
      'moderation': <String, dynamic>{
        'messagingMode': _MessagingModerationMode.hybrid.firestoreValue,
      },
      'updatedAt': FieldValue.serverTimestamp(),
      if (updatedBy != null && updatedBy.trim().isNotEmpty)
        'updatedBy': updatedBy.trim(),
    }, SetOptions(merge: true));
  }

  Future<void> updateMode(
    _MessagingModerationMode mode, {
    String? updatedBy,
  }) async {
    await _configRef.set(<String, dynamic>{
      'moderation': <String, dynamic>{'messagingMode': mode.firestoreValue},
      'updatedAt': FieldValue.serverTimestamp(),
      if (updatedBy != null && updatedBy.trim().isNotEmpty)
        'updatedBy': updatedBy.trim(),
    }, SetOptions(merge: true));
  }
}

class _AdminMessagingModerationTile extends StatefulWidget {
  const _AdminMessagingModerationTile();

  @override
  State<_AdminMessagingModerationTile> createState() =>
      _AdminMessagingModerationTileState();
}

class _AdminMessagingModerationTileState
    extends State<_AdminMessagingModerationTile> {
  final _service = _MessagingModerationConfigService();

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(
      _service.ensureDefaultConfigExists(
        updatedBy: FirebaseAuth.instance.currentUser?.uid,
      ),
    );
  }

  Future<void> _setMode(_MessagingModerationMode mode) async {
    if (_saving) return;

    setState(() => _saving = true);
    try {
      await _service.updateMode(
        mode,
        updatedBy: FirebaseAuth.instance.currentUser?.uid,
      );
      if (!mounted) return;
      showSuccessSnackBar(
        context,
        'Mode de modération messagerie mis à jour : ${mode.label}.',
      );
    } catch (_) {
      if (!mounted) return;
      showErrorSnackBar(
        context,
        'Impossible de mettre à jour la modération messagerie.',
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const titleColor = Color(0xFF111827);
    const subtitleColor = Color(0xFF6B7280);
    const accentColor = Color(0xFF0F766E);

    return StreamBuilder<_MessagingModerationMode>(
      stream: _service.watchMode(ensureExists: true),
      builder: (context, snapshot) {
        final mode = snapshot.data ?? _MessagingModerationMode.hybrid;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.shield_rounded, color: accentColor),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Modération messagerie',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: titleColor,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Choisir le niveau de contrôle des messages texte et image.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: subtitleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SegmentedButton<_MessagingModerationMode>(
                segments: const [
                  ButtonSegment(
                    value: _MessagingModerationMode.visibleThenRetract,
                    label: Text('Souple'),
                    icon: Icon(Icons.bolt_rounded),
                  ),
                  ButtonSegment(
                    value: _MessagingModerationMode.hiddenUntilValidated,
                    label: Text('Strict'),
                    icon: Icon(Icons.visibility_off_rounded),
                  ),
                  ButtonSegment(
                    value: _MessagingModerationMode.hybrid,
                    label: Text('Hybride'),
                    icon: Icon(Icons.tune_rounded),
                  ),
                ],
                selected: {mode},
                onSelectionChanged:
                    _saving ? null : (selection) => _setMode(selection.first),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ModeBadge(label: 'Mode actif : ${mode.label}'),
                  _ModeBadge(label: 'Clé Firestore : ${mode.firestoreValue}'),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mode.label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      mode.description,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: subtitleColor,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ModeBadge extends StatelessWidget {
  final String label;

  const _ModeBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE6FFFB),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0F766E),
        ),
      ),
    );
  }
}

const List<_AdminMetricDomain> _kAdminDashboardMetricDomains = [
  _AdminMetricDomain(
    title: 'Acquisition & trafic',
    icon: Icons.trending_up_rounded,
    color: Color(0xFF1A73E8),
    metrics: [
      'Visiteurs uniques (DAU / MAU)',
      'Sources de trafic (organique, direct, referral, paid)',
      'Taux d\'installation (si mobile)',
      'Coût par acquisition (CPA)',
    ],
  ),
  _AdminMetricDomain(
    title: 'Annonces & contenu',
    icon: Icons.campaign_rounded,
    color: Color(0xFFFF6600),
    metrics: [
      'Nombre d\'annonces publiées (total / par période)',
      'Annonces actives vs expirées vs supprimées',
      'Taux de publication (utilisateurs qui créent une annonce)',
      'Durée moyenne de vie d\'une annonce',
      'Catégories les plus populaires',
      'Annonces signalées / modérées',
    ],
  ),
  _AdminMetricDomain(
    title: 'Utilisateurs',
    icon: Icons.groups_rounded,
    color: Color(0xFF0F9D58),
    metrics: [
      'Nouveaux inscrits (par jour/semaine/mois)',
      'Taux de rétention (J1, J7, J30)',
      'Taux de churn',
      'Utilisateurs actifs vs dormants',
      'Ratio annonceurs / chercheurs',
      'Profils complétés vs incomplets',
    ],
  ),
  _AdminMetricDomain(
    title: 'Engagement',
    icon: Icons.insights_rounded,
    color: Color(0xFF8E24AA),
    metrics: [
      'Vues par annonce (moyenne)',
      'Taux de clics (CTR) sur les annonces',
      'Nombre de contacts / messages envoyés',
      'Taux de conversion (vue → contact)',
      'Temps passé sur l\'app',
      'Recherches effectuées (top queries)',
    ],
  ),
  _AdminMetricDomain(
    title: 'Transactions & revenus',
    icon: Icons.payments_rounded,
    color: Color(0xFF00897B),
    metrics: [
      'GMV (valeur brute des transactions)',
      'Revenus publicitaires / abonnements premium',
      'ARPU (revenu moyen par utilisateur)',
      'Taux de conversion vers offres payantes',
      'Remboursements / litiges',
    ],
  ),
  _AdminMetricDomain(
    title: 'Qualité & modération',
    icon: Icons.verified_user_rounded,
    color: Color(0xFFD81B60),
    metrics: [
      'Taux d\'annonces frauduleuses détectées',
      'Temps moyen de modération',
      'Nombre de signalements utilisateurs',
      'Taux de faux profils',
    ],
  ),
  _AdminMetricDomain(
    title: 'Technique & performance',
    icon: Icons.speed_rounded,
    color: Color(0xFF3949AB),
    metrics: [
      'Temps de chargement moyen',
      'Taux de crash / erreurs',
      'Disponibilité (uptime)',
      'Latence API',
    ],
  ),
];

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

  final FirebaseFunctions _functions = prestoFirebaseFunctions;

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

  Future<void> _prepareAdminCallableAuth() async {
    try {
      await MicroIaService.prepareSecureCallableContext(
        forceRefreshToken: true,
        forceRefreshAppCheckToken: true,
      );
    } catch (_) {
      // Best effort: the callable will still provide the definitive auth error.
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      await _prepareAdminCallableAuth();
      final callable = _functions.httpsCallable(
        'adminGetMicroIaConfig',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
      );
      HttpsCallableResult<dynamic> res;
      try {
        res = await callable.call<dynamic>({});
      } on FirebaseFunctionsException catch (e) {
        if (e.code != 'unauthenticated' && e.code != 'permission-denied') {
          rethrow;
        }
        await _prepareAdminCallableAuth();
        res = await callable.call<dynamic>({});
      }
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
      await _prepareAdminCallableAuth();
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
        backgroundColor: const Color(0xFF1A73E8),
        foregroundColor: Colors.white,
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
                      await _prepareAdminCallableAuth();
                      final callable = _functions.httpsCallable(
                        'adminSetMicroIaConfig',
                        options: HttpsCallableOptions(
                          timeout: const Duration(seconds: 30),
                        ),
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
    return value.map((key, entry) => MapEntry(key.toString(), entry));
  }
  return <String, dynamic>{};
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _toDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _asDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  try {
    final converted = (value as dynamic).toDate();
    if (converted is DateTime) {
      return converted;
    }
  } catch (_) {
    // no-op
  }
  return null;
}

DateTime _startOfDay(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String _dateKey(DateTime value) {
  String two(int part) => part.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)}';
}

int? _bucketIndexFor(DateTime? value, DateTime start, int bucketCount) {
  if (value == null) return null;
  final normalized = _startOfDay(value);
  final diff = normalized.difference(start).inDays;
  if (diff < 0 || diff >= bucketCount) return null;
  return diff;
}

String _formatCompactNumber(num value) {
  final absValue = value.abs();
  if (absValue >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (absValue >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}k';
  }
  if (value is int || value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(1);
}

String _formatPercent(double ratio) {
  if (!ratio.isFinite) return '—';
  final percent = ratio * 100;
  final decimals = percent >= 10 ? 0 : 1;
  return '${percent.toStringAsFixed(decimals)} %';
}

bool _isCompleteAdminUser(Map<String, dynamic> data) {
  final hasIdentity = [
    data['displayName'],
    data['pseudo'],
    data['userName'],
    data['name'],
  ].any((value) => value != null && value.toString().trim().isNotEmpty);
  final hasPhone = [
    data['phone'],
    data['phoneNumber'],
    data['phone_number'],
  ].any((value) => value != null && value.toString().trim().isNotEmpty);
  final hasLocation = [
    data['city'],
    data['cityId'],
    data['postalCode'],
    data['cp'],
    data['companyName'],
  ].any((value) => value != null && value.toString().trim().isNotEmpty);
  final hasAvatar = [
    data['avatarUrl'],
    data['photoUrl'],
    data['photoURL'],
    data['profilePhotoUrl'],
    data['imageUrl'],
  ].any((value) => value != null && value.toString().trim().isNotEmpty);
  final score = [
    hasIdentity,
    hasPhone,
    hasLocation,
    hasAvatar,
  ].where((value) => value).length;
  return score >= 3;
}

String _topEntryLabel(Map<String, int> counts, {String fallback = '—'}) {
  String label = fallback;
  var best = -1;
  counts.forEach((key, value) {
    if (value > best && key.trim().isNotEmpty) {
      best = value;
      label = key;
    }
  });
  return label;
}

String _topSourceLabel(dynamic rawMap, {String fallback = 'à connecter'}) {
  final map = _stringKeyMap(rawMap);
  if (map.isEmpty) return fallback;
  String topLabel = fallback;
  var topValue = -1;
  map.forEach((key, value) {
    final current = _toInt(value);
    if (current > topValue && key.trim().isNotEmpty) {
      topValue = current;
      topLabel = key;
    }
  });
  return topLabel;
}

String _escapeCsv(String value) {
  final needsQuotes =
      value.contains(',') || value.contains('\n') || value.contains('"');
  final escaped = value.replaceAll('"', '""');
  return needsQuotes ? '"$escaped"' : escaped;
}

String _buildAdminDomainCsv({
  required _AdminDomainLiveData data,
  required _AdminDashboardWindow window,
}) {
  final rows = <String>['domaine,periode,type,label,valeur'];

  for (final stat in data.highlights) {
    rows.add(
      [
        data.domain.title,
        window.label,
        'highlight',
        stat.label,
        stat.value,
      ].map(_escapeCsv).join(','),
    );
  }

  for (var index = 0; index < data.series.length; index += 1) {
    rows.add(
      [
        data.domain.title,
        window.label,
        'trend_point',
        'jour_${index + 1}',
        data.series[index].toStringAsFixed(2),
      ].map(_escapeCsv).join(','),
    );
  }

  for (final metric in data.domain.metrics) {
    rows.add(
      [
        data.domain.title,
        window.label,
        'catalog_metric',
        metric,
        '',
      ].map(_escapeCsv).join(','),
    );
  }

  rows.add(
    [
      data.domain.title,
      window.label,
      'note',
      'note',
      data.note,
    ].map(_escapeCsv).join(','),
  );

  return rows.join('\n');
}

String _formatAdminTimestamp(int? millis) {
  if (millis == null || millis <= 0) return 'inconnue';
  final dt = DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
}

enum _EmailDashboardWindow { hour1, day1, day7 }

enum _AdminDashboardWindow { day7, day30, day90 }

extension _AdminDashboardWindowX on _AdminDashboardWindow {
  String get label {
    switch (this) {
      case _AdminDashboardWindow.day7:
        return '7 jours';
      case _AdminDashboardWindow.day30:
        return '30 jours';
      case _AdminDashboardWindow.day90:
        return '90 jours';
    }
  }

  String get shortLabel {
    switch (this) {
      case _AdminDashboardWindow.day7:
        return '7j';
      case _AdminDashboardWindow.day30:
        return '30j';
      case _AdminDashboardWindow.day90:
        return '90j';
    }
  }

  int get dayCount {
    switch (this) {
      case _AdminDashboardWindow.day7:
        return 7;
      case _AdminDashboardWindow.day30:
        return 30;
      case _AdminDashboardWindow.day90:
        return 90;
    }
  }
}

class _AdminDashboardStat {
  final String label;
  final String value;

  const _AdminDashboardStat({required this.label, required this.value});
}

class _AdminDomainLiveData {
  final _AdminMetricDomain domain;
  final List<_AdminDashboardStat> highlights;
  final List<double> series;
  final String trendLabel;
  final String note;

  const _AdminDomainLiveData({
    required this.domain,
    required this.highlights,
    required this.series,
    required this.trendLabel,
    required this.note,
  });
}

class _AdminKpiSnapshot {
  final int publishedListings;
  final int activeListings;
  final int expiredListings;
  final int messagesStarted;
  final int reportedListings;
  final int blockedListings;
  final int manualReviewListings;
  final int activeSubscriptions;
  final int premiumUpgrades;

  const _AdminKpiSnapshot({
    required this.publishedListings,
    required this.activeListings,
    required this.expiredListings,
    required this.messagesStarted,
    required this.reportedListings,
    required this.blockedListings,
    required this.manualReviewListings,
    required this.activeSubscriptions,
    required this.premiumUpgrades,
  });
}

class _AdminDashboardComputed {
  final int newUsers;
  final int activeUsers;
  final int publishedListings;
  final int activeListings;
  final int expiredListings;
  final int listingViews;
  final int messagesStarted;
  final int premiumUpgrades;
  final int paidInvoices;
  final int failedInvoices;
  final double revenueAmount;
  final int reportedListings;
  final int blockedListings;
  final int manualReviewListings;
  final int activeSubscriptions;
  final List<_AdminDomainLiveData> domains;

  const _AdminDashboardComputed({
    required this.newUsers,
    required this.activeUsers,
    required this.publishedListings,
    required this.activeListings,
    required this.expiredListings,
    required this.listingViews,
    required this.messagesStarted,
    required this.premiumUpgrades,
    required this.paidInvoices,
    required this.failedInvoices,
    required this.revenueAmount,
    required this.reportedListings,
    required this.blockedListings,
    required this.manualReviewListings,
    required this.activeSubscriptions,
    required this.domains,
  });

  factory _AdminDashboardComputed.fromSources({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> userDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> activeUserDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> listingDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> analyticsDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> subscriptionDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> billingDocs,
    required Map<String, dynamic>? userStats,
    required _AdminDashboardWindow window,
    required List<_AdminMetricDomain> domains,
  }) {
    final totalAccounts = _toInt(userStats?['totalAccounts']);
    final onlineUsers = _toInt(userStats?['onlineUsers']);
    final start = _startOfDay(
      DateTime.now(),
    ).subtract(Duration(days: window.dayCount - 1));
    final bucketCount = window.dayCount;

    final userSeries = List<double>.filled(bucketCount, 0);
    final listingSeries = List<double>.filled(bucketCount, 0);
    final viewSeries = List<double>.filled(bucketCount, 0);
    final premiumSeries = List<double>.filled(bucketCount, 0);
    final billingSeries = List<double>.filled(bucketCount, 0);
    final moderationSeries = List<double>.filled(bucketCount, 0);
    final instrumentationSeries = List<double>.filled(bucketCount, 0);

    var completedProfiles = 0;
    for (final doc in userDocs) {
      final data = doc.data();
      if (_isCompleteAdminUser(data)) {
        completedProfiles += 1;
      }
      final index = _bucketIndexFor(
        _asDateTime(data['createdAt']),
        start,
        bucketCount,
      );
      if (index != null) {
        userSeries[index] += 1;
      }
    }

    final activeUsers = activeUserDocs.length;
    final dormantUsers =
        totalAccounts > activeUsers ? totalAccounts - activeUsers : 0;

    var activeListings = 0;
    var expiredListings = 0;
    var removedListings = 0;
    var reportedListings = 0;
    var blockedListings = 0;
    var manualReviewListings = 0;
    var totalRisk = 0.0;
    var lifespanDaysSum = 0.0;
    var lifespanCount = 0;
    var totalViews = 0;
    var totalContacts = 0;
    final owners = <String>{};
    final categoryCounts = <String, int>{};

    for (final doc in listingDocs) {
      final data = doc.data();
      final status = (data['status'] ?? '').toString().trim().toLowerCase();
      final moderation =
          (data['moderationStatus'] ?? '').toString().trim().toLowerCase();
      final expiresAt = _asDateTime(data['expiresAt']);
      final createdAt = _asDateTime(data['createdAt']);
      final publishedAt = _asDateTime(data['publishedAt']) ?? createdAt;
      final ownerId =
          (data['ownerId'] ?? data['userId'] ?? '').toString().trim();
      final categoryLabel =
          (data['category'] ?? data['categoryId'] ?? 'Sans catégorie')
              .toString()
              .trim();

      if (ownerId.isNotEmpty) {
        owners.add(ownerId);
      }
      if (categoryLabel.isNotEmpty) {
        categoryCounts.update(
          categoryLabel,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }

      if (status == 'active') {
        activeListings += 1;
      }
      if (expiresAt != null && expiresAt.isBefore(DateTime.now())) {
        expiredListings += 1;
      }
      if (status == 'deleted' || status == 'archived' || status == 'sold') {
        removedListings += 1;
      }

      final reportCount = _toInt(data['reportCount']);
      final viewCount = _toInt(data['viewCount']);
      final contactCount = _toInt(data['contactCount']);
      final riskScore = _toDouble(data['riskScore']);
      totalViews += viewCount;
      totalContacts += contactCount;
      totalRisk += riskScore;

      if (reportCount > 0) {
        reportedListings += 1;
      }
      if (moderation == 'blocked' || moderation == 'auto_flagged') {
        blockedListings += 1;
      }
      if (moderation == 'manual_review') {
        manualReviewListings += 1;
      }
      if (publishedAt != null && expiresAt != null) {
        lifespanDaysSum += expiresAt.difference(publishedAt).inHours / 24;
        lifespanCount += 1;
      }

      final index = _bucketIndexFor(createdAt, start, bucketCount);
      if (index != null) {
        listingSeries[index] += 1;
      }
    }

    final avgLifespanDays =
        lifespanCount == 0 ? 0.0 : lifespanDaysSum / lifespanCount;
    final avgRisk = listingDocs.isEmpty ? 0.0 : totalRisk / listingDocs.length;
    final conversionRatio = totalViews == 0 ? 0.0 : totalContacts / totalViews;
    final topCategory = _topEntryLabel(categoryCounts, fallback: '—');
    final advertiserRatio =
        activeUsers == 0 ? 0.0 : owners.length / activeUsers;

    final analyticsTotals = <String, int>{};
    var analyticsCoverageDays = 0;
    DateTime? latestAnalyticsDay;
    for (final doc in analyticsDocs) {
      final data = doc.data();
      if ((data['metricGroup'] ?? '').toString() != 'marketplace') {
        continue;
      }

      analyticsCoverageDays += 1;
      final date = DateTime.tryParse((data['dateKey'] ?? '').toString());
      if (date != null &&
          (latestAnalyticsDay == null || date.isAfter(latestAnalyticsDay))) {
        latestAnalyticsDay = date;
      }
      final index = _bucketIndexFor(date, start, bucketCount);
      final metrics = _stringKeyMap(data['metrics']);
      var totalDayEvents = 0;

      metrics.forEach((key, value) {
        final current = _toInt(value);
        analyticsTotals.update(
          key,
          (existing) => existing + current,
          ifAbsent: () => current,
        );
        totalDayEvents += current;
      });

      if (index != null) {
        viewSeries[index] += _toInt(metrics['listing_view']);
        premiumSeries[index] += _toInt(metrics['premium_upgrade_completed']);
        moderationSeries[index] += _toInt(metrics['listing_reported']);
        instrumentationSeries[index] += totalDayEvents;
      }
    }

    final searches = analyticsTotals['search_performed'] ?? 0;
    final messagesStarted = analyticsTotals['listing_message_started'] ?? 0;
    final premiumUpgrades = analyticsTotals['premium_upgrade_completed'] ?? 0;
    final reportEvents = analyticsTotals['listing_reported'] ?? 0;
    final totalTrackedEvents = analyticsTotals.values.fold<int>(
      0,
      (runningTotal, value) => runningTotal + value,
    );

    int sumByKeyPattern(RegExp pattern) {
      var sum = 0;
      analyticsTotals.forEach((key, value) {
        if (pattern.hasMatch(key)) {
          sum += value;
        }
      });
      return sum;
    }

    final errorEvents = sumByKeyPattern(
      RegExp(r'error|failed', caseSensitive: false),
    );
    final crashEvents = sumByKeyPattern(RegExp(r'crash', caseSensitive: false));

    double? metricFromMap(Map<String, dynamic> metrics, List<String> keys) {
      for (final key in keys) {
        if (metrics.containsKey(key)) {
          final value = _toDouble(metrics[key]);
          if (value > 0) return value;
        }
      }
      return null;
    }

    var latencySum = 0.0;
    var latencyCount = 0;
    var loadSum = 0.0;
    var loadCount = 0;
    for (final doc in analyticsDocs) {
      final data = doc.data();
      if ((data['metricGroup'] ?? '').toString() != 'marketplace') continue;
      final metrics = _stringKeyMap(data['metrics']);
      final latency = metricFromMap(metrics, const [
        'api_latency_ms_avg',
        'api_latency_ms',
        'latency_ms',
        'api_avg_ms',
      ]);
      if (latency != null) {
        latencySum += latency;
        latencyCount += 1;
      }
      final load = metricFromMap(metrics, const [
        'app_load_ms_avg',
        'app_load_ms',
        'app_start_ms',
        'page_load_ms',
      ]);
      if (load != null) {
        loadSum += load;
        loadCount += 1;
      }
    }

    final avgApiLatencyMs = latencyCount == 0 ? 0.0 : latencySum / latencyCount;
    final avgLoadMs = loadCount == 0 ? 0.0 : loadSum / loadCount;
    final errorCrashRate = totalTrackedEvents == 0
        ? 0.0
        : (errorEvents + crashEvents) / totalTrackedEvents;
    final uptimeRatio = (1.0 - errorCrashRate).clamp(0.0, 1.0);

    var activeSubscriptions = 0;
    for (final doc in subscriptionDocs) {
      final status =
          (doc.data()['status'] ?? '').toString().trim().toLowerCase();
      if (status == 'active' || status == 'trialing' || status == 'paid') {
        activeSubscriptions += 1;
      }
    }

    var paidInvoices = 0;
    var failedInvoices = 0;
    var refundOrDisputeCount = 0;
    var totalRevenue = 0.0;
    for (final doc in billingDocs) {
      final data = doc.data();
      final status = (data['status'] ?? '').toString().trim().toLowerCase();
      final amount = _toDouble(
        data['amount_paid'] ?? data['amount_due'] ?? data['amount'] ?? 0,
      );
      final issuedAt = _asDateTime(
        data['createdAt'] ?? data['issued_at'] ?? data['updatedAt'],
      );
      final index = _bucketIndexFor(issuedAt, start, bucketCount);
      if (status == 'paid' ||
          status == 'succeeded' ||
          status == 'payment_succeeded') {
        paidInvoices += 1;
        totalRevenue += amount;
        if (index != null) {
          billingSeries[index] += amount;
        }
      } else if (status == 'failed' || status == 'payment_failed') {
        failedInvoices += 1;
      } else if (status.contains('refund') ||
          status.contains('dispute') ||
          status.contains('chargeback')) {
        refundOrDisputeCount += 1;
      }
    }

    final arpu = activeUsers == 0 ? 0.0 : totalRevenue / activeUsers;
    final paidConversion =
        activeUsers == 0 ? 0.0 : activeSubscriptions / activeUsers;

    final topPlatform = _topSourceLabel(userStats?['loginsByPlatform']);
    final topMethod = _topSourceLabel(userStats?['loginsByMethod']);

    final domainByTitle = {for (final domain in domains) domain.title: domain};

    _AdminMetricDomain domain(String title) =>
        domainByTitle[title] ??
        _AdminMetricDomain(
          title: title,
          icon: Icons.dashboard,
          color: const Color(0xFF1A73E8),
          metrics: const [],
        );

    final liveDomains = [
      _AdminDomainLiveData(
        domain: domain('Acquisition & trafic'),
        highlights: [
          _AdminDashboardStat(
            label: 'Nouveaux',
            value: _formatCompactNumber(userDocs.length),
          ),
          _AdminDashboardStat(
            label: 'Actifs',
            value: _formatCompactNumber(activeUsers),
          ),
          _AdminDashboardStat(
            label: 'En ligne',
            value: _formatCompactNumber(onlineUsers),
          ),
          _AdminDashboardStat(label: 'Top accès', value: topPlatform),
        ],
        series: userSeries,
        trendLabel: 'Inscriptions / jour',
        note:
            'Méthode dominante: $topMethod • CPA et sources d’acquisition à connecter.',
      ),
      _AdminDomainLiveData(
        domain: domain('Annonces & contenu'),
        highlights: [
          _AdminDashboardStat(
            label: 'Publiées',
            value: _formatCompactNumber(listingDocs.length),
          ),
          _AdminDashboardStat(
            label: 'Actives',
            value: _formatCompactNumber(activeListings),
          ),
          _AdminDashboardStat(
            label: 'Expirées',
            value: _formatCompactNumber(expiredListings),
          ),
          _AdminDashboardStat(
            label: 'Vie moy.',
            value: avgLifespanDays <= 0
                ? '—'
                : '${avgLifespanDays.toStringAsFixed(1)} j',
          ),
        ],
        series: listingSeries,
        trendLabel: 'Annonces créées / jour',
        note:
            'Top catégorie: $topCategory • Supprimées/retirées: ${_formatCompactNumber(removedListings)} • Signalées: ${_formatCompactNumber(reportedListings)}.',
      ),
      _AdminDomainLiveData(
        domain: domain('Utilisateurs'),
        highlights: [
          _AdminDashboardStat(
            label: 'Total comptes',
            value: _formatCompactNumber(totalAccounts),
          ),
          _AdminDashboardStat(
            label: 'Dormants',
            value: _formatCompactNumber(dormantUsers),
          ),
          _AdminDashboardStat(
            label: 'Annonceurs',
            value: _formatCompactNumber(owners.length),
          ),
          _AdminDashboardStat(
            label: 'Profils complets',
            value:
                '${_formatCompactNumber(completedProfiles)}/${_formatCompactNumber(userDocs.length)}',
          ),
        ],
        series: userSeries,
        trendLabel: 'Nouveaux inscrits / jour',
        note:
            'Ratio annonceurs / actifs: ${_formatPercent(advertiserRatio)} • Rétention et churn à connecter.',
      ),
      _AdminDomainLiveData(
        domain: domain('Engagement'),
        highlights: [
          _AdminDashboardStat(
            label: 'Vues',
            value: _formatCompactNumber(totalViews),
          ),
          _AdminDashboardStat(
            label: 'Contacts',
            value: _formatCompactNumber(totalContacts),
          ),
          _AdminDashboardStat(
            label: 'Conv. vue→contact',
            value: _formatPercent(conversionRatio),
          ),
          _AdminDashboardStat(
            label: 'Recherches',
            value: _formatCompactNumber(searches),
          ),
        ],
        series: viewSeries,
        trendLabel: 'Vues annonces / jour',
        note:
            'Messages démarrés: ${_formatCompactNumber(messagesStarted)} • Temps passé et top queries détaillées à connecter.',
      ),
      _AdminDomainLiveData(
        domain: domain('Transactions & revenus'),
        highlights: [
          _AdminDashboardStat(
            label: 'Upgrades premium',
            value: _formatCompactNumber(premiumUpgrades),
          ),
          _AdminDashboardStat(
            label: 'Abonnements actifs',
            value: _formatCompactNumber(activeSubscriptions),
          ),
          _AdminDashboardStat(
            label: 'ARPU',
            value: arpu <= 0 ? '0 EUR' : '${arpu.toStringAsFixed(2)} EUR',
          ),
          _AdminDashboardStat(
            label: 'GMV',
            value: totalRevenue <= 0
                ? '0 EUR'
                : '${_formatCompactNumber(totalRevenue)} EUR',
          ),
        ],
        series: billingSeries,
        trendLabel: 'Revenus facturés / jour',
        note:
            'Factures payées: ${_formatCompactNumber(paidInvoices)} • Échecs: ${_formatCompactNumber(failedInvoices)} • Litiges/remboursements: ${_formatCompactNumber(refundOrDisputeCount)} • Conversion payante: ${_formatPercent(paidConversion)}.',
      ),
      _AdminDomainLiveData(
        domain: domain('Qualité & modération'),
        highlights: [
          _AdminDashboardStat(
            label: 'Signalements',
            value: _formatCompactNumber(
              reportEvents > reportedListings ? reportEvents : reportedListings,
            ),
          ),
          _AdminDashboardStat(
            label: 'Fraude détectée',
            value: _formatCompactNumber(blockedListings),
          ),
          _AdminDashboardStat(
            label: 'En revue',
            value: _formatCompactNumber(manualReviewListings),
          ),
          _AdminDashboardStat(
            label: 'Risque moyen',
            value: avgRisk <= 0 ? '0' : avgRisk.toStringAsFixed(1),
          ),
        ],
        series: moderationSeries,
        trendLabel: 'Signalements / jour',
        note:
            'Temps moyen de modération et faux profils restent à instrumenter côté backend.',
      ),
      _AdminDomainLiveData(
        domain: domain('Technique & performance'),
        highlights: [
          _AdminDashboardStat(
            label: 'Événements suivis',
            value: _formatCompactNumber(totalTrackedEvents),
          ),
          _AdminDashboardStat(
            label: 'Jours couverts',
            value: _formatCompactNumber(analyticsCoverageDays),
          ),
          _AdminDashboardStat(
            label: 'Dernière maj',
            value:
                latestAnalyticsDay == null ? '—' : _dateKey(latestAnalyticsDay),
          ),
          _AdminDashboardStat(
            label: 'Crash+erreurs',
            value: _formatPercent(errorCrashRate),
          ),
          _AdminDashboardStat(
            label: 'Uptime estimée',
            value: _formatPercent(uptimeRatio),
          ),
          _AdminDashboardStat(
            label: 'Latence API',
            value: avgApiLatencyMs <= 0
                ? 'n/d'
                : '${avgApiLatencyMs.toStringAsFixed(0)} ms',
          ),
          _AdminDashboardStat(
            label: 'Chargement moyen',
            value:
                avgLoadMs <= 0 ? 'n/d' : '${avgLoadMs.toStringAsFixed(0)} ms',
          ),
        ],
        series: instrumentationSeries,
        trendLabel: 'Événements instrumentés / jour',
        note:
            'Ces indicateurs techniques sont calculés automatiquement à partir des métriques présentes dans analyticsSnapshots.',
      ),
    ];

    return _AdminDashboardComputed(
      newUsers: userDocs.length,
      activeUsers: activeUsers,
      publishedListings: listingDocs.length,
      activeListings: activeListings,
      expiredListings: expiredListings,
      listingViews: totalViews,
      messagesStarted: messagesStarted,
      premiumUpgrades: premiumUpgrades,
      paidInvoices: paidInvoices,
      failedInvoices: failedInvoices,
      revenueAmount: totalRevenue,
      reportedListings: reportedListings,
      blockedListings: blockedListings,
      manualReviewListings: manualReviewListings,
      activeSubscriptions: activeSubscriptions,
      domains: liveDomains,
    );
  }
}

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

      incrementBucket(
        byProvider,
        provider.isEmpty ? 'unknown' : provider,
        status,
      );
      incrementBucket(
        byTemplate,
        template.isEmpty ? 'unknown' : template,
        status,
      );
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
        backgroundColor: const Color(0xFF1A73E8),
        foregroundColor: Colors.white,
        elevation: 0.5,
        titleSpacing: 16,
        title: const Text('Dashboard email', style: kPrestoAppBarTitleStyle),
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
            Expanded(child: _EmailDashboardContent(window: _window)),
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
    final threshold =
        DateTime.now().subtract(window.duration).millisecondsSinceEpoch;
    final logsStream = FirebaseFirestore.instance
        .collection('email_logs')
        .where('created_at', isGreaterThanOrEqualTo: threshold)
        .orderBy('created_at', descending: true)
        .limit(1000)
        .get()
        .asStream();
    final jobsStream = FirebaseFirestore.instance
        .collection('email_jobs')
        .where('updated_at', isGreaterThanOrEqualTo: threshold)
        .orderBy('updated_at', descending: true)
        .limit(60)
        .get()
        .asStream();
    final ticketsStream = FirebaseFirestore.instance
        .collection('support_tickets')
        .orderBy('updated_at', descending: true)
        .limit(60)
        .get()
        .asStream();

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

        final stats = _EmailDashboardStats.fromLogs(
          logsSnapshot.data?.docs ?? [],
        );

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
                .where(
                  (doc) =>
                      (doc.data()['status'] ?? '').toString() == 'dead_letter',
                )
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
                    .where(
                      (doc) => _toInt(doc.data()['updated_at']) >= threshold,
                    )
                    .toList();
                final openTickets = tickets
                    .where(
                      (doc) =>
                          (doc.data()['status'] ?? 'open').toString() == 'open',
                    )
                    .length;
                final hasAlert = deadLetters.isNotEmpty ||
                    stats.failed > 0 ||
                    stats.bounceRate >= 0.05 ||
                    stats.complaintRate >= 0.01;

                final providerEntries = stats.byProvider.entries.toList()
                  ..sort((a, b) {
                    return (b.value['sent'] ?? 0).compareTo(
                      a.value['sent'] ?? 0,
                    );
                  });
                final templateEntries = stats.byTemplate.entries.toList()
                  ..sort((a, b) {
                    return (b.value['sent'] ?? 0).compareTo(
                      a.value['sent'] ?? 0,
                    );
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
                                      color:
                                          (hasAlert ? Colors.red : prestoBlue)
                                              .withValues(alpha: 0.10),
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
                              onTap: () =>
                                  _showDeadLettersSheet(context, deadLetters),
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
                              onTap: () =>
                                  _showSupportTicketsSheet(context, tickets),
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
                        title:
                            (doc.data()['template_code'] ?? doc.id).toString(),
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
                          color: (doc.data()['status'] ?? 'open').toString() ==
                                  'open'
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

  final FirebaseFunctions _functions = prestoFirebaseFunctions;
  final AdminAccessResolver _adminAccessResolver = AdminAccessResolver();
  final TextEditingController _deployDiagnosticController =
      TextEditingController();

  bool _adminStatusLoading = true;
  bool _adminAccessGranted = false;
  String _adminMode = 'HYBRID';
  String _adminAccessSource = '';
  DateTime? _adminCheckedAt;
  Object? _adminStatusError;
  AdminAccessState? _adminAccessState;
  bool _userStatsLoading = true;
  Map<String, dynamic>? _userStats;
  _AdminKpiSnapshot? _kpiSnapshot;

  void _onKpiComputed(_AdminKpiSnapshot snapshot) {
    if (mounted) setState(() => _kpiSnapshot = snapshot);
  }

  @override
  void initState() {
    super.initState();
    _reloadAdminPage();
  }

  @override
  void dispose() {
    _deployDiagnosticController.dispose();
    super.dispose();
  }

  Future<User?> _ensureSignedInUser({bool forceRefreshToken = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return null;
    }

    try {
      await user.getIdToken(forceRefreshToken);
    } catch (e) {
      debugPrint('[AdminSpace] getIdToken failed: $e');
    }

    return FirebaseAuth.instance.currentUser ?? user;
  }

  Future<void> _reloadAdminPage() async {
    await _loadAdminStatus();
    if (!mounted || !_adminAccessGranted) {
      if (mounted) {
        setState(() {
          _userStatsLoading = false;
        });
      }
      return;
    }
    await _loadUserStats();
  }

  Future<void> _loadAdminStatus() async {
    setState(() {
      _adminStatusLoading = true;
      _adminAccessGranted = false;
      _adminAccessSource = '';
      _adminStatusError = null;
      _adminAccessState = null;
    });

    try {
      final accessState = await _adminAccessResolver
          .resolveAdminAccess(
        forceRefresh: true,
        returnOnLocalAdminEvidence: true,
      )
          .timeout(
        const Duration(seconds: 6),
        onTimeout: () {
          throw TimeoutException(
            'admin verification timed out after 6 seconds',
          );
        },
      );
      if (!mounted) return;
      setState(() {
        _adminAccessState = accessState;
        _adminAccessGranted = accessState.effectiveIsAdmin;
        _adminAccessSource = accessState.sourceOfTruth == 'none'
            ? ''
            : accessState.sourceOfTruth;
        _adminCheckedAt = accessState.serverCheckedAt ?? _adminCheckedAt;
        _adminStatusError = accessState.effectiveIsAdmin
            ? null
            : StateError(
                accessState.isAuthenticated
                    ? 'permission-denied: admin required'
                    : 'unauthenticated: no current user',
              );
      });
      debugPrint(
        '[AdminSpace] adminCheckComplete=true uid=${accessState.uid ?? '-'} '
        'isAdmin=${accessState.effectiveIsAdmin} '
        'source=${accessState.sourceOfTruth} '
        'tokenAdmin=${accessState.tokenHasAdmin} '
        'profileAdmin=${accessState.profileHasAdmin} '
        'loading=false',
      );

      if (!accessState.effectiveIsAdmin) {
        return;
      }

      try {
        await MicroIaService.prepareSecureCallableContext(
          forceRefreshToken: true,
          forceRefreshAppCheckToken: true,
        );
        final configCallable = _functions.httpsCallable(
          'adminGetMicroIaConfig',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
        );
        HttpsCallableResult<dynamic> configRes;
        try {
          configRes = await configCallable.call<dynamic>({});
        } on FirebaseFunctionsException catch (e) {
          if (e.code != 'unauthenticated' && e.code != 'permission-denied') {
            rethrow;
          }
          await MicroIaService.prepareSecureCallableContext(
            forceRefreshToken: true,
            forceRefreshAppCheckToken: true,
          );
          configRes = await configCallable.call<dynamic>({});
        }
        final configData = (configRes.data is Map)
            ? Map<String, dynamic>.from(configRes.data as Map)
            : <String, dynamic>{};
        if (!mounted) return;
        setState(() {
          _adminMode = (configData['mode'] ?? _adminMode).toString();
        });
      } catch (e) {
        debugPrint('[AdminSpace] adminGetMicroIaConfig failed: $e');
      }
    } catch (error) {
      if (!mounted) return;
      debugPrint(
        '[AdminSpace] adminCheckComplete=true isAdmin=false error=$error',
      );
      setState(() {
        _adminAccessGranted = false;
        _adminStatusError = error;
      });
    } finally {
      if (mounted) {
        setState(() {
          _adminStatusLoading = false;
        });
      }
    }
  }

  bool _isAdminAccessDenied(Object? error) {
    if (error is FirebaseFunctionsException) {
      return error.code == 'permission-denied' ||
          error.code == 'unauthenticated';
    }

    final errStr = error?.toString() ?? '';
    return errStr.contains('permission-denied') ||
        errStr.contains('unauthenticated');
  }

  String _adminErrorDetail(Object? error) {
    if (error is FirebaseFunctionsException) {
      final message = error.message?.trim();
      if (message != null && message.isNotEmpty) {
        return message;
      }

      switch (error.code) {
        case 'permission-denied':
          return 'Accès refusé par la fonction admin.';
        case 'unauthenticated':
          return 'Session non synchronisee avec le serveur. Recharge la page ou reconnecte-toi.';
        case 'unavailable':
          return 'Le service admin est indisponible ou le réseau ne répond pas.';
        case 'deadline-exceeded':
          return 'La vérification admin a dépassé le délai autorisé.';
        case 'internal':
          return 'La fonction admin a renvoyé une erreur interne.';
      }
    }

    final errStr = error?.toString().trim() ?? '';
    final errLower = errStr.toLowerCase();
    if (errLower.contains('socketexception') ||
        errLower.contains('network') ||
        errLower.contains('failed host lookup')) {
      return 'Échec réseau pendant la vérification admin.';
    }
    if (errLower.contains('timeout') ||
        errLower.contains('deadline-exceeded')) {
      return 'La vérification admin a expiré.';
    }
    if (errStr.isEmpty) {
      return 'Détail indisponible.';
    }
    return errStr;
  }

  String _adminModeLabel(String mode) {
    switch (mode) {
      case 'GOOGLE_ONLY':
        return 'Google uniquement';
      case 'WHISPER_ONLY':
        return 'Whisper uniquement';
      case 'HYBRID':
      default:
        return 'Hybride';
    }
  }

  List<_FirebaseDeployDiagnosticRule> _matchFirebaseDeployDiagnostics(
    String rawOutput,
  ) {
    final normalized = rawOutput.toLowerCase();
    return _kFirebaseDeployDiagnosticRules.where((rule) {
      return rule.needles.any(normalized.contains);
    }).toList();
  }

  Widget _buildFirebaseDeployDiagnosticPanel() {
    final rawOutput = _deployDiagnosticController.text.trim();
    final matches = _matchFirebaseDeployDiagnostics(rawOutput);
    final hasOutput = rawOutput.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_sync_rounded, color: prestoBlue),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Diagnostic Firebase deploy',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(
                    const ClipboardData(text: _kFirestoreRulesDeployCommand),
                  );
                  if (!mounted) return;
                  showSuccessSnackBar(context, 'Commande Firebase copiée');
                },
                icon: const Icon(Icons.copy_all_rounded, size: 16),
                label: const Text('Copier la commande'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Colle ici la sortie du terminal Codespaces pour mapper l’erreur de deploy vers une cause probable et une action utile.',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              _kFirestoreRulesDeployCommand,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _deployDiagnosticController,
            minLines: 5,
            maxLines: 8,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText:
                  'Colle ici la sortie firebase deploy --only firestore:rules',
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: hasOutput
                    ? () {
                        _deployDiagnosticController.clear();
                        setState(() {});
                      }
                    : null,
                icon: const Icon(Icons.clear_rounded),
                label: const Text('Vider'),
              ),
              const SizedBox(width: 10),
              if (hasOutput)
                Text(
                  matches.isEmpty
                      ? 'Aucun motif connu détecté'
                      : '${matches.length} diagnostic${matches.length > 1 ? 's' : ''} détecté${matches.length > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: matches.isEmpty ? Colors.black45 : prestoBlue,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (!hasOutput)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _kFirebaseDeployDiagnosticRules.take(4).map((rule) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: rule.color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    rule.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: rule.color,
                    ),
                  ),
                );
              }).toList(),
            ),
          if (hasOutput && matches.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black12),
              ),
              child: const Text(
                'La sortie ne correspond pas à un motif connu. Vérifie le project id, le compte CLI, le fichier firestore.rules et la connectivité réseau.',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
            ),
          if (matches.isNotEmpty) ...[
            for (final rule in matches) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: rule.color.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: rule.color.withValues(alpha: 0.22)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(rule.icon, color: rule.color),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            rule.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      rule.summary,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Action: ${rule.action}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildAdminStatusBanner() {
    if (_adminStatusLoading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: prestoBlue.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: prestoBlue.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: const [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Verification admin en cours pour cet espace.',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_adminStatusError != null) {
      final denied = _isAdminAccessDenied(_adminStatusError);
      final detail = _adminAccessSource.isNotEmpty
          ? 'Source serveur: $_adminAccessSource'
          : _adminErrorDetail(_adminStatusError);
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: denied ? Colors.red.shade50 : Colors.orange.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: denied ? Colors.red.shade200 : Colors.orange.shade200,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              denied
                  ? 'Acces admin non confirme'
                  : 'Controle admin indisponible',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              denied
                  ? 'Le chargement admin n est pas encore confirme pour cette session. Relance le controle apres synchronisation.'
                  : 'La verification admin a echoue temporairement. Relance le controle.',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Detail: $detail',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black45,
                fontSize: 12,
              ),
            ),
            if (_adminCheckedAt != null) ...[
              const SizedBox(height: 6),
              Text(
                'Dernier controle valide: ${_formatAdminTimestamp(_adminCheckedAt!.millisecondsSinceEpoch)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black45,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _reloadAdminPage,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Relancer le controle'),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: prestoBlue.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user_rounded, color: Colors.green.shade700),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Statut admin verifie',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Text(
                  'Verifie',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Mode serveur charge: ${_adminModeLabel(_adminMode)}.',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          if (_adminAccessState != null &&
              _adminAccessState!.serverCheckAttempted &&
              !_adminAccessState!.serverCheckSucceeded) ...[
            const SizedBox(height: 6),
            Text(
              'Vérification serveur temporairement indisponible, accès confirmé par ${_adminAccessSource.isNotEmpty ? _adminAccessSource : 'une source locale'}.',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.orange.shade700,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Dernier controle: ${_formatAdminTimestamp(_adminCheckedAt?.millisecondsSinceEpoch)}',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black45,
              fontSize: 12,
            ),
          ),
          if (_adminAccessSource.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Source droits admin: $_adminAccessSource',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black45,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: prestoBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Config Micro-IA chargee',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: prestoBlue.withValues(alpha: 0.92),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: prestoOrange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Pipeline: ${_adminModeLabel(_adminMode)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: prestoOrange.withValues(alpha: 0.92),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _loadUserStats() async {
    setState(() => _userStatsLoading = true);
    if (!_adminAccessGranted) {
      setState(() => _userStatsLoading = false);
      return;
    }
    try {
      final signedInUser = await _ensureSignedInUser(forceRefreshToken: true);
      if (signedInUser == null) {
        throw StateError('unauthenticated: no current user');
      }

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
      if (e.code == 'permission-denied' || e.code == 'unauthenticated') {
        final user = await _ensureSignedInUser(forceRefreshToken: true);
        if (user != null) {
          try {
            final callable = _functions.httpsCallable(
              'adminGetUserStats',
              options: HttpsCallableOptions(
                timeout: const Duration(seconds: 15),
              ),
            );
            final res = await callable.call<dynamic>({});
            final data = (res.data is Map)
                ? Map<String, dynamic>.from(res.data as Map)
                : <String, dynamic>{};
            if (!mounted) return;
            setState(() {
              _userStats = data;
            });
            return;
          } catch (_) {}
        }
      }
      if (!mounted) return;
      showErrorSnackBar(context, e.message ?? 'Erreur stats utilisateurs');
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Erreur stats utilisateurs: $e');
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
        backgroundColor: const Color(0xFF1A73E8),
        foregroundColor: Colors.white,
        elevation: 0.5,
        titleSpacing: 16,
        title: const Text('Espace admin', style: kPrestoAppBarTitleStyle),
        actions: [
          _AdminChip(
            label: 'Admin',
            onTap: () {
              unawaited(_reloadAdminPage());
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 20),
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
              _buildAdminStatusBanner(),
              const SizedBox(height: 14),
              const AdminSubscriptionTile(),
              const SizedBox(height: 14),
              const _AdminMessagingModerationTile(),
              const SizedBox(height: 14),
              _AdminMessagingEntryCard(accessState: _adminAccessState),
              const SizedBox(height: 14),
              _buildFirebaseDeployDiagnosticPanel(),
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
                  _KpiTile(
                    icon: Icons.campaign_rounded,
                    title: 'Offres',
                    subtitle: _kpiSnapshot == null
                        ? 'Chargement…'
                        : 'Actives: ${_formatCompactNumber(_kpiSnapshot!.activeListings)}\nTotal: ${_formatCompactNumber(_kpiSnapshot!.publishedListings)}\nExpirées: ${_formatCompactNumber(_kpiSnapshot!.expiredListings)}',
                    badge: null,
                    iconColor: prestoOrange,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AdminListingsManagementPage(),
                        ),
                      );
                    },
                  ),
                  _KpiTile(
                    icon: Icons.chat_bubble_rounded,
                    title: 'Messages',
                    subtitle: _kpiSnapshot == null
                        ? 'Chargement…'
                        : _kpiSnapshot!.messagesStarted == 0
                            ? 'Aucun message\nenregistré'
                            : '${_formatCompactNumber(_kpiSnapshot!.messagesStarted)}\ndémarrés',
                    badge: null,
                    iconColor: prestoBlue,
                  ),
                  _KpiTile(
                    icon: Icons.verified_user_rounded,
                    title: 'Modération',
                    subtitle: _kpiSnapshot == null
                        ? 'Chargement…'
                        : (_kpiSnapshot!.reportedListings == 0 &&
                                _kpiSnapshot!.blockedListings == 0)
                            ? 'Aucune alerte\nen cours'
                            : 'Signalées: ${_formatCompactNumber(_kpiSnapshot!.reportedListings)}\nBloquées: ${_formatCompactNumber(_kpiSnapshot!.blockedListings)}\nEn revue: ${_formatCompactNumber(_kpiSnapshot!.manualReviewListings)}',
                    badge: null,
                    iconColor: prestoBlue,
                  ),
                  _KpiTile(
                    icon: Icons.admin_panel_settings_rounded,
                    title: 'Gestion messagerie',
                    subtitle: 'Dashboard, signalements, audit et réglages',
                    badge: null,
                    iconColor: const Color(0xFF0F766E),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => AdminMessagingDashboardPage(
                            accessState: _adminAccessState,
                          ),
                        ),
                      );
                    },
                  ),
                  _KpiTile(
                    icon: Icons.shield_outlined,
                    title: 'Messages modérés',
                    subtitle: 'Journal récent\ndes messages en revue',
                    badge: null,
                    iconColor: const Color(0xFF0F766E),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AdminMessagingModerationPage(),
                        ),
                      );
                    },
                  ),
                  _KpiTile(
                    icon: Icons.photo_library_outlined,
                    title: 'Photos à valider',
                    subtitle: 'Swipe gauche / droite',
                    badge: null,
                    iconColor: prestoOrange,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AdminPhotoReviewsPage(),
                        ),
                      );
                    },
                  ),
                  _KpiTile(
                    icon: Icons.workspace_premium_rounded,
                    title: 'Premium',
                    subtitle: _kpiSnapshot == null
                        ? 'Chargement…'
                        : 'Abonnements: ${_formatCompactNumber(_kpiSnapshot!.activeSubscriptions)}\nUpgrades: ${_formatCompactNumber(_kpiSnapshot!.premiumUpgrades)}',
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
                  _KpiTile(
                    icon: Icons.monitor_heart_rounded,
                    title: 'Monitoring',
                    subtitle: 'Santé app',
                    badge: null,
                    iconColor: prestoOrange,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AdminMonitoringHealthPage(),
                        ),
                      );
                    },
                  ),
                  _KpiTile(
                    icon: Icons.slideshow_rounded,
                    title: "Gestion du Hero",
                    subtitle: "Accueil: ajouter, supprimer et réordonner",
                    badge: null,
                    iconColor: prestoOrange,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AdminHeroSlidesPage(),
                        ),
                      );
                    },
                  ),
                  _KpiTile(
                    icon: Icons.photo_library_outlined,
                    title: 'Images placeholders',
                    subtitle: 'AdBanner Je consulte',
                    badge: null,
                    iconColor: prestoOrange,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AdPlaceholderImagesAdminPage(),
                        ),
                      );
                    },
                  ),
                  _KpiTile(
                    icon: Icons.headphones_rounded,
                    title: "Audio popup",
                    subtitle: "Génération & import MP3",
                    badge: null,
                    iconColor: prestoBlue,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const _AudioPopupAdminPage(),
                        ),
                      );
                    },
                  ),
                  _KpiTile(
                    icon: Icons.notifications_active_rounded,
                    title: "Notification test",
                    subtitle: "Push à tous les utilisateurs",
                    badge: null,
                    iconColor: prestoOrange,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              const _BroadcastNotificationAdminPage(),
                        ),
                      );
                    },
                  ),
                  _KpiTile(
                    icon: Icons.text_fields_rounded,
                    title: "Typographie",
                    subtitle: "Police et taille pour toute l'application",
                    badge: null,
                    iconColor: prestoBlue,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AdminTypographyPage(),
                        ),
                      );
                    },
                  ),
                  if (!kReleaseMode)
                    _KpiTile(
                      icon: Icons.layers_rounded,
                      title: 'Catalogue pages',
                      subtitle: 'Inventaire et rendu par page',
                      badge: null,
                      iconColor: prestoBlue,
                      onTap: () {
                        Navigator.of(context).pushNamed('/page-catalog');
                      },
                    ),
                ],
              ),
              const SizedBox(height: 18),
              _AdminDashboardSection(
                userStats: _userStats,
                userStatsLoading: _userStatsLoading,
                domains: _kAdminDashboardMetricDomains,
                onComputed: _onKpiComputed,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AudioPopupAdminPage extends StatelessWidget {
  const _AudioPopupAdminPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        titleSpacing: 16,
        title: const Text(
          'Audio popup paiement',
          style: kPrestoAppBarTitleStyle,
        ),
      ),
      body: const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: PaymentInfoAudioAdminSection(),
        ),
      ),
    );
  }
}

enum _NotifTestTarget { me, all }

class _BroadcastNotificationAdminPage extends StatefulWidget {
  const _BroadcastNotificationAdminPage();

  @override
  State<_BroadcastNotificationAdminPage> createState() =>
      _BroadcastNotificationAdminPageState();
}

class _BroadcastNotificationAdminPageState
    extends State<_BroadcastNotificationAdminPage> {
  static const Color prestoOrange = Color(0xFFFF6600);

  final AdminBroadcastService _service = AdminBroadcastService();
  final TextEditingController _titleController = TextEditingController(
    text: 'Notification test',
  );
  final TextEditingController _bodyController = TextEditingController(
    text: 'Ceci est une notification test envoyée à tous les utilisateurs.',
  );

  _NotifTestTarget _target = _NotifTestTarget.me;
  bool _sending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _confirmAndSend() async {
    if (_sending) return;

    if (_target == _NotifTestTarget.all) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Envoyer à TOUS les utilisateurs ?'),
          content: const Text(
            'Cette notification push sera envoyée à tous les utilisateurs '
            'possédant un appareil enregistré. Cette action est irréversible.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: prestoOrange),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Envoyer à tous'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _sending = true);
    try {
      if (_target == _NotifTestTarget.me) {
        await _runSelfTest();
      } else {
        await _runBroadcast();
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _runBroadcast() async {
    try {
      final result = await _service.sendTestNotificationToAllUsers(
        title: _titleController.text,
        body: _bodyController.text,
      );
      if (!mounted) return;
      if (result.tokenCount == 0) {
        showErrorSnackBar(
          context,
          'Aucun appareil avec notifications activées '
          '(0 sur ${result.totalUsers} utilisateurs). '
          'Les utilisateurs doivent activer les notifications pour recevoir un push.',
        );
      } else {
        showSuccessSnackBar(
          context,
          'Envoyé : ${result.successCount}/${result.tokenCount} appareils '
          '— ${result.userCount} utilisateur(s) avec notifs activées '
          'sur ${result.totalUsers} au total.',
        );
      }
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      final message = error.code == 'permission-denied'
          ? 'Accès admin requis.'
          : (error.message ?? 'Erreur lors de l’envoi.');
      showErrorSnackBar(context, message);
    } catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Erreur lors de l’envoi : $error');
    }
  }

  Future<void> _runSelfTest() async {
    try {
      final notificationService = NotificationService();

      var registration = await notificationService.ensureDeviceRegistered();

      if (registration == DeviceRegistrationResult.permissionMissing) {
        final granted = await notificationService.requestPushPermission();
        if (!granted) {
          if (!mounted) return;
          showErrorSnackBar(
            context,
            notificationService.pushActivationFailureMessage(),
          );
          return;
        }
        registration = await notificationService.ensureDeviceRegistered();
      }

      if (registration == DeviceRegistrationResult.noToken ||
          registration == DeviceRegistrationResult.registrationFailed) {
        // Retry court: certains navigateurs délivrent le token après un second
        // passage (service worker / FCM web warmup).
        await Future<void>.delayed(const Duration(milliseconds: 350));
        registration = await notificationService.ensureDeviceRegistered();
      }

      if (registration != DeviceRegistrationResult.registered) {
        if (!mounted) return;
        showErrorSnackBar(context, _registrationIssueMessage(registration));
        return;
      }

      final count = await notificationService.sendSelfTestNotification();
      if (!mounted) return;
      showSuccessSnackBar(
        context,
        'Notification test envoyée à $count appareil(s). Verrouille ton écran : '
        'tu devrais la voir dans quelques secondes.',
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      final message = error.code == 'failed-precondition'
          ? 'Aucun appareil enregistré. Active les notifications puis recharge la page et réessaie.'
          : (error.message ?? 'Envoi du test impossible.');
      showErrorSnackBar(context, message);
    } catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Envoi du test impossible : $error');
    }
  }

  String _registrationIssueMessage(DeviceRegistrationResult result) {
    switch (result) {
      case DeviceRegistrationResult.permissionMissing:
        return 'Active d’abord les notifications dans Mon compte.';
      case DeviceRegistrationResult.noToken:
        return 'Impossible d’obtenir un jeton de notification sur cet appareil. '
            'Sur le web, recharge la page puis réessaie.';
      case DeviceRegistrationResult.registrationFailed:
        return 'Échec de l’enregistrement de l’appareil. Réessaie.';
      case DeviceRegistrationResult.registered:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A73E8),
        foregroundColor: Colors.white,
        elevation: 0.5,
        titleSpacing: 16,
        title: const Text('Notification test', style: kPrestoAppBarTitleStyle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<_NotifTestTarget>(
                segments: const [
                  ButtonSegment(
                    value: _NotifTestTarget.me,
                    label: Text('À moi'),
                    icon: Icon(Icons.person_outline),
                  ),
                  ButtonSegment(
                    value: _NotifTestTarget.all,
                    label: Text('À tous'),
                    icon: Icon(Icons.groups_outlined),
                  ),
                ],
                selected: {_target},
                onSelectionChanged: _sending
                    ? null
                    : (selection) => setState(() => _target = selection.first),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                color: const Color(0xFFFFF3EA),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _target == _NotifTestTarget.me
                            ? Icons.send_to_mobile_rounded
                            : Icons.campaign_rounded,
                        color: prestoOrange,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _target == _NotifTestTarget.me
                              ? 'Envoie une notification test sur TES appareils '
                                  'uniquement, pour vérifier la réception (écran '
                                  'verrouillé compris).'
                              : 'Envoie immédiatement la notification à TOUS les '
                                  'utilisateurs ayant un appareil enregistré. '
                                  'À utiliser avec précaution.',
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_target == _NotifTestTarget.all) ...[
                TextField(
                  controller: _titleController,
                  maxLength: 120,
                  enabled: !_sending,
                  decoration: const InputDecoration(
                    labelText: 'Titre',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _bodyController,
                  maxLength: 500,
                  maxLines: 4,
                  enabled: !_sending,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: prestoOrange,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _sending ? null : _confirmAndSend,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(
                  _sending
                      ? 'Envoi en cours...'
                      : _target == _NotifTestTarget.me
                          ? 'Envoyer sur mes appareils'
                          : 'Envoyer à tous les utilisateurs',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
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
  final VoidCallback? onTap;

  const _AdminChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final content = Container(
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
            child: const Icon(
              Icons.person_rounded,
              size: 16,
              color: Colors.black54,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return ExcludeSemantics(child: content);
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: content,
    );
  }
}

class _AdminDashboardSection extends StatefulWidget {
  final Map<String, dynamic>? userStats;
  final bool userStatsLoading;
  final List<_AdminMetricDomain> domains;
  final void Function(_AdminKpiSnapshot)? onComputed;

  const _AdminDashboardSection({
    required this.userStats,
    required this.userStatsLoading,
    required this.domains,
    this.onComputed,
  });

  @override
  State<_AdminDashboardSection> createState() => _AdminDashboardSectionState();
}

class _AdminDashboardSectionState extends State<_AdminDashboardSection> {
  _AdminDashboardWindow _window = _AdminDashboardWindow.day30;

  late Stream<QuerySnapshot<Map<String, dynamic>>> _usersStream;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _activeUsersStream;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _listingsStream;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _subscriptionsStream;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _billingInvoicesStream;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _analyticsStream;

  @override
  void initState() {
    super.initState();
    _rebuildStreams();
  }

  void _rebuildStreams() {
    final start = _startOfDay(
      DateTime.now(),
    ).subtract(Duration(days: _window.dayCount - 1));
    final startTimestamp = Timestamp.fromDate(start);
    _usersStream = FirebaseFirestore.instance
        .collection('users')
        .where('createdAt', isGreaterThanOrEqualTo: startTimestamp)
        .get()
        .asStream();
    _activeUsersStream = FirebaseFirestore.instance
        .collection('users')
        .where('lastSeenAt', isGreaterThanOrEqualTo: startTimestamp)
        .get()
        .asStream();
    _listingsStream = FirebaseFirestore.instance
        .collection('listings')
        .where('createdAt', isGreaterThanOrEqualTo: startTimestamp)
        .get()
        .asStream();
    _subscriptionsStream = FirebaseFirestore.instance
        .collection('subscriptions')
        .where('updatedAt', isGreaterThanOrEqualTo: startTimestamp)
        .get()
        .asStream();
    _billingInvoicesStream = FirebaseFirestore.instance
        .collection('billing_invoices')
        .where('updatedAt', isGreaterThanOrEqualTo: startTimestamp)
        .get()
        .asStream();
    _analyticsStream = FirebaseFirestore.instance
        .collection('analyticsSnapshots')
        .where('dateKey', isGreaterThanOrEqualTo: _dateKey(start))
        .get()
        .asStream();
  }

  Future<void> _openDomainDetails(_AdminDomainLiveData data) async {
    final csv = _buildAdminDomainCsv(data: data, window: _window);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _BottomSheetScaffold(
          title: 'Détails — ${data.domain.title}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final stat in data.highlights)
                    _DashboardPill(
                      label: stat.label,
                      value: stat.value,
                      color: data.domain.color,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _AdminMiniChart(
                color: data.domain.color,
                label: data.trendLabel,
                points: data.series,
              ),
              const SizedBox(height: 12),
              Text(
                data.note,
                style: const TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Catalogue métriques',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              ...data.domain.metrics.map(
                (metric) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '• $metric',
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: csv));
                        if (!sheetContext.mounted) return;
                        showSuccessSnackBar(sheetContext, 'CSV copié');
                      },
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Exporter CSV'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Dashboard admin: métriques clés',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
              ),
            ),
            _StatusBadge(
              label: _window.shortLabel,
              color: const Color(0xFF1A73E8),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Première vague branchée sur Firestore, Functions et analyticsSnapshots, avec filtre période et tendances miniatures.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final window in _AdminDashboardWindow.values)
              _WindowChip(
                label: window.label,
                selected: window == _window,
                onTap: () => setState(() {
                  _window = window;
                  _rebuildStreams();
                }),
              ),
          ],
        ),
        const SizedBox(height: 14),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _usersStream,
          builder: (context, usersSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _activeUsersStream,
              builder: (context, activeUsersSnapshot) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _listingsStream,
                  builder: (context, listingsSnapshot) {
                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _subscriptionsStream,
                      builder: (context, subscriptionsSnapshot) {
                        return StreamBuilder<
                            QuerySnapshot<Map<String, dynamic>>>(
                          stream: _billingInvoicesStream,
                          builder: (context, billingInvoicesSnapshot) {
                            return StreamBuilder<
                                QuerySnapshot<Map<String, dynamic>>>(
                              stream: _analyticsStream,
                              builder: (context, analyticsSnapshot) {
                                final hasError = usersSnapshot.hasError ||
                                    activeUsersSnapshot.hasError ||
                                    listingsSnapshot.hasError ||
                                    subscriptionsSnapshot.hasError ||
                                    billingInvoicesSnapshot.hasError ||
                                    analyticsSnapshot.hasError;
                                if (hasError) {
                                  return const _SimpleAdminEmpty(
                                    message:
                                        'Impossible de charger une partie des métriques admin. Vérifie les droits et les index Firestore.',
                                  );
                                }

                                final waiting = usersSnapshot.connectionState ==
                                        ConnectionState.waiting ||
                                    activeUsersSnapshot.connectionState ==
                                        ConnectionState.waiting ||
                                    listingsSnapshot.connectionState ==
                                        ConnectionState.waiting ||
                                    subscriptionsSnapshot.connectionState ==
                                        ConnectionState.waiting ||
                                    billingInvoicesSnapshot.connectionState ==
                                        ConnectionState.waiting ||
                                    analyticsSnapshot.connectionState ==
                                        ConnectionState.waiting;

                                final userDocs =
                                    usersSnapshot.data?.docs ?? const [];
                                final activeUserDocs =
                                    activeUsersSnapshot.data?.docs ?? const [];
                                final listingDocs =
                                    listingsSnapshot.data?.docs ?? const [];
                                final subscriptionDocs =
                                    subscriptionsSnapshot.data?.docs ??
                                        const [];
                                final billingDocs =
                                    billingInvoicesSnapshot.data?.docs ??
                                        const [];
                                final analyticsDocs =
                                    analyticsSnapshot.data?.docs ?? const [];

                                if (waiting &&
                                    userDocs.isEmpty &&
                                    activeUserDocs.isEmpty &&
                                    listingDocs.isEmpty &&
                                    analyticsDocs.isEmpty &&
                                    widget.userStatsLoading) {
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 24,
                                      ),
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }

                                final computed =
                                    _AdminDashboardComputed.fromSources(
                                  userDocs: userDocs,
                                  activeUserDocs: activeUserDocs,
                                  listingDocs: listingDocs,
                                  analyticsDocs: analyticsDocs,
                                  subscriptionDocs: subscriptionDocs,
                                  billingDocs: billingDocs,
                                  userStats: widget.userStats,
                                  window: _window,
                                  domains: widget.domains,
                                );

                                if (widget.onComputed != null) {
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (!mounted) return;
                                    widget.onComputed!(
                                      _AdminKpiSnapshot(
                                        publishedListings:
                                            computed.publishedListings,
                                        activeListings: computed.activeListings,
                                        expiredListings:
                                            computed.expiredListings,
                                        messagesStarted:
                                            computed.messagesStarted,
                                        reportedListings:
                                            computed.reportedListings,
                                        blockedListings:
                                            computed.blockedListings,
                                        manualReviewListings:
                                            computed.manualReviewListings,
                                        activeSubscriptions:
                                            computed.activeSubscriptions,
                                        premiumUpgrades:
                                            computed.premiumUpgrades,
                                      ),
                                    );
                                  });
                                }

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    GridView.count(
                                      crossAxisCount: 2,
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      mainAxisSpacing: 12,
                                      crossAxisSpacing: 12,
                                      childAspectRatio: 1.35,
                                      children: [
                                        _MetricCard(
                                          label: 'Nouveaux inscrits',
                                          value: _formatCompactNumber(
                                            computed.newUsers,
                                          ),
                                          icon: Icons.person_add_alt_1_rounded,
                                          color: const Color(0xFF1A73E8),
                                        ),
                                        _MetricCard(
                                          label: 'Utilisateurs actifs',
                                          value: _formatCompactNumber(
                                            computed.activeUsers,
                                          ),
                                          icon: Icons.groups_rounded,
                                          color: const Color(0xFF0F9D58),
                                        ),
                                        _MetricCard(
                                          label: 'Annonces publiées',
                                          value: _formatCompactNumber(
                                            computed.publishedListings,
                                          ),
                                          icon: Icons.campaign_rounded,
                                          color: const Color(0xFFFF6600),
                                        ),
                                        _MetricCard(
                                          label: 'Vues annonces',
                                          value: _formatCompactNumber(
                                            computed.listingViews,
                                          ),
                                          icon: Icons.visibility_rounded,
                                          color: const Color(0xFF8E24AA),
                                        ),
                                        _MetricCard(
                                          label: 'Factures payées',
                                          value: _formatCompactNumber(
                                            computed.paidInvoices,
                                          ),
                                          icon: Icons.receipt_long_rounded,
                                          color: const Color(0xFF00897B),
                                        ),
                                        _MetricCard(
                                          label: 'Revenu estimé',
                                          value: computed.revenueAmount <= 0
                                              ? '0 EUR'
                                              : '${_formatCompactNumber(computed.revenueAmount)} EUR',
                                          icon: Icons
                                              .account_balance_wallet_rounded,
                                          color: const Color(0xFF00897B),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    Column(
                                      children: [
                                        for (final domain
                                            in computed.domains) ...[
                                          _AdminMetricDomainCard(
                                            domain: domain.domain,
                                            highlights: domain.highlights,
                                            series: domain.series,
                                            trendLabel: domain.trendLabel,
                                            note: domain.note,
                                            onTap: () =>
                                                _openDomainDetails(domain),
                                          ),
                                          if (domain != computed.domains.last)
                                            const SizedBox(height: 12),
                                        ],
                                      ],
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _AdminMetricDomainCard extends StatelessWidget {
  final _AdminMetricDomain domain;
  final List<_AdminDashboardStat> highlights;
  final List<double> series;
  final String trendLabel;
  final String note;
  final VoidCallback? onTap;

  const _AdminMetricDomainCard({
    required this.domain,
    required this.highlights,
    required this.series,
    required this.trendLabel,
    required this.note,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
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
                      color: domain.color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: domain.color.withValues(alpha: 0.20),
                      ),
                    ),
                    child: Icon(domain.icon, color: domain.color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      domain.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final stat in highlights)
                    _DashboardPill(
                      label: stat.label,
                      value: stat.value,
                      color: domain.color,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _AdminMiniChart(
                color: domain.color,
                label: trendLabel,
                points: series,
              ),
              const SizedBox(height: 10),
              Text(
                note,
                style: const TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final metric in domain.metrics)
                    _AdminMetricPill(label: metric, color: domain.color),
                ],
              ),
              if (onTap != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Appuyer pour le détail + export CSV',
                  style: TextStyle(
                    color: domain.color,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminMiniChart extends StatelessWidget {
  final Color color;
  final String label;
  final List<double> points;

  const _AdminMiniChart({
    required this.color,
    required this.label,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 56,
            child: CustomPaint(
              painter: _AdminSparklinePainter(color: color, points: points),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminSparklinePainter extends CustomPainter {
  final Color color;
  final List<double> points;

  const _AdminSparklinePainter({required this.color, required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    final axisPaint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height - 1),
      Offset(size.width, size.height - 1),
      axisPaint,
    );

    if (points.isEmpty) {
      return;
    }

    var minValue = points.first;
    var maxValue = points.first;
    for (final point in points) {
      if (point < minValue) minValue = point;
      if (point > maxValue) maxValue = point;
    }

    final span = (maxValue - minValue).abs();
    final effectiveSpan = span <= 0 ? 1.0 : span;
    final xStep =
        points.length <= 1 ? size.width : size.width / (points.length - 1);

    final path = Path();
    final fillPath = Path();
    for (var index = 0; index < points.length; index += 1) {
      final x = xStep * index;
      final normalized = (points[index] - minValue) / effectiveSpan;
      final y = size.height - 8 - (normalized * (size.height - 16));
      if (index == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _AdminSparklinePainter oldDelegate) {
    if (oldDelegate.color != color) return true;
    if (oldDelegate.points.length != points.length) return true;
    for (var index = 0; index < points.length; index += 1) {
      if (oldDelegate.points[index] != points[index]) return true;
    }
    return false;
  }
}

class _AdminMetricPill extends StatelessWidget {
  final String label;
  final Color color;

  const _AdminMetricPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w700,
          height: 1.25,
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
                  child: const Icon(
                    Icons.person_rounded,
                    color: Colors.black54,
                  ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: Colors.green.shade700,
                      ),
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
                const Icon(
                  Icons.fingerprint_rounded,
                  size: 18,
                  color: Colors.black54,
                ),
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
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: prestoBlue.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: prestoBlue.withValues(alpha: 0.20),
                    ),
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

  const _BottomSheetScaffold({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
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

class _AdminMessagingEntryCard extends StatelessWidget {
  final AdminAccessState? accessState;

  const _AdminMessagingEntryCard({required this.accessState});

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  AdminMessagingDashboardPage(accessState: accessState),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F766E).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF0F766E).withValues(alpha: 0.18),
                  ),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: Color(0xFF0F766E),
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gestion messagerie',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Accès direct au dashboard, aux signalements, à l’audit et aux réglages.',
                      style: TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF0F766E),
                size: 28,
              ),
            ],
          ),
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
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.w800, color: color),
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
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
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
                                  activeThumbColor: prestoOrange,
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
                    color: prestoBlue.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.autorenew_rounded,
                    color: prestoBlue,
                    size: 18,
                  ),
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
                  activeThumbColor: prestoOrange,
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
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final code in languages)
                  _LangChip(code: code, onRemove: () => onRemoveLanguage(code)),
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
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
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
                ),
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
            color: Colors.black.withValues(alpha: 0.08),
          ),
        ],
      ),
      child: child,
    );
  }
}
