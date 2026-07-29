// toolbox_je_me_lance_page.dart
//
// Dépendances :
//   firebase_auth: ^x.x.x
//   cloud_firestore: ^x.x.x
//
// Firestore structure:
//   users/{uid}/parcours/{parcoursId}
//
// Usage:
//   Navigator.push(context, MaterialPageRoute(builder: (_) => const ToolboxJeMeLancePage()));
//
// Notes:
// - L'IA réelle (OpenAI/Gemini) pourra remplacer la fonction _computeRecommendationRules().
// - L'anti-copie / anti-capture sera ajouté plus tard.
//
// © You can freely adapt.

import 'dart:async';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:presto_app/features/subscriptions/journey_entitlements_service.dart';
import 'package:presto_app/features/subscriptions/subscription_action_placeholders.dart';
import 'package:presto_app/pages/account_page.dart';
import 'package:presto_app/pages/account/guided_journey_page.dart';
import 'package:presto_app/services/journey_local_storage_service.dart';
import 'package:presto_app/services/journey_pdf_export_service.dart';
import 'package:presto_app/services/parcours_fiches_service.dart';
import 'package:presto_app/services/screen_capture_protection_service.dart';
import 'package:presto_app/services/toolbox_cache_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_core.dart';
import '../data/city_postal_data.dart';
import '../services/je_me_lance_parcours_fiches_service.dart';
import '../services/region_resources_service.dart';

/// Construit l'instantané JSON-compatible d'un parcours personnalisé,
/// utilisé à la fois pour la sauvegarde locale explicite
/// ([JourneyLocalStorageService.saveSnapshot]) et pour l'historique
/// auto-écrasé ([JourneyLocalStorageService.saveHistorySnapshot]).
Map<String, dynamic> _buildJourneySnapshot({
  required String projectLabel,
  required String region,
  required String currentStatus,
  required String selectedActivity,
  required Map<String, dynamic> recommendation,
  required List<String> blockingAlerts,
  required Map<String, dynamic> costs,
  required List<Map<String, dynamic>> aides,
  required List<Map<String, dynamic>> plan30,
  required Map<String, dynamic> summary,
  required List<Map<String, dynamic>> regulationTutorial,
  required List<Map<String, dynamic>> statusWarnings,
  required Map<String, dynamic> recommendedLegalStatus,
  required List<Map<String, dynamic>> steps,
}) {
  return {
    'savedAt': DateTime.now().toIso8601String(),
    'projectLabel': projectLabel,
    'region': region,
    'currentStatus': currentStatus,
    'selectedActivity': selectedActivity,
    'recommendation': recommendation,
    'blockingAlerts': blockingAlerts,
    'costs': costs,
    'aides': aides,
    'plan30': plan30,
    'summary': summary,
    'regulationTutorial': regulationTutorial,
    'statusWarnings': statusWarnings,
    'recommendedLegalStatus': recommendedLegalStatus,
    'steps': steps,
  };
}

Future<void> _openExternalUrl(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Impossible d\'ouvrir $url')));
  }
}

List<RegionResource> _planContactsForTask(
  String region,
  String title, {
  String activity = '',
  String currentStatus = '',
}) {
  final resources = getRegionResources(region);
  if (resources.isEmpty) return const [];

  final lowerTitle = title.toLowerCase();
  final lowerActivity = activity.toLowerCase().trim();
  final lowerStatus = currentStatus.toLowerCase().trim();
  final isDromRegion = RegionResourcesService.isDROM(region);
  final isArtisanActivity =
      lowerActivity.contains('artisan') ||
      lowerActivity.contains('btp') ||
      lowerActivity.contains('travaux') ||
      lowerActivity.contains('coiffure') ||
      lowerActivity.contains('esthétique') ||
      lowerActivity.contains('reparation') ||
      lowerActivity.contains('réparation');
  final isCommerceActivity =
      lowerActivity.contains('commerce') ||
      lowerActivity.contains('vente') ||
      lowerActivity.contains('restauration') ||
      lowerActivity.contains('livraison');
  final isServiceActivity =
      lowerActivity.contains('conseil') ||
      lowerActivity.contains('formation') ||
      lowerActivity.contains('digitale') ||
      lowerActivity.contains('événementiel') ||
      lowerActivity.contains('evenementiel');
  final selected = <RegionResource>[];

  void addMatches(List<String> patterns) {
    for (final resource in resources) {
      final haystacks = [
        resource.name.toLowerCase(),
        resource.description.toLowerCase(),
      ];
      final matches = patterns.any(
        (pattern) => haystacks.any((text) => text.contains(pattern)),
      );
      final alreadyAdded = selected.any((item) => item.url == resource.url);
      if (matches && !alreadyAdded) {
        selected.add(resource);
      }
    }
  }

  if (lowerTitle.contains('guichet unique') ||
      lowerTitle.contains('formalit') ||
      lowerTitle.contains('deposer')) {
    addMatches(['inpi', 'urssaf']);
    if (isArtisanActivity) {
      addMatches(['artisanat']);
    } else if (isCommerceActivity) {
      addMatches(['cci']);
    }
  }

  if (lowerTitle.contains('acre') || lowerTitle.contains('france travail')) {
    addMatches(['france travail', 'urssaf']);
    if (isDromRegion) {
      addMatches(['lodeom', 'outre-mer']);
    }
  }

  if (lowerTitle.contains('cci') ||
      lowerTitle.contains('cma') ||
      lowerTitle.contains('bge') ||
      lowerTitle.contains('rdv')) {
    if (isArtisanActivity) {
      addMatches(['artisanat', 'bge', 'cci']);
    } else if (isCommerceActivity) {
      addMatches(['cci', 'bge', 'artisanat']);
    } else if (isServiceActivity) {
      addMatches(['bge', 'cci', 'initiative france']);
    } else {
      addMatches(['cci', 'artisanat', 'bge']);
    }
  }

  if (lowerTitle.contains('aides-territoires') ||
      lowerTitle.contains('aide') ||
      lowerTitle.contains('subvention')) {
    addMatches([
      'aides locales',
      'aides-territoires',
      'bpifrance',
      'initiative france',
      'région',
      'collectivité',
    ]);
    if (lowerStatus.contains('demandeur')) {
      addMatches(['france travail']);
    }
    if (isDromRegion) {
      addMatches(['collectivité', 'outre-mer', 'ladom']);
    }
  }

  if (lowerTitle.contains('assurance') || lowerTitle.contains('banque')) {
    if (isArtisanActivity) {
      addMatches(['artisanat', 'cci', 'bpifrance']);
    } else {
      addMatches(['cci', 'bpifrance', 'artisanat']);
    }
  }

  if (lowerTitle.contains('client') ||
      lowerTitle.contains('offre') ||
      lowerTitle.contains('commerciale')) {
    if (isServiceActivity) {
      addMatches(['bge', 'reseau entreprendre', 'cci']);
    } else {
      addMatches(['cci', 'bge', 'reseau entreprendre']);
    }
  }

  if (lowerTitle.contains('autorisation') ||
      lowerTitle.contains('qualification') ||
      lowerTitle.contains('documents')) {
    if (isArtisanActivity) {
      addMatches(['artisanat', 'cci']);
    } else {
      addMatches(['cci', 'bge']);
    }
  }

  if (lowerStatus.contains('fonctionnaire') ||
      lowerStatus.contains('agent public')) {
    addMatches(['bge', 'cci']);
  }

  if (lowerStatus.contains('salari')) {
    addMatches(['bge', 'cci']);
  }

  if (isDromRegion) {
    addMatches(['collectivité', 'outre-mer']);
  }

  if (selected.isEmpty) {
    if (isArtisanActivity) {
      addMatches(['artisanat', 'cci', 'bge']);
    } else {
      addMatches(['cci', 'bge', 'urssaf']);
    }
  }

  return selected.take(3).toList();
}

class ToolboxJeMeLancePage extends StatefulWidget {
  const ToolboxJeMeLancePage({super.key});

  @override
  State<ToolboxJeMeLancePage> createState() => _ToolboxJeMeLancePageState();
}

class _ToolboxJeMeLancePageState extends State<ToolboxJeMeLancePage> {
  // Brand colors (Prestō-like)
  static const Color kOrange = Color(0xFFFF6600);
  static const Color kBlue = Color(0xFF1A73E8);
  static const Color kBg = Color(0xFFF6F7FB);
  static const Color kCardBg = Color(0xFFE8E8E8); // Gris clair pour les tuiles
  static const Color kTextDark = Color(0xFF071B4D);
  static const Color kMutedText = Color(0xFF66728A);
  static const Color kBorder = Color(0xFFE2E6EF);
  static const int kTotalSteps = 4;
  static const double kPageHorizontalPadding = 10;

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _cacheService = ToolboxCacheService();
  final _parcoursFichesService = ParcoursFichesService();

  // UI state
  int _step = 1; // 1..4
  bool _loading = true;
  bool _saving = false;
  bool _isLocalOnlyMode = false;
  bool _showStarterErrors = false;
  String? _error;
  String _journeyStatus = 'draft';

  // Parcours Firestore
  String? _parcoursId;
  bool _isFromCache = false;

  // Form fields
  final TextEditingController _projectCtrl = TextEditingController();
  final TextEditingController _regionCtrl = TextEditingController();
  final TextEditingController _departementCtrl = TextEditingController();
  final TextEditingController _communeCtrl = TextEditingController();
  String _activityType = 'Prestation de services'; // default
  String _clientele = 'Particuliers (B2C)';
  String _businessModel = 'Ponctuel';
  String _selectedActivity = '';

  String _situation = ''; // Salarié / Fonctionnaire / etc.

  String _region = '';
  String _departement = '';
  String _commune = '';

  final List<String> _starterStatuses = const [
    'Salarié',
    'Fonctionnaire',
    'Demandeur d\'emploi',
    'Étudiant',
    'Indépendant',
    'Sans activité',
    'Retraité',
  ];

  List<String> get _availableActivities {
    final values = kCategorySubcategories.values
        .expand((items) => items)
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
    values.sort();
    return values;
  }

  String _resolveActivityTypeFromSelection(String activity) {
    for (final entry in kCategorySubcategories.entries) {
      if (entry.value.contains(activity)) {
        return entry.key;
      }
    }
    return 'Prestation de services';
  }

  // Extra fields (optional but useful)
  String _ambition = "Tester l'idée";
  double _caVise = 0;
  double _depensesPro = 0;
  String _besoinTva = 'Je ne sais pas';
  bool _association = false;
  bool _protectionPatrimoine = true;

  // Derived
  Map<String, dynamic> _recommendation = {};
  List<String> _blockingAlerts = [];
  Map<String, dynamic> _costs = {};
  List<Map<String, dynamic>> _plan30 = [];
  List<Map<String, dynamic>> _aides = [];
  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _regulationTutorial = [];
  List<Map<String, dynamic>> _statusWarnings = [];
  Map<String, dynamic> _recommendedLegalStatus = {};
  List<Map<String, dynamic>> _tutorialSteps = [];
  List<Map<String, dynamic>> _progressSteps = [];

  Timer? _autosaveDebounce;
  final ScrollController _pageScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _projectCtrl.addListener(_onAnyFieldChanged);
  }

  @override
  void dispose() {
    _autosaveDebounce?.cancel();
    _projectCtrl.dispose();
    _regionCtrl.dispose();
    _departementCtrl.dispose();
    _communeCtrl.dispose();
    _pageScrollController.dispose();
    super.dispose();
  }

  // --------------------------
  // Bootstrap: load or create parcours
  // --------------------------
  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> _tryFetchLatestParcours(
    String uid,
  ) async {
    final col = _db.collection('users').doc(uid).collection('parcours');

    // Tentative 1 : tri serveur sur updatedAt (peut échouer si types inconsistants)
    try {
      final snap = await col
          .orderBy('updatedAt', descending: true)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) return snap.docs.first;
      return null;
    } catch (e) {
      debugPrint('[Toolbox] latest parcours orderBy query failed: $e');
    }

    // Fallback 2 : lecture sans orderBy + sélection locale
    try {
      final snap = await col.limit(50).get();
      if (snap.docs.isEmpty) return null;

      QueryDocumentSnapshot<Map<String, dynamic>>? best;
      Timestamp? bestTs;

      for (final d in snap.docs) {
        final data = d.data();
        final v = data['updatedAt'];
        final ts = v is Timestamp ? v : null;
        if (ts == null) continue;
        if (bestTs == null || ts.compareTo(bestTs) > 0) {
          bestTs = ts;
          best = d;
        }
      }

      return best ?? snap.docs.first;
    } catch (e) {
      debugPrint('[Toolbox] latest parcours fallback query failed: $e');
      return null;
    }
  }

  Future<void> _prefillRegionFromProfile(String uid) async {
    if (_region.isNotEmpty) return;

    try {
      final snap = await _db.collection('users').doc(uid).get();
      final data = snap.data();
      if (data == null) return;

      final territory = (data['territory'] as Map?)?.cast<String, dynamic>();
      final profile = (data['profile'] as Map?)?.cast<String, dynamic>();

      final profileRegion =
          [territory?['region'], profile?['region'], data['region']]
              .map((value) => value?.toString().trim() ?? '')
              .firstWhere((value) => value.isNotEmpty, orElse: () => '');

      if (profileRegion.isEmpty) return;

      _region = profileRegion;
      _regionCtrl.text = profileRegion;
    } catch (e) {
      debugPrint('[Toolbox] profile region prefill skipped: $e');
    }
  }

  Future<void> _bootstrap() async {
    try {
      await JeMeLanceParcoursFichesService.instance.ensureLoaded();

      var user = _auth.currentUser;

      // Tentative de sign-in anonyme si utilisateur null
      if (user == null) {
        try {
          await _auth.signInAnonymously();
          user = _auth.currentUser;
        } catch (e) {
          // Pas d'obligation de connexion pour accéder à la boîte à outils.
          // Si l'auth anonyme est désactivée, on fonctionne en mode local (sans Firestore).
          user = null;
        }
      }

      if (user == null) {
        _parcoursId = null;
        _isLocalOnlyMode = true;
        _isFromCache = false;
        _journeyStatus = 'draft';
        _recomputeDerived();
        setState(() {
          _loading = false;
          _error = null;
        });
        return;
      }

      // Try to resume last updated parcours with fallback strategy
      final latest = await _tryFetchLatestParcours(user.uid);

      if (latest == null) {
        await _prefillRegionFromProfile(user.uid);

        // Créer un nouveau parcours
        final doc = _db
            .collection('users')
            .doc(user.uid)
            .collection('parcours')
            .doc();

        _parcoursId = doc.id;
        _journeyStatus = 'draft';
        _isLocalOnlyMode = false;
        _isFromCache = false;

        final now = FieldValue.serverTimestamp();
        await doc.set({
          'status': 'draft',
          'step': 1,
          'createdAt': now,
          'updatedAt': now,
          'data': _exportData(),
          'derived': _exportDerived(),
          'version': 1,
        });

        _recomputeDerived();
      } else {
        final d = latest;
        _parcoursId = d.id;

        final map = d.data();
        final data = (map['data'] as Map<String, dynamic>?) ?? {};
        final derived = (map['derived'] as Map<String, dynamic>?) ?? {};
        final step = (map['step'] as num?)?.toInt() ?? 1;
        final status = (map['status'] ?? 'draft').toString();

        _importData(data);
        _importDerived(derived);
        _step = step.clamp(1, kTotalSteps);
        _journeyStatus = status == 'completed' ? 'completed' : 'draft';
        _isLocalOnlyMode = false;
        _isFromCache = false;

        await _prefillRegionFromProfile(user.uid);

        // Répare `updatedAt` si absent/non-Timestamp (évite crashes orderBy futur)
        final updatedAt = map['updatedAt'];
        if (updatedAt == null || updatedAt is! Timestamp) {
          unawaited(
            _db
                .collection('users')
                .doc(user.uid)
                .collection('parcours')
                .doc(_parcoursId)
                .update({'updatedAt': FieldValue.serverTimestamp()}),
          );
        }
      }

      setState(() {
        _loading = false;
        _error = null;
      });
    } on FirebaseException catch (e) {
      debugPrint('[Toolbox] bootstrap firebase error: $e');
      final isDenied = e.code.toLowerCase() == 'permission-denied';
      if (isDenied) {
        // Si Firestore est inaccessible (App Check / règles / auth), on laisse l'utilisateur
        // accéder à la toolbox en mode local (sans persistance).
        _parcoursId = null;
        _isLocalOnlyMode = true;
        _isFromCache = false;
        _journeyStatus = 'draft';
        _recomputeDerived();
        setState(() {
          _loading = false;
          _error = null;
        });
        return;
      }

      setState(() {
        _loading = false;
        _error =
            'Le parcours est temporairement indisponible. Reessayez dans un instant.';
      });
    } catch (e) {
      debugPrint('[Toolbox] bootstrap error: $e');
      setState(() {
        _loading = false;
        _error =
            'Le parcours est temporairement indisponible. Reessayez dans un instant.';
      });
    }
  }

  // --------------------------
  // Autosave
  // --------------------------
  void _onAnyFieldChanged() {
    if (_journeyStatus == 'completed' && mounted) {
      setState(() => _journeyStatus = 'draft');
    }
    _autosaveDebounce?.cancel();
    _autosaveDebounce = Timer(const Duration(milliseconds: 500), () async {
      await _saveDraft();
    });
  }

  Future<void> _saveDraft({bool recompute = true}) async {
    final user = _auth.currentUser;
    if (user == null || _parcoursId == null) {
      if (recompute) {
        await _recomputeDerivedAsync();
        if (mounted) setState(() {});
      }
      return;
    }

    setState(() => _saving = true);
    try {
      if (recompute) {
        // Utiliser le cache si les critères clés sont remplis
        if (_projectCtrl.text.trim().isNotEmpty && _region.isNotEmpty) {
          await _recomputeDerivedWithCache();
        } else {
          _recomputeDerived();
        }
      }

      await _db
          .collection('users')
          .doc(user.uid)
          .collection('parcours')
          .doc(_parcoursId)
          .set({
            'status': _journeyStatus,
            'step': _step,
            'updatedAt': FieldValue.serverTimestamp(),
            'data': _exportData(),
            'derived': _exportDerived(),
          }, SetOptions(merge: true));

      if (mounted) setState(() => _saving = false);
    } on FirebaseException catch (e) {
      debugPrint('[Toolbox] save draft firebase error: $e');
      // Ne bloque pas l'écran si Firestore est interdit; on continue en mode non persistant.
      if (mounted) {
        setState(() {
          _saving = false;
          if (e.code.toLowerCase() != 'permission-denied') {
            _error =
                'Les modifications n ont pas pu etre enregistrees pour le moment.';
          }
        });
      }
    } catch (e) {
      debugPrint('[Toolbox] save draft error: $e');
      if (mounted) {
        setState(() {
          _saving = false;
          _error =
              'Les modifications n ont pas pu etre enregistrees pour le moment.';
        });
      }
    }
  }

  // --------------------------
  // Data import/export
  // --------------------------
  Map<String, dynamic> _exportData() => {
    'projectText': _projectCtrl.text.trim(),
    'selectedActivity': _selectedActivity,
    'activityType': _activityType,
    'clientele': _clientele,
    'businessModel': _businessModel,
    'situation': _situation,
    'territory': {
      'region': _region,
      'departement': _departement,
      'commune': _commune,
    },
    'ambition': _ambition,
    'caVise': _caVise,
    'depensesPro': _depensesPro,
    'besoinTva': _besoinTva,
    'association': _association,
    'protectionPatrimoine': _protectionPatrimoine,
  };

  void _importData(Map<String, dynamic> data) {
    _projectCtrl.text = (data['projectText'] ?? '') as String;
    _selectedActivity = (data['selectedActivity'] ?? '') as String;
    _activityType = (data['activityType'] ?? _activityType) as String;
    _clientele = (data['clientele'] ?? _clientele) as String;
    _businessModel = (data['businessModel'] ?? _businessModel) as String;

    _situation = (data['situation'] ?? '') as String;

    final t = (data['territory'] as Map?)?.cast<String, dynamic>() ?? {};
    _region = (t['region'] ?? '') as String;
    _departement = (t['departement'] ?? '') as String;
    _commune = (t['commune'] ?? '') as String;
    _regionCtrl.text = _region;
    _departementCtrl.text = _departement;
    _communeCtrl.text = _commune;

    _ambition = (data['ambition'] ?? _ambition) as String;
    _caVise = ((data['caVise'] ?? 0) as num).toDouble();
    _depensesPro = ((data['depensesPro'] ?? 0) as num).toDouble();
    _besoinTva = (data['besoinTva'] ?? _besoinTva) as String;
    _association = (data['association'] ?? _association) as bool;
    _protectionPatrimoine =
        (data['protectionPatrimoine'] ?? _protectionPatrimoine) as bool;

    _recomputeDerived();
  }

  Map<String, dynamic> _exportDerived() => {
    'recommendation': _recommendation,
    'blockingAlerts': _blockingAlerts,
    'costs': _costs,
    'plan30': _plan30,
    'aides': _aides,
    'summary': _summary,
    'regulationTutorial': _regulationTutorial,
    'statusWarnings': _statusWarnings,
    'recommendedLegalStatus': _recommendedLegalStatus,
    'steps': _tutorialSteps,
    'progress': {
      'completedSteps': _progressSteps
          .where((step) => (step['status'] ?? 'todo') == 'done')
          .map((step) => step['id'])
          .toList(),
      'currentStep':
          _progressSteps.indexWhere(
            (step) => (step['status'] ?? 'todo') != 'done',
          ) +
          1,
      'percent': _tutorialProgressValue,
    },
  };

  void _importDerived(Map<String, dynamic> derived) {
    _recommendation =
        (derived['recommendation'] as Map?)?.cast<String, dynamic>() ?? {};
    _blockingAlerts =
        (derived['blockingAlerts'] as List?)?.map((e) => '$e').toList() ?? [];
    _costs = (derived['costs'] as Map?)?.cast<String, dynamic>() ?? {};
    _plan30 =
        (derived['plan30'] as List?)
            ?.map((e) => (e as Map).cast<String, dynamic>())
            .toList() ??
        [];
    _aides =
        (derived['aides'] as List?)
            ?.map((e) => (e as Map).cast<String, dynamic>())
            .toList() ??
        [];
    _summary = (derived['summary'] as Map?)?.cast<String, dynamic>() ?? {};
    _regulationTutorial =
        (derived['regulationTutorial'] as List?)
            ?.map((e) => (e as Map).cast<String, dynamic>())
            .toList() ??
        [];
    _statusWarnings =
        (derived['statusWarnings'] as List?)
            ?.map((e) => (e as Map).cast<String, dynamic>())
            .toList() ??
        [];
    _recommendedLegalStatus =
        (derived['recommendedLegalStatus'] as Map?)?.cast<String, dynamic>() ??
        {};
    _tutorialSteps =
        (derived['steps'] as List?)
            ?.map((e) => (e as Map).cast<String, dynamic>())
            .toList() ??
        [];
    final progress =
        (derived['progress'] as Map?)?.cast<String, dynamic>() ?? {};
    final completedSteps =
        (progress['completedSteps'] as List?)?.map((e) => '$e').toSet() ??
        <String>{};
    if (_tutorialSteps.isNotEmpty) {
      _progressSteps = _tutorialSteps
          .map(
            (step) => {
              ...step,
              'status': completedSteps.contains('${step['id']}')
                  ? 'done'
                  : (step['status'] ?? 'todo'),
            },
          )
          .toList();
    } else {
      _progressSteps = [];
    }
  }

  void _applyDerivedResult(Map<String, dynamic> r) {
    _recommendation = (r['recommendation'] as Map).cast<String, dynamic>();
    _blockingAlerts = (r['blockingAlerts'] as List).cast<String>();
    _costs = (r['costs'] as Map).cast<String, dynamic>();
    _plan30 = (r['plan30'] as List)
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
    _aides = (r['aides'] as List)
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
    _summary = (r['summary'] as Map).cast<String, dynamic>();
    _regulationTutorial = (r['regulationTutorial'] as List)
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
    _statusWarnings = (r['statusWarnings'] as List)
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
    _recommendedLegalStatus = (r['recommendedLegalStatus'] as Map)
        .cast<String, dynamic>();
    _tutorialSteps = (r['steps'] as List)
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
    _progressSteps = _cloneProgressSteps(_tutorialSteps);
  }

  bool get _shouldUseFonctionnaireFiche {
    return _normalizedSituation == 'Fonctionnaire / agent public' &&
        _selectedActivity.trim().isNotEmpty;
  }

  /// Vrai dès qu'une fiche officielle (n'importe lequel des 7 packs
  /// statut+activité) correspond à la sélection actuelle. Sert à exclure ce
  /// parcours du cache partagé inter-utilisateurs `toolbox_journeys` : ce
  /// cache n'a aucune invalidation liée au contenu des fiches, donc un
  /// parcours mis en cache avant une évolution du pack (nouvelle activité,
  /// champ enrichi...) resterait servi tel quel indéfiniment. Les fiches
  /// étant des données locales et le calcul déterministe/peu coûteux, elles
  /// n'ont de toute façon pas besoin d'être mises en cache.
  bool get _hasMatchedParcoursFiche => _matchedParcoursFiche() != null;

  Future<Map<String, dynamic>> _computeDerivedData() async {
    final fallback = _computeRecommendationRules();
    if (!_shouldUseFonctionnaireFiche) {
      return fallback;
    }

    try {
      final firestored = await _parcoursFichesService
          .loadFonctionnaireDerivedData(
            activity: _selectedActivity,
            region: _region,
            currentStatus: _normalizedSituation,
            fallback: fallback,
          );
      return firestored ?? fallback;
    } catch (e) {
      debugPrint('[Toolbox] fonctionnaire parcours fiche fallback: $e');
      return fallback;
    }
  }

  Future<void> _recomputeDerivedAsync() async {
    _isFromCache = false;
    final r = await _computeDerivedData();
    _applyDerivedResult(r);
  }

  // --------------------------
  // Derived computation (RULES + CACHE)
  // --------------------------
  // Inclut statut + activité exacte dans la clé de cache : deux statuts
  // différents (ex. Fonctionnaire vs Salarié) sur la même activité/région ne
  // doivent jamais partager un parcours mis en cache (notamment le contenu
  // issu des fiches officielles, spécifique au statut Fonctionnaire).
  String get _cacheDomaineKey =>
      '${_projectCtrl.text.trim()}|$_normalizedSituation|$_selectedActivity';

  Future<void> _recomputeDerivedWithCache() async {
    if (_shouldUseFonctionnaireFiche || _hasMatchedParcoursFiche) {
      await _recomputeDerivedAsync();
      return;
    }

    // Essayer de récupérer depuis le cache
    final cachedJourney = await _cacheService.fetchExistingJourney(
      typeProjet: _activityType,
      domaine: _cacheDomaineKey,
      region: _region,
    );

    if (cachedJourney != null) {
      _isFromCache = true;
      debugPrint(
        '[Toolbox] cache hit ($_activityType / ${_projectCtrl.text.trim()} / $_region)',
      );
      _importDerived(cachedJourney['content'] as Map<String, dynamic>? ?? {});
    } else {
      _isFromCache = false;
      final r = await _computeDerivedData();
      _applyDerivedResult(r);

      // Sauvegarder le nouveau parcours généré en cache
      final journeyContent = {
        'recommendation': _recommendation,
        'blockingAlerts': _blockingAlerts,
        'costs': _costs,
        'plan30': _plan30,
        'aides': _aides,
        'summary': _summary,
        'regulationTutorial': _regulationTutorial,
        'statusWarnings': _statusWarnings,
        'recommendedLegalStatus': _recommendedLegalStatus,
        'steps': _progressSteps,
        'progress': {
          'completedSteps': <String>[],
          'currentStep': 1,
          'percent': 0,
        },
      };

      unawaited(
        _cacheService.saveNewJourney(
          typeProjet: _activityType,
          domaine: _cacheDomaineKey,
          region: _region,
          journeyContent: journeyContent,
        ),
      );
    }
  }

  void _recomputeDerived() {
    _isFromCache = false;
    final r = _computeRecommendationRules();
    _applyDerivedResult(r);
  }

  String get _normalizedSituation {
    switch (_situation) {
      case 'Fonctionnaire':
        return 'Fonctionnaire / agent public';
      case 'Demandeur d’emploi':
        return "Demandeur d'emploi";
      default:
        return _situation;
    }
  }

  Map<String, dynamic> _computeRecommendationRules() {
    final text = _projectCtrl.text.toLowerCase();
    final isDromRegion = isDROM(_region);
    final hasManyCosts = _depensesPro >= 8000; // tweak threshold
    final wantsGrowth =
        _ambition.contains('Croissance') ||
        _ambition.contains('Lever') ||
        _ambition.contains('Revenu principal') ||
        _caVise >= 60000;

    final likelyRegulatedKeywords = <String>[
      'alimentaire',
      'pâtisserie',
      'restaurant',
      'food truck',
      'snack',
      'vtc',
      'transport',
      'sécurité',
      'garderie',
      'enfant',
      'bâtiment',
      'électricité',
      'plomberie',
      'immobilier',
      'santé',
      'coiffure',
      'barber',
    ];

    final blocking = <String>[];
    if (likelyRegulatedKeywords.any((k) => text.contains(k))) {
      blocking.add(
        "Activité potentiellement réglementée : vérification (diplômes/assurances/autorisations) recommandée avant création.",
      );
    }
    if (_normalizedSituation == 'Fonctionnaire / agent public') {
      blocking.add(
        "Cumul : demande écrite hiérarchique + règles spécifiques (temps partiel / durée encadrée).",
      );
    }
    if (_normalizedSituation == "Demandeur d'emploi") {
      blocking.add(
        "Aides France Travail : attention au timing (ARCE/ACRE) avant certaines démarches.",
      );
    }

    final statusWarnings = _buildStatusWarnings();

    // Statut recommandé (simple rules)
    String statut;
    String why;
    String planB;

    if (!wantsGrowth &&
        !hasManyCosts &&
        _businessModel != 'Marketplace/plateforme') {
      statut = "Micro-entrepreneur";
      why =
          "Idéal pour tester rapidement, démarches simples, compta ultra légère.";
      planB =
          "Passer en EI au réel ou créer une SASU/EURL si croissance/frais élevés.";
    } else if (hasManyCosts && !_association && !wantsGrowth) {
      statut = "Entreprise Individuelle (EI) au réel";
      why =
          "Plus adapté si tu as beaucoup de frais : déduction plus fine qu'en micro.";
      planB =
          "Créer une EURL/SASU si besoin de séparation plus forte ou d'associés.";
    } else if (wantsGrowth ||
        _association ||
        _businessModel == 'Marketplace/plateforme') {
      statut = "SASU / SAS";
      why =
          "Adapté à la croissance, crédibilité, possible ouverture à des associés/investisseurs.";
      planB =
          "EURL/SARL si tu veux un cadre plus 'classique' et souvent moins coûteux à gérer selon cas.";
    } else {
      statut = "EURL / SARL";
      why =
          "Cadre stable et 'classique', souvent apprécié pour une petite structure.";
      planB = "SASU/SAS si projet innovant, croissance, associés, levée.";
    }

    // Costs (rough placeholders; you can localize later)
    final costs = <String, dynamic>{
      'formalitesEstimees': _estimateFormalites(statut),
      'annonceLegale': (statut.contains('SAS') || statut.contains('EURL'))
          ? 180
          : 0,
      'assuranceProAn': 250,
      'comptableAn': (statut.contains('SAS') || statut.contains('EURL'))
          ? 1200
          : 0,
      'banqueOutilsAn': 120,
      'note':
          "Estimations indicatives. Les montants varient selon activité et département.",
    };

    // Aides (checklist)
    final aides = <Map<String, dynamic>>[
      _aid("ACRE", "Exonération partielle de cotisations au démarrage", true),
      _aid(
        "ARCE",
        "Capital France Travail (si ARE + conditions)",
        _normalizedSituation == "Demandeur d'emploi",
      ),
      _aid("Prêt d'honneur", "Initiative France / Réseau Entreprendre", true),
      _aid(
        "Aides territoriales",
        "Région / Département / Agglo (selon territoire)",
        true,
      ),
      _aid(
        "Fonds européens",
        "FEDER / FSE+ / FEADER (via programmes régionaux)",
        true,
      ),
      if (isDromRegion) ...[
        _aid(
          "LODEOM",
          "Loi Outre-mer : exonérations renforcées de cotisations sociales au démarrage",
          true,
        ),
        _aid(
          "Aides CTM/CTG/CTD",
          "Aides de la collectivité territoriale locale selon votre DROM",
          true,
        ),
      ],
    ];

    // Plan 30 jours
    final plan = <Map<String, dynamic>>[
      _task("Semaine 1", "Vérifier activité réglementée (si concerné)"),
      _task("Semaine 1", "Choisir statut + option TVA"),
      _task("Semaine 1", "Lister 10 clients cibles + offre + tarif"),
      _task(
        "Semaine 2",
        _region.isNotEmpty
            ? "Contacter CCI/CMA/BGE de $_region et prendre 1 RDV"
            : "Contacter CCI/CMA/BGE local et prendre 1 RDV",
      ),
      _task(
        "Semaine 2",
        _region.isNotEmpty
            ? "Chercher aides sur Aides-territoires pour la région $_region"
            : "Chercher aides via Aides-territoires + Région",
      ),
      _task("Semaine 3", "Monter dossier ACRE / France Travail (si concerné)"),
      _task(
        "Semaine 3",
        "Préparer dossier subvention (résumé + budget + devis)",
      ),
      _task("Semaine 4", "Déposer formalités via guichet unique"),
      _task("Semaine 4", "Assurances + compte bancaire pro si nécessaire"),
      _task(
        "Semaine 4",
        "1ère action commerciale (prospection / pub / partenariats)",
      ),
    ];

    final regulationTutorial = _buildRegulationTutorial(
      isDromRegion: isDromRegion,
      hasRegulatedSignal: likelyRegulatedKeywords.any(
        (keyword) => text.contains(keyword),
      ),
    );
    final summary = _buildSummary(
      statut: statut,
      hasBlockingAlerts: blocking.isNotEmpty,
    );
    final recommendedLegalStatus = {
      'recommended': statut,
      'justification': why,
      'planB': planB,
      'disclaimer':
          'Cette recommandation est une orientation de démarrage. Elle ne remplace pas une validation juridique ou comptable adaptée à votre situation.',
    };
    final steps = _buildTutorialSteps();

    final Map<String, dynamic> result = {
      'recommendation': {
        'statut': statut,
        'why': why,
        'planB': planB,
        'priorites': _prioritiesGuess(),
      },
      'blockingAlerts': blocking,
      'costs': costs,
      'plan30': plan,
      'aides': aides,
      'summary': summary,
      'regulationTutorial': regulationTutorial,
      'statusWarnings': statusWarnings,
      'recommendedLegalStatus': recommendedLegalStatus,
      'steps': steps,
    };

    final fiche = _matchedParcoursFiche();
    if (fiche == null) return result;
    return _applyFicheToRecommendation(result, fiche);
  }

  // Statuts couverts par un pack de fiches officielles. Ajouter une entrée
  // ici suffit à brancher un nouveau statut une fois son pack déclaré dans
  // JeMeLanceParcoursFichesService.
  static const _ficheStatutParSituation = <String, String>{
    'Fonctionnaire / agent public': 'fonctionnaire',
    'Retraité': 'retraité',
    'Étudiant': 'étudiant',
    'Salarié': 'salarié',
    'Indépendant': 'indépendant',
    "Demandeur d'emploi": 'demandeur d’emploi',
    'Sans activité': 'sans activité',
  };

  // Sous-clés de `regles_<statut>` traitées comme alertes bloquantes
  // (mises en avant par les packs eux-mêmes, ex. mineur / titre de séjour
  // pour le statut Étudiant, alertes_generales pour le statut Salarié).
  // À étendre si un futur pack en ajoute.
  static const _reglesAlertKeys = <String>[
    'mineur',
    'titre_sejour',
    'alertes_generales',
  ];

  // Sous-clés de `regles_<statut>` utilisées comme checklist de la section
  // "Vérifier votre situation personnelle", par ordre de priorité (la
  // première clé non vide trouvée est utilisée).
  static const _reglesChecksPriorityKeys = <String>[
    'declaration_caisse',
    'bourse_assiduite',
    'fiscalite_etudiant',
    'clauses',
    'conditions',
    'actualisation',
  ];

  /// Fiche officielle (pack `parcoursFiches`) correspondant au statut et à
  /// l'activité actuellement sélectionnés, si elle existe.
  Map<String, dynamic>? _matchedParcoursFiche() {
    final ficheStatut = _ficheStatutParSituation[_normalizedSituation];
    if (ficheStatut == null) return null;
    if (_selectedActivity.trim().isEmpty) return null;
    return JeMeLanceParcoursFichesService.instance.find(
      statutUtilisateur: ficheStatut,
      activite: _selectedActivity,
    );
  }

  /// Alimente les sections du parcours personnalisé avec le contenu de la
  /// fiche officielle correspondante, sans changer la structure attendue
  /// par l'UI (mêmes clés/formes que la logique générique).
  Map<String, dynamic> _applyFicheToRecommendation(
    Map<String, dynamic> result,
    Map<String, dynamic> fiche,
  ) {
    String s(dynamic v) => (v ?? '').toString().trim();
    List<String> l(dynamic v) =>
        (v as List?)
            ?.map((e) => '$e'.trim())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const <String>[];
    String stripWeekPrefix(String text) {
      final idx = text.indexOf(':');
      final tail = idx == -1 ? text : text.substring(idx + 1).trim();
      return tail.isEmpty ? tail : tail[0].toUpperCase() + tail.substring(1);
    }

    final activite = s(fiche['activite']);
    final alertes = l(fiche['alertes']);
    final assurances = l(fiche['assurances']);
    final documents = l(fiche['documents_a_collecter']);
    final couts = l(fiche['couts_indicatifs']);
    final organismes = l(fiche['organismes_accompagnement']);
    final modesExercice = l(fiche['modes_exercice']);
    final statutAlternatif = l(fiche['statut_alternatif']);
    final parcours =
        (fiche['parcours'] as Map?)?.cast<String, dynamic>() ?? const {};
    final fiscalite =
        (fiche['fiscalite'] as Map?)?.cast<String, dynamic>() ?? const {};
    // Champs supplémentaires de la fiche officielle, pour que le parcours
    // reprenne l'intégralité des informations présentes dans les fiches
    // statut+activité (.md) : famille d'activité, nature fiscale probable,
    // organisme de contrôle, niveau de vigilance réel et sources officielles.
    final famille = s(fiche['famille']);
    final natureFiscaleProbable = s(fiche['nature_fiscale_probable']);
    final organismeControle = s(fiche['organisme_controle']);
    final niveauVigilance = s(fiche['niveau_vigilance']);
    final activiteReglementee = fiche['activite_reglementee'] == true;
    final statutUtilisateurLabel = s(fiche['statut_utilisateur']);
    // `sources_officielles` a deux formats selon l'ancienneté du pack :
    // une liste d'URLs brutes (packs historiques) ou une liste d'objets
    // {titre, url, resume} (packs plus récents) — on gère les deux.
    final sourcesOfficielles =
        (fiche['sources_officielles'] as List?)?.map((e) {
          if (e is Map) return e.cast<String, dynamic>();
          return <String, dynamic>{'titre': '', 'url': '$e', 'resume': ''};
        }).toList() ??
        const <Map<String, dynamic>>[];
    // Bloc optionnel propre à certains statuts (ex. `regles_retraite`,
    // `regles_etudiant`). Détecté par préfixe pour rester générique aux
    // packs sans lister chaque statut ici.
    Map<String, dynamic>? reglesSpecifiques;
    for (final entry in fiche.entries) {
      final value = entry.value;
      if (entry.key.startsWith('regles_') && value is Map) {
        reglesSpecifiques = value.cast<String, dynamic>();
        break;
      }
    }
    final statutLower = s(fiche['statut_utilisateur']).toLowerCase();
    final cumulLabel = statutLower.contains('retrait')
        ? 'Cumul emploi-retraite'
        : statutLower.contains('etudiant') || statutLower.contains('étudiant')
        ? 'Points à vérifier avant de démarrer'
        : 'Cumul d’activité';
    // Sous-listes de `reglesSpecifiques` à traiter comme alertes bloquantes
    // (mises en avant par les packs eux-mêmes, ex. mineur / titre de séjour
    // pour le statut Étudiant). À étendre si un futur pack ajoute une clé
    // équivalente.
    final reglesAlerts = <String>[];
    if (reglesSpecifiques != null) {
      for (final key in _reglesAlertKeys) {
        reglesAlerts.addAll(l(reglesSpecifiques[key]));
      }
    }

    final regulationTutorial = <Map<String, dynamic>>[
      {
        'title': 'Vue d’ensemble',
        'description': [
          'Ce parcours explique comment un profil « $statutUtilisateurLabel » '
              'peut démarrer ou ajouter l’activité « $activite ».',
          'Activité ${activiteReglementee ? 'réglementée' : 'libre'}.',
          if (niveauVigilance.isNotEmpty)
            'Niveau de vigilance : $niveauVigilance.',
        ].join(' '),
      },
      {
        'title': 'Activité : $activite',
        'description': [
          s(fiche['type_activite']),
          if (famille.isNotEmpty) 'Famille : $famille.',
          'Code APE indicatif : ${s(fiche['code_ape_indicatif'])}.',
          if (natureFiscaleProbable.isNotEmpty)
            'Nature fiscale probable : $natureFiscaleProbable.',
        ].where((e) => e.isNotEmpty).join(' '),
      },
      if (s(fiche['qualification_regles']).isNotEmpty)
        {
          'title': 'Règles à respecter',
          'description': s(fiche['qualification_regles']),
        },
      if (assurances.isNotEmpty)
        {
          'title': 'Assurances à prévoir',
          'description': assurances.join(' ; '),
        },
      if (organismes.isNotEmpty)
        {
          'title': 'Organismes à consulter',
          'description': organismes.join(' ; '),
        },
      if (organismeControle.isNotEmpty)
        {'title': 'Organisme(s) de contrôle', 'description': organismeControle},
      if (alertes.isNotEmpty)
        {
          'title': 'Alertes spécifiques à l’activité',
          'description': alertes.join(' ; '),
        },
      for (final source in sourcesOfficielles)
        if (s(source['titre']).isNotEmpty || s(source['url']).isNotEmpty)
          {
            'title': s(source['titre']).isNotEmpty
                ? s(source['titre'])
                : 'Source officielle',
            'description': [
              s(source['resume']),
              s(source['url']),
            ].where((e) => e.isNotEmpty).join(' — '),
          },
    ];

    final reglesSpecifiquesResume = reglesSpecifiques != null
        ? s(reglesSpecifiques['resume'])
        : '';
    final situationDescription = reglesSpecifiquesResume.isNotEmpty
        ? reglesSpecifiquesResume
        : (s(parcours['2_situation_personnelle']).isNotEmpty
              ? s(parcours['2_situation_personnelle'])
              : 'Vérifiez le cumul d’activité auprès de ${s(fiche['organisme_cumul'])}.');
    var reglesSpecifiquesChecks = const <String>[];
    if (reglesSpecifiques != null) {
      for (final key in _reglesChecksPriorityKeys) {
        final values = l(reglesSpecifiques[key]);
        if (values.isNotEmpty) {
          reglesSpecifiquesChecks = values;
          break;
        }
      }
    }
    final statusWarnings = <Map<String, dynamic>>[
      {
        'title': '$cumulLabel — $activite',
        'description': situationDescription,
        'checks': reglesSpecifiquesChecks.isNotEmpty
            ? reglesSpecifiquesChecks
            : (documents.isNotEmpty ? documents : alertes),
      },
    ];

    final existingLegal = (result['recommendedLegalStatus'] as Map)
        .cast<String, dynamic>();
    final recommendedLegalStatus = {
      'recommended': s(fiche['statut_recommande']).isNotEmpty
          ? fiche['statut_recommande']
          : existingLegal['recommended'],
      'justification': s(parcours['3_cadre']).isNotEmpty
          ? parcours['3_cadre']
          : existingLegal['justification'],
      'planB': statutAlternatif.isNotEmpty
          ? statutAlternatif.join(' ou ')
          : existingLegal['planB'],
      'disclaimer': s(fiche['legal_review_status']).isNotEmpty
          ? fiche['legal_review_status']
          : existingLegal['disclaimer'],
    };

    final blockingAlerts = <String>{
      ...(result['blockingAlerts'] as List).cast<String>(),
      ...alertes,
      ...reglesAlerts,
    }.toList();

    final demarches = l(parcours['4_demarches']);
    final ficheAides = l(parcours['5_aides']);
    final steps = (result['steps'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    for (final step in steps) {
      switch (step['id']) {
        case 'reglementation':
          {
            step['todos'] = [
              s(fiche['qualification_regles']),
              if (s(fiche['code_ape_indicatif']).isNotEmpty)
                'Code APE indicatif : ${s(fiche['code_ape_indicatif'])}',
              ...assurances,
            ].where((e) => e.toString().isNotEmpty).toList();
            break;
          }
        case 'situation':
          {
            step['todos'] = [
              situationDescription,
              ...reglesAlerts,
              if (s(fiche['organisme_cumul']).isNotEmpty)
                'Contact utile : ${s(fiche['organisme_cumul'])}',
            ].where((e) => e.toString().isNotEmpty).toList();
            break;
          }
        case 'statut_lancement':
          {
            step['todos'] = [
              'Statut conseillé : ${s(fiche['statut_recommande'])}',
              if (statutAlternatif.isNotEmpty)
                'Alternatives : ${statutAlternatif.join(', ')}',
            ].where((e) => e.toString().isNotEmpty).toList();
            break;
          }
        case 'preparation':
          {
            if (documents.isNotEmpty) step['todos'] = documents;
            break;
          }
        case 'declaration':
          {
            step['todos'] = [
              ...(demarches.isNotEmpty
                  ? demarches
                  : (step['todos'] as List).cast<String>()),
              if (s(fiche['organisme_formalite']).isNotEmpty)
                'Guichet : ${s(fiche['organisme_formalite'])}',
            ].where((e) => e.toString().isNotEmpty).toList();
            break;
          }
        case 'protections':
          {
            if (assurances.isNotEmpty) step['todos'] = assurances;
            break;
          }
        case 'gestion':
          {
            final gestionTodos = fiscalite.entries
                .where((e) => s(e.value).isNotEmpty)
                .map((e) => '${_fiscaliteLabel(e.key)} : ${s(e.value)}')
                .toList();
            if (gestionTodos.isNotEmpty) step['todos'] = gestionTodos;
            break;
          }
        case 'aides':
          {
            final todos = [
              ...ficheAides,
              if (organismes.isNotEmpty)
                'Organismes : ${organismes.join(', ')}',
            ];
            if (todos.isNotEmpty) step['todos'] = todos;
            break;
          }
        case 'offres':
          {
            if (modesExercice.isNotEmpty) {
              step['todos'] = modesExercice
                  .map((m) => 'Mode d’exercice possible : $m')
                  .toList();
            }
            break;
          }
      }
    }

    final aides = (result['aides'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final existingAideNames = aides
        .map((a) => '${a['name']}'.toLowerCase())
        .toSet();
    for (final name in ficheAides) {
      final key = name.toLowerCase();
      if (existingAideNames.contains(key)) continue;
      aides.add(
        _aid(
          name,
          'Dispositif identifié pour l’activité « $activite » (fiche officielle).',
          true,
        ),
      );
      existingAideNames.add(key);
    }

    final costs = Map<String, dynamic>.from(result['costs'] as Map);
    if (couts.isNotEmpty) {
      costs['note'] = couts.join(' ');
      // Liste détaillée des coûts propres à l'activité (fiche officielle),
      // affichée telle quelle en complément des estimations génériques.
      costs['ficheCoutsIndicatifs'] = couts;
    }

    final summary = <String, dynamic>{
      ...(result['summary'] as Map).cast<String, dynamic>(),
      if (niveauVigilance.isNotEmpty)
        'vigilanceLevel':
            niveauVigilance[0].toUpperCase() + niveauVigilance.substring(1),
    };

    final ficheWeeks = l(parcours['7_plan_30_jours']);
    const weekLabels = ['Semaine 1', 'Semaine 2', 'Semaine 3', 'Semaine 4'];
    final plan30 = <Map<String, dynamic>>[];
    final insertedWeeks = <String>{};
    for (final task in (result['plan30'] as List)) {
      final week = '${(task as Map)['week']}';
      final idx = weekLabels.indexOf(week);
      if (idx != -1 &&
          idx < ficheWeeks.length &&
          !insertedWeeks.contains(week)) {
        plan30.add(_task(week, stripWeekPrefix(ficheWeeks[idx])));
        insertedWeeks.add(week);
      }
      plan30.add(Map<String, dynamic>.from(task));
    }

    final recommendation = Map<String, dynamic>.from(
      result['recommendation'] as Map,
    );
    if (s(fiche['statut_recommande']).isNotEmpty) {
      recommendation['statut'] = fiche['statut_recommande'];
    }
    if (s(parcours['3_cadre']).isNotEmpty) {
      recommendation['why'] = parcours['3_cadre'];
    }
    if (statutAlternatif.isNotEmpty) {
      recommendation['planB'] = statutAlternatif.join(' ou ');
    }

    return {
      ...result,
      'recommendation': recommendation,
      'blockingAlerts': blockingAlerts,
      'costs': costs,
      'summary': summary,
      'plan30': plan30,
      'aides': aides,
      'regulationTutorial': regulationTutorial,
      'statusWarnings': statusWarnings,
      'recommendedLegalStatus': recommendedLegalStatus,
      'steps': steps,
    };
  }

  // Acronymes usuels rencontrés dans les clés `fiscalite` des fiches, pour un
  // libellé plus lisible que la simple capitalisation mot à mot.
  static const _fiscaliteAcronyms = <String, String>{
    'cfe': 'CFE',
    'tva': 'TVA',
    'ca': 'CA',
    'bic': 'BIC',
    'cnav': 'CNAV',
    'cnavpl': 'CNAVPL',
    'zfrr': 'ZFRR',
    'zup': 'ZUP',
  };

  /// Transforme une clé `fiscalite` (ex. `seuil_micro_service_2026_2028`) en
  /// libellé lisible, sans dépendre du nom exact des clés d'un pack donné.
  String _fiscaliteLabel(String key) {
    return key
        .split('_')
        .where((w) => w.isNotEmpty)
        .map((w) {
          final lower = w.toLowerCase();
          if (_fiscaliteAcronyms.containsKey(lower)) {
            return _fiscaliteAcronyms[lower]!;
          }
          if (RegExp(r'^\d').hasMatch(w)) return w;
          return w[0].toUpperCase() + w.substring(1);
        })
        .join(' ');
  }

  Map<String, dynamic> _buildSummary({
    required String statut,
    required bool hasBlockingAlerts,
  }) {
    return {
      'region': _region,
      'currentStatus': _normalizedSituation,
      'activity': _selectedActivity,
      'vigilanceLevel': hasBlockingAlerts ? 'Moyen' : 'Faible',
      'recommendedPath': 'Création progressive',
      'recommendedLegalStatus': statut,
    };
  }

  List<Map<String, dynamic>> _buildStatusWarnings() {
    switch (_normalizedSituation) {
      case 'Fonctionnaire / agent public':
        return [
          {
            'title': 'Cumul d’activité à vérifier',
            'description':
                'En tant qu’agent public, vous devez vérifier les règles de cumul avant de démarrer une activité indépendante. Certaines activités nécessitent une autorisation préalable.',
            'checks': [
              'Vérifier les règles internes de votre administration',
              'Contacter le service RH',
              'Demander une autorisation si nécessaire',
              'Conserver une trace écrite de l’accord',
            ],
          },
        ];
      case "Demandeur d'emploi":
        return [
          {
            'title': 'Aides et calendrier à anticiper',
            'description':
                'Votre situation peut ouvrir droit à certaines aides, mais le moment de la création est important. Vérifiez les conditions avant de déclarer l’activité.',
            'checks': [
              'Vérifier l’ACRE',
              'Vérifier l’ARCE',
              'Étudier le maintien partiel des allocations',
              'Prévoir un rendez-vous France Travail',
            ],
          },
        ];
      case 'Salarié':
        return [
          {
            'title': 'Contrat de travail à vérifier',
            'description':
                'Avant de lancer votre activité, vérifiez votre contrat de travail et les limites éventuelles d’une activité parallèle.',
            'checks': [
              'Clause d’exclusivité',
              'Clause de non-concurrence',
              'Obligation de loyauté',
              'Compatibilité des horaires',
            ],
          },
        ];
      default:
        return [
          {
            'title': 'Situation personnelle à confirmer',
            'description':
                'Vérifiez les règles de cumul, vos droits éventuels et les démarches propres à votre situation avant de lancer l’activité.',
            'checks': [
              'Identifier les règles de cumul éventuelles',
              'Lister les aides ouvertes selon votre situation',
              'Vérifier le calendrier de création',
            ],
          },
        ];
    }
  }

  List<Map<String, dynamic>> _buildRegulationTutorial({
    required bool isDromRegion,
    required bool hasRegulatedSignal,
  }) {
    final territoryNote = isDromRegion
        ? 'Votre territoire relève d’un DROM. Certaines aides, formalités et délais peuvent être spécifiques.'
        : 'Les démarches locales et les organismes d’accompagnement dépendent de votre région.';

    return [
      {
        'title': 'Activité libre ou réglementée',
        'description': hasRegulatedSignal
            ? 'Votre activité semble relever d’un secteur qui nécessite des vérifications réglementaires avant démarrage.'
            : 'Aucune contrainte réglementaire forte n’a été détectée automatiquement, mais une vérification reste recommandée.',
      },
      {
        'title': 'Autorisations ou qualifications',
        'description':
            'Vérifiez si votre activité impose un diplôme, une expérience, une certification ou une autorisation préalable.',
      },
      {
        'title': 'Assurances à prévoir',
        'description':
            'Certaines activités nécessitent une responsabilité civile professionnelle, voire une assurance spécifique comme la décennale selon le métier.',
      },
      {'title': 'Vigilances territoriales', 'description': territoryNote},
    ];
  }

  List<Map<String, dynamic>> _buildTutorialSteps() {
    return [
      _tutorialStep(
        id: 'reglementation',
        order: 1,
        title: 'Vérifier la réglementation de l’activité',
        objective: 'Confirmer que vous pouvez exercer cette activité.',
        todos: [
          'Vérifier si l’activité est réglementée',
          'Identifier les diplômes ou autorisations nécessaires',
          'Lister les assurances à prévoir',
        ],
      ),
      _tutorialStep(
        id: 'situation',
        order: 2,
        title: 'Vérifier votre situation personnelle',
        objective:
            'Sécuriser les règles de cumul et les aides liées à votre statut.',
        todos: [
          'Relire votre situation actuelle',
          'Contacter RH ou organisme compétent si besoin',
          'Conserver une preuve écrite des validations importantes',
        ],
      ),
      _tutorialStep(
        id: 'statut_lancement',
        order: 3,
        title: 'Choisir le statut de lancement',
        objective: 'Sélectionner le cadre le plus simple pour démarrer.',
        todos: [
          'Comparer micro-entreprise, EI et société',
          'Vérifier charges et plafonds',
          'Confirmer si le projet est un test ou une croissance',
        ],
      ),
      _tutorialStep(
        id: 'preparation',
        order: 4,
        title: 'Préparer les informations nécessaires',
        objective: 'Avoir les éléments prêts avant la déclaration.',
        todos: [
          'Préparer identité et adresse',
          'Confirmer l’activité exacte et la date de début',
          'Vérifier régime fiscal, TVA et justificatifs',
        ],
      ),
      _tutorialStep(
        id: 'declaration',
        order: 5,
        title: 'Déclarer l’activité',
        objective: 'Créer officiellement l’activité.',
        todos: [
          'Utiliser le bon guichet officiel',
          'Renseigner l’activité et les options',
          'Conserver les justificatifs',
        ],
      ),
      _tutorialStep(
        id: 'protections',
        order: 6,
        title: 'Mettre en place les protections utiles',
        objective: 'Réduire les risques dès les premiers clients.',
        todos: [
          'Souscrire l’assurance utile',
          'Préparer devis, facture et CGV',
          'Vérifier les mentions légales si présence en ligne',
        ],
      ),
      _tutorialStep(
        id: 'gestion',
        order: 7,
        title: 'Organiser la gestion',
        objective: 'Suivre l’activité dès le démarrage.',
        todos: [
          'Créer un tableau de suivi',
          'Séparer dépenses perso et pro',
          'Suivre le chiffre d’affaires et les charges',
        ],
      ),
      _tutorialStep(
        id: 'aides',
        order: 8,
        title: 'Trouver les premières aides',
        objective: 'Ne pas passer à côté des dispositifs utiles.',
        todos: [
          'Vérifier les aides nationales',
          'Vérifier les aides régionales',
          'Préparer les justificatifs nécessaires',
        ],
      ),
      _tutorialStep(
        id: 'offres',
        order: 9,
        title: 'Lancer les premières offres',
        objective: 'Passer de la préparation à l’action commerciale.',
        todos: [
          'Définir une offre simple',
          'Vérifier le prix de lancement',
          'Tester auprès des premiers clients',
        ],
      ),
    ];
  }

  Map<String, dynamic> _tutorialStep({
    required String id,
    required int order,
    required String title,
    required String objective,
    required List<String> todos,
  }) {
    return {
      'id': id,
      'order': order,
      'title': title,
      'objective': objective,
      'todos': todos,
      'status': 'todo',
    };
  }

  List<Map<String, dynamic>> _cloneProgressSteps(
    List<Map<String, dynamic>> source,
  ) {
    return source
        .map(
          (step) =>
              Map<String, dynamic>.from(step)
                ..putIfAbsent('status', () => 'todo'),
        )
        .toList();
  }

  double get _tutorialProgressValue {
    if (_progressSteps.isEmpty) return 0;
    final doneCount = _progressSteps
        .where((step) => (step['status'] ?? 'todo') == 'done')
        .length;
    return doneCount / _progressSteps.length;
  }

  Map<String, dynamic> _task(String week, String label) => {
    'week': week,
    'label': label,
    'done': false,
  };

  Map<String, dynamic> _aid(String name, String desc, bool relevant) => {
    'name': name,
    'desc': desc,
    'relevant': relevant,
    'status': 'à checker', // à checker / demandé / obtenu
  };

  Map<String, dynamic> _estimateFormalites(String statut) {
    if (statut.contains('Micro')) return {'min': 0, 'max': 50};
    if (statut.contains('EI')) return {'min': 0, 'max': 80};
    if (statut.contains('SAS') || statut.contains('EURL')) {
      return {'min': 120, 'max': 350};
    }
    return {'min': 0, 'max': 200};
  }

  List<String> _prioritiesGuess() {
    final p = <String>[];
    if (_businessModel == 'Ponctuel') p.add('Simplicité');
    if (_protectionPatrimoine) p.add('Protection');
    if (_depensesPro > 5000) p.add('Optimisation frais');
    if (_ambition.contains('Croissance') || _caVise > 60000) {
      p.add('Croissance');
    }
    if (p.isEmpty) return ['Simplicité', 'Coût', 'Rapidité'];
    return p.take(3).toList();
  }

  // --------------------------
  // Navigation
  // --------------------------
  bool get _starterStepValid => _region.isNotEmpty;
  bool get _step2Valid => _situation.isNotEmpty;
  bool get _step3Valid => _selectedActivity.trim().isNotEmpty;
  bool get _step4Valid =>
      _region.isNotEmpty &&
      _situation.isNotEmpty &&
      _selectedActivity.trim().isNotEmpty;

  Future<void> _next() async {
    if (_step == 1 && !_starterStepValid) return;
    if (_step == 2 && !_step2Valid) return;
    if (_step == 3 && !_step3Valid) return;
    if (_step == 4 && !_step4Valid) return;

    if (_step == 3 && _projectCtrl.text.trim().isEmpty) {
      _projectCtrl.text = _selectedActivity;
    }

    setState(() {
      _showStarterErrors = false;
      _step = (_step + 1).clamp(1, kTotalSteps);
    });
    _scrollToTop();
    await _saveDraft();
  }

  Future<void> _completeJourney() async {
    if (!_step4Valid) return;

    setState(() {
      _journeyStatus = 'completed';
      _step = kTotalSteps;
    });
    await _saveDraft();

    // Historique local : toujours écrasé automatiquement à chaque parcours
    // terminé, sans quota ni action de l'utilisateur — distinct du parcours
    // "véritablement sauvegardé" via le bouton "Sauvegarder". Best-effort :
    // ne doit jamais bloquer ni faire échouer la validation du parcours.
    unawaited(() async {
      try {
        await const JourneyLocalStorageService().saveHistorySnapshot(
          _buildJourneySnapshot(
            projectLabel: _projectCtrl.text.trim(),
            region: _region,
            currentStatus: _normalizedSituation,
            selectedActivity: _selectedActivity,
            recommendation: Map<String, dynamic>.from(_recommendation),
            blockingAlerts: List<String>.from(_blockingAlerts),
            costs: Map<String, dynamic>.from(_costs),
            aides: _aides
                .map((item) => Map<String, dynamic>.from(item))
                .toList(),
            plan30: _plan30
                .map((item) => Map<String, dynamic>.from(item))
                .toList(),
            summary: Map<String, dynamic>.from(_summary),
            regulationTutorial: _regulationTutorial
                .map((item) => Map<String, dynamic>.from(item))
                .toList(),
            statusWarnings: _statusWarnings
                .map((item) => Map<String, dynamic>.from(item))
                .toList(),
            recommendedLegalStatus: Map<String, dynamic>.from(
              _recommendedLegalStatus,
            ),
            steps: _progressSteps
                .map((item) => Map<String, dynamic>.from(item))
                .toList(),
          ),
        );
      } catch (e) {
        debugPrint('[Toolbox] history snapshot save failed: $e');
      }
    }());

    final user = _auth.currentUser;
    if (!_isLocalOnlyMode && user != null && _parcoursId != null) {
      try {
        await _db
            .collection('users')
            .doc(user.uid)
            .collection('parcours')
            .doc(_parcoursId)
            .set({
              'status': 'completed',
              'completedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('[Toolbox] complete journey final sync error: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Le parcours est valide, mais la synchronisation finale a echoue.',
            ),
          ),
        );
        return;
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isLocalOnlyMode
              ? 'Parcours validé en mode local. Il ne sera pas repris sur un autre appareil.'
              : 'Parcours validé et sauvegardé.',
        ),
      ),
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GuidedJourneyPage(
          projectLabel: _projectCtrl.text.trim(),
          region: _region,
          currentStatus: _normalizedSituation,
          selectedActivity: _selectedActivity,
          recommendation: Map<String, dynamic>.from(_recommendation),
          blockingAlerts: List<String>.from(_blockingAlerts),
          costs: Map<String, dynamic>.from(_costs),
          aides: _aides.map((item) => Map<String, dynamic>.from(item)).toList(),
          plan30: _plan30
              .map((item) => Map<String, dynamic>.from(item))
              .toList(),
          summary: Map<String, dynamic>.from(_summary),
          regulationTutorial: _regulationTutorial
              .map((item) => Map<String, dynamic>.from(item))
              .toList(),
          statusWarnings: _statusWarnings
              .map((item) => Map<String, dynamic>.from(item))
              .toList(),
          recommendedLegalStatus: Map<String, dynamic>.from(
            _recommendedLegalStatus,
          ),
          steps: _progressSteps
              .map((item) => Map<String, dynamic>.from(item))
              .toList(),
        ),
      ),
    );
  }

  Future<void> _reopenJourneyForEditing() async {
    setState(() => _journeyStatus = 'draft');
    await _saveDraft(recompute: false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Le parcours est repassé en brouillon pour modification.',
        ),
      ),
    );
  }

  void _resetJourneyValues() {
    _step = 1;
    _journeyStatus = 'draft';
    _isFromCache = false;
    _showStarterErrors = false;
    _projectCtrl.clear();
    _regionCtrl.clear();
    _departementCtrl.clear();
    _communeCtrl.clear();

    _activityType = 'Prestation de services';
    _clientele = 'Particuliers (B2C)';
    _businessModel = 'Ponctuel';
    _situation = '';
    _region = '';
    _departement = '';
    _commune = '';
    _ambition = "Tester l'idée";
    _caVise = 0;
    _depensesPro = 0;
    _besoinTva = 'Je ne sais pas';
    _association = false;
    _protectionPatrimoine = true;
    _selectedActivity = '';

    _recommendation = {};
    _blockingAlerts = [];
    _costs = {};
    _plan30 = [];
    _aides = [];
    _recomputeDerived();
  }

  Future<void> _startNewJourney() async {
    _autosaveDebounce?.cancel();

    final user = _auth.currentUser;
    final canPersist = !_isLocalOnlyMode && user != null;

    setState(() {
      _resetJourneyValues();
      _parcoursId = null;
    });

    if (canPersist) {
      final doc = _db
          .collection('users')
          .doc(user.uid)
          .collection('parcours')
          .doc();
      _parcoursId = doc.id;
      final now = FieldValue.serverTimestamp();
      await doc.set({
        'status': 'draft',
        'step': 1,
        'createdAt': now,
        'updatedAt': now,
        'data': _exportData(),
        'derived': _exportDerived(),
        'version': 1,
      });
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          canPersist
              ? 'Nouveau parcours créé.'
              : 'Nouveau parcours local démarré.',
        ),
      ),
    );
  }

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageScrollController.hasClients) {
        _pageScrollController.jumpTo(0);
      }
    });
  }

  Future<void> _back() async {
    setState(() => _step = (_step - 1).clamp(1, kTotalSteps));
    _scrollToTop();
    await _saveDraft();
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Impossible d\'ouvrir $url')));
    }
  }

  Widget _buildJourneyStatusStrip() {
    final chips = <Widget>[
      _JourneyStatusChip(
        icon: _journeyStatus == 'completed'
            ? Icons.verified_rounded
            : Icons.edit_note_rounded,
        label: _journeyStatus == 'completed' ? 'Valide' : 'Brouillon',
        color: _journeyStatus == 'completed' ? const Color(0xFF0F766E) : kBlue,
      ),
    ];

    if (_saving) {
      chips.add(
        const _JourneyStatusChip(
          icon: Icons.sync_rounded,
          label: 'Sauvegarde',
          color: kOrange,
        ),
      );
    }

    if (_isFromCache) {
      chips.add(
        const _JourneyStatusChip(
          icon: Icons.history_toggle_off_rounded,
          label: 'Source cache',
          color: Color(0xFF7C3AED),
        ),
      );
    }

    if (_isLocalOnlyMode) {
      chips.add(
        const _JourneyStatusChip(
          icon: Icons.cloud_off_outlined,
          label: 'Mode local',
          color: Color(0xFF6B7280),
        ),
      );
    }

    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }

  Widget _buildHeaderStatusPanel() {
    String helperText =
        'Chaque modification recalcule et met a jour le parcours automatiquement.';

    if (_isFromCache) {
      helperText =
          'Resultat propose a partir de criteres similaires. Modifiez vos reponses pour lancer un recalcul sur mesure.';
    } else if (_isLocalOnlyMode) {
      helperText =
          'Le parcours reste utilisable sur cet appareil, sans synchronisation distante pour le moment.';
    } else if (_journeyStatus == 'completed') {
      helperText =
          'Le parcours est valide. Toute modification le repassera automatiquement en brouillon.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        _buildHeroHighlights(),
        const SizedBox(height: 12),
        _buildJourneyStatusStrip(),
        const SizedBox(height: 12),
        Text(
          helperText,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  String get _currentStepTitle {
    switch (_step) {
      case 1:
        return 'Étape 1 · Votre région';
      case 2:
        return 'Étape 2 · Votre statut';
      case 3:
        return 'Étape 3 · Votre activité';
      case 4:
        return 'Étape 4 · Vérification';
      default:
        return 'Parcours personnalisé';
    }
  }

  String get _currentStepDescription {
    if (_journeyStatus == 'completed') {
      return 'Le parcours est valide avec une recommandation, un plan 30 jours et les aides a suivre.';
    }

    switch (_step) {
      case 1:
        return 'Choisissez votre région pour personnaliser les aides, les guichets et les démarches locales.';
      case 2:
        return 'Précisez votre statut actuel pour ajuster les alertes et les aides pertinentes.';
      case 3:
        return 'Choisissez votre activité pour générer une recommandation adaptée à votre projet.';
      case 4:
        return 'Vérifiez vos réponses avant d’ouvrir votre parcours personnalisé.';
      default:
        return 'Décrivez ton projet, ta situation et ton territoire.';
    }
  }

  IconData get _currentStepIcon {
    switch (_step) {
      case 1:
        return Icons.track_changes_rounded;
      case 2:
        return Icons.badge_outlined;
      case 3:
        return Icons.work_outline_rounded;
      case 4:
        return Icons.task_alt_rounded;
      default:
        return Icons.auto_awesome;
    }
  }

  Widget _buildHeroHighlights() {
    final items = <Map<String, String>>[
      {
        'label': 'Etape',
        'value': _journeyStatus == 'completed'
            ? 'Finalise'
            : '$_step/$kTotalSteps',
      },
      {'label': 'Sortie', 'value': 'Statut + aides'},
      {'label': 'Cadence', 'value': _saving ? 'Synchro' : 'Auto-save'},
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items
          .map(
            (item) =>
                _HeroMetricPill(label: item['label']!, value: item['value']!),
          )
          .toList(),
    );
  }

  // --------------------------
  // UI
  // --------------------------
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: kOrange,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: kBg,
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              _buildTopHeader(),
              _buildTopProgressBar(),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? _ErrorState(message: _error!, onRetry: _bootstrap)
                    : SingleChildScrollView(
                        controller: _pageScrollController,
                        padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildStepPageShell(_buildCurrentStepPage()),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: kPageHorizontalPadding,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (_journeyStatus == 'completed') ...[
                                    _InfoBox(
                                      icon: Icons.verified_outlined,
                                      title: 'Parcours validé',
                                      text: _isLocalOnlyMode
                                          ? 'Ce parcours a été validé localement. Toute nouvelle modification remettra le parcours en brouillon.'
                                          : 'Ce parcours a été validé et sauvegardé. Toute nouvelle modification remettra le parcours en brouillon.',
                                    ),
                                    const SizedBox(height: 12),
                                    _buildCompletionActionsCard(),
                                    const SizedBox(height: 12),
                                  ],
                                  const SizedBox(height: 14),
                                  _buildNavButtons(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReviewStep() {
    return _Card(
      title: 'Vérifiez avant validation',
      stepLabel: 'Étape 4/4',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _InfoBox(
            icon: Icons.fact_check_outlined,
            title: 'Dernière vérification',
            text:
                'Confirmez vos 3 réponses avant de générer votre parcours personnalisé.',
          ),
          const SizedBox(height: 12),
          _ResultCallout(
            icon: Icons.place_outlined,
            title: 'Territoire pris en compte',
            text: _region.isNotEmpty ? _region : 'Aucune région renseignée',
            tone: kBlue,
          ),
          const SizedBox(height: 10),
          _ResultCallout(
            icon: Icons.badge_outlined,
            title: 'Statut actuel',
            text: _situation.isNotEmpty ? _situation : 'Aucun statut renseigné',
            tone: kBlue,
          ),
          const SizedBox(height: 10),
          _ResultCallout(
            icon: Icons.work_outline_rounded,
            title: 'Activité',
            text: _selectedActivity.isNotEmpty
                ? _selectedActivity
                : 'Aucune activité renseignée',
            tone: kBlue,
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader() {
    final topInset = MediaQuery.of(context).padding.top;

    return Container(
      color: kOrange,
      padding: EdgeInsets.only(top: topInset),
      child: SizedBox(
        height: 108,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: kPageHorizontalPadding,
          ),
          child: Row(
            children: [
              _HeaderCircleButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => Navigator.of(context).maybePop(),
                outlined: false,
                light: true,
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _currentStepTitle,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currentStepDescription,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFFEDD5),
                      ),
                    ),
                  ],
                ),
              ),
              _HeaderCircleButton(
                icon: Icons.help_outline_rounded,
                onTap: _showJourneyHelp,
                outlined: true,
                light: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStepPage() {
    switch (_step) {
      case 1:
        return _buildStepRegion();
      case 2:
        return _buildStepSituation();
      case 3:
        return _buildStepActivity();
      case 4:
      default:
        return _buildReviewStep();
    }
  }

  Widget _buildStepPageShell(Widget child) {
    final screenHeight = MediaQuery.of(context).size.height;
    final minHeight = (screenHeight - 300).clamp(440.0, 620.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kPageHorizontalPadding),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight - 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [const SizedBox(height: 6), child],
        ),
      ),
    );
  }

  Widget _buildTopProgressBar() {
    final completedChoices = [
      _region.isNotEmpty,
      _situation.isNotEmpty,
      _selectedActivity.trim().isNotEmpty,
    ].where((value) => value).length;
    final progressLabel = _journeyStatus == 'completed' ? 3 : completedChoices;
    final progressText = switch (progressLabel) {
      0 => '0 / 3 renseigne — Commencez par votre région',
      1 => '1 / 3 renseigne — Continuez avec votre statut',
      2 => '2 / 3 renseignés — Il reste votre activité',
      _ => '3 / 3 renseignés — Votre parcours est prêt',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        kPageHorizontalPadding,
        8,
        kPageHorizontalPadding,
        28,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              children: [
                const TextSpan(
                  text: 'Progression ',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: kBlue,
                  ),
                ),
                TextSpan(
                  text: '$progressLabel',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: kBlue,
                  ),
                ),
                const TextSpan(
                  text: ' / 3',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF5F6C85),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildProgressCircle(
                number: 1,
                active: progressLabel == 1,
                done: progressLabel > 1,
              ),
              _buildProgressLine(active: progressLabel > 1),
              _buildProgressCircle(
                number: 2,
                active: progressLabel == 2,
                done: progressLabel > 2,
              ),
              _buildProgressLine(active: progressLabel > 2),
              _buildProgressCircle(
                number: 3,
                active: progressLabel == 3,
                done: progressLabel == 3,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            progressText,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCircle({
    required int number,
    required bool active,
    required bool done,
  }) {
    return Container(
      width: active ? 34 : 30,
      height: active ? 34 : 30,
      decoration: BoxDecoration(
        color: active || done ? kOrange : const Color(0xFFB7BECC),
        shape: BoxShape.circle,
        boxShadow: active
            ? [
                BoxShadow(
                  color: kOrange.withValues(alpha: 0.28),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        '$number',
        style: TextStyle(
          color: Colors.white,
          fontSize: active ? 15 : 14,
          fontWeight: active ? FontWeight.w800 : FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildProgressLine({required bool active}) {
    return Expanded(
      child: Container(
        height: 4,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: active ? kOrange : const Color(0xFFD8DDE7),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }

  Widget _buildStarterCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        kPageHorizontalPadding,
        0,
        kPageHorizontalPadding,
        24,
      ),
      constraints: const BoxConstraints(minHeight: 520),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFFF7A1A), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6600).withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF8A33), Color(0xFFFF6600)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(
                  Icons.track_changes_rounded,
                  color: Colors.white,
                  size: 42,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Commencer votre parcours',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: kTextDark,
                          height: 1.1,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Sélectionnez votre région, votre statut actuel et votre activité pour obtenir un guide adapté.',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: kMutedText,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          _buildStarterSelector(
            icon: Icons.location_on_outlined,
            iconColor: kOrange,
            iconBackground: const Color(0xFFFFF1E8),
            label: 'Votre région',
            value: _region.isNotEmpty ? _region : 'Choisir une région',
            helper: _region.isNotEmpty
                ? RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: 'Récupérée depuis votre profil • ',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF7A8498),
                          ),
                        ),
                        TextSpan(
                          text: 'Modifiable',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: kBlue,
                          ),
                        ),
                      ],
                    ),
                  )
                : const Text(
                    'Récupérée depuis votre profil • Modifiable',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF7A8498),
                    ),
                  ),
            onTap: () {
              final regions =
                  kFrenchCitiesData.map((c) => c.region).toSet().toList()
                    ..sort();
              _showRegionPicker(regions);
            },
            isError: _showStarterErrors && _region.isEmpty,
          ),
          const SizedBox(height: 24),
          _buildStarterSelector(
            icon: Icons.badge_outlined,
            iconColor: kBlue,
            iconBackground: const Color(0xFFEAF3FF),
            label: 'Votre statut actuel',
            value: _situation.isNotEmpty ? _situation : 'Choisir un statut',
            helper: const Text(
              'Votre situation actuelle ajuste les alertes et aides utiles',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF7A8498),
              ),
            ),
            onTap: _showStatusPicker,
            isError: _showStarterErrors && _situation.isEmpty,
            minHeight: 108,
          ),
          const SizedBox(height: 24),
          _buildStarterSelector(
            icon: Icons.work_outline_rounded,
            iconColor: const Color(0xFF26A65B),
            iconBackground: const Color(0xFFEAF8EF),
            label: 'Votre activité',
            value: _selectedActivity.isNotEmpty
                ? _selectedActivity
                : 'Choisir une activité',
            helper: const Text(
              'Votre activité principale sert à générer le parcours de création',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF7A8498),
              ),
            ),
            onTap: _showActivityPicker,
            isError: _showStarterErrors && _selectedActivity.trim().isEmpty,
            minHeight: 108,
          ),
        ],
      ),
    );
  }

  Widget _buildStarterSelector({
    required IconData icon,
    required Color iconColor,
    required Color iconBackground,
    required String label,
    required String value,
    required Widget helper,
    required VoidCallback onTap,
    required bool isError,
    double minHeight = 118,
  }) {
    final borderColor = isError ? const Color(0xFFFF3B30) : kBorder;
    final backgroundColor = isError ? const Color(0xFFFFF5F5) : Colors.white;
    final hasValue = !value.toLowerCase().startsWith('choisir');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          constraints: BoxConstraints(minHeight: minHeight),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: iconBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '$label ',
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: kTextDark,
                            ),
                          ),
                          const TextSpan(
                            text: '*',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: kOrange,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 58,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFDCE1EA)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              value,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: hasValue
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: hasValue
                                    ? kTextDark
                                    : const Color(0xFF7A8498),
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Color(0xFF1E293B),
                            size: 28,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    helper,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showJourneyHelp() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Je me lance'),
          content: const Text(
            'Commencez par votre région, votre statut actuel et votre activité. Ces choix servent à personnaliser les étapes suivantes du parcours sans supprimer les critères déjà présents.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  void _showStatusPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choisir un statut actuel',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: kTextDark,
                  ),
                ),
                const SizedBox(height: 14),
                ..._starterStatuses.map(
                  (status) => Material(
                    color: Colors.transparent,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(status),
                      trailing: _situation == status
                          ? const Icon(Icons.check_circle, color: kBlue)
                          : null,
                      onTap: () {
                        setState(() {
                          _situation = status;
                          _showStarterErrors = false;
                        });
                        Navigator.of(sheetContext).pop();
                        _onAnyFieldChanged();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showActivityPicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final activities = _availableActivities;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choisir une activité',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: kTextDark,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Sélectionnez uniquement une activité dans la liste. La saisie clavier est désactivée.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: activities.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final activity = activities[index];
                      return Material(
                        color: Colors.transparent,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(activity),
                          trailing: _selectedActivity == activity
                              ? const Icon(Icons.check_circle, color: kBlue)
                              : null,
                          onTap: () {
                            setState(() {
                              _selectedActivity = activity;
                              _activityType = _resolveActivityTypeFromSelection(
                                activity,
                              );
                              _showStarterErrors = false;
                            });
                            Navigator.of(sheetContext).pop();
                            _onAnyFieldChanged();
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStepProject() {
    final suggestions = <String>[
      "Créer une entreprise de vente de gâteaux",
      "Service de jardinage / paysagiste",
      "Ouvrir une pâtisserie",
      "Organisation d'événements / DJ / sono",
      "Ouvrir un food truck / snack",
      "Ouvrir un salon de coiffure / barber",
      "Réparation smartphones / petits appareils",
      "Se lancer en micro-entrepreneur",
    ];

    return _Card(
      title: "Que souhaitez-vous faire ?",
      stepLabel: "Étape 3/4",
      accent: kBlue,
      icon: Icons.explore_outlined,
      subtitle:
          'Définissez précisément votre projet et son cadre pour affiner la recommandation.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("Décrivez votre projet en une phrase."),
          const SizedBox(height: 10),
          TextField(
            controller: _projectCtrl,
            decoration: InputDecoration(
              hintText: "Ex : Créer une entreprise de vente de gâteaux",
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          const Text("Suggestions basées sur votre saisie"),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions
                .map(
                  (s) => ActionChip(
                    label: Text(s),
                    onPressed: () {
                      _projectCtrl.text = s;
                      _onAnyFieldChanged();
                    },
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          const _SectionTitle("Affiner (optionnel)"),
          const SizedBox(height: 8),
          _DropdownField(
            label: "Type d'activité",
            value: _activityType,
            items: const [
              "Vente de biens",
              "Prestation de services",
              "Libérale",
              "Artisanat",
              "Agricole",
              "Tech/innovation",
              "Culture",
              "BTP",
              "Transport",
              "Autre",
            ],
            onChanged: (v) {
              setState(() => _activityType = v);
              _onAnyFieldChanged();
            },
          ),
          const SizedBox(height: 10),
          _DropdownField(
            label: "Clientèle",
            value: _clientele,
            items: const [
              "Particuliers (B2C)",
              "Entreprises (B2B)",
              "Mixte",
              "Marché public",
            ],
            onChanged: (v) {
              setState(() => _clientele = v);
              _onAnyFieldChanged();
            },
          ),
          const SizedBox(height: 10),
          _DropdownField(
            label: "Modèle",
            value: _businessModel,
            items: const [
              "Ponctuel",
              "Récurrent/abonnement",
              "Marketplace/plateforme",
              "Boutique",
              "Freelance",
              "Franchise",
              "Autre",
            ],
            onChanged: (v) {
              setState(() => _businessModel = v);
              _onAnyFieldChanged();
            },
          ),
          const SizedBox(height: 14),
          const _SectionTitle("Ambition (optionnel)"),
          const SizedBox(height: 8),
          _DropdownField(
            label: "Objectif 6–12 mois",
            value: _ambition,
            items: const [
              "Tester l'idée",
              "Complément de revenu",
              "Revenu principal",
              "Croissance/embauches",
              "Lever des fonds",
            ],
            onChanged: (v) {
              setState(() => _ambition = v);
              _onAnyFieldChanged();
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _NumberField(
                  label: "CA visé (annuel) €",
                  value: _caVise,
                  onChanged: (v) {
                    setState(() => _caVise = v);
                    _onAnyFieldChanged();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _NumberField(
                  label: "Dépenses pro/an €",
                  value: _depensesPro,
                  onChanged: (v) {
                    setState(() => _depensesPro = v);
                    _onAnyFieldChanged();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _DropdownField(
            label: "Besoin de TVA ?",
            value: _besoinTva,
            items: const ["Oui", "Non", "Je ne sais pas"],
            onChanged: (v) {
              setState(() => _besoinTva = v);
              _onAnyFieldChanged();
            },
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            value: _association,
            title: const Text("Besoin de s'associer ?"),
            onChanged: (v) {
              setState(() => _association = v);
              _onAnyFieldChanged();
            },
          ),
          SwitchListTile(
            value: _protectionPatrimoine,
            title: const Text("Protection du patrimoine perso importante ?"),
            onChanged: (v) {
              setState(() => _protectionPatrimoine = v);
              _onAnyFieldChanged();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStepSituation() {
    final items = _starterStatuses;

    return _Card(
      title: "Votre statut actuel",
      stepLabel: "Étape 2/4",
      accent: const Color(0xFF7C3AED),
      icon: Icons.badge_outlined,
      subtitle:
          'Validez votre contexte actuel pour ajuster les alertes et les aides pertinentes.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _InfoBox(
            icon: Icons.badge_outlined,
            title: 'Pourquoi cette étape ?',
            text:
                'Votre statut sert à afficher les règles de cumul, les aides mobilisables et les démarches prioritaires.',
          ),
          const SizedBox(height: 14),
          ...items.map(
            (s) => _SelectRow(
              icon: Icons.work_outline,
              title: s,
              selected: _situation == s,
              onTap: () {
                setState(() => _situation = s);
                _onAnyFieldChanged();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullWidthActivitySelector() {
    final isError = !_step3Valid;
    final borderColor = isError ? const Color(0xFFFF3B30) : kBorder;
    final backgroundColor = isError ? const Color(0xFFFFF5F5) : Colors.white;
    final hasValue = _selectedActivity.isNotEmpty;
    final value = hasValue ? _selectedActivity : 'Choisir une activité';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showActivityPicker,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 108),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEAF8EF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.work_outline_rounded,
                      color: Color(0xFF26A65B),
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'Activité ',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: kTextDark,
                                ),
                              ),
                              TextSpan(
                                text: '*',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: kOrange,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Sélectionnez votre activité principale dans la liste.',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF6B7280),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Champ du menu déroulant élargi sur toute la largeur de la tuile.
              Container(
                width: double.infinity,
                height: 58,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFDCE1EA)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: hasValue
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: hasValue ? kTextDark : const Color(0xFF7A8498),
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF1E293B),
                      size: 28,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepActivity() {
    final suggestions = <String>[
      'Vente de gâteaux',
      'Service de jardinage',
      'Pâtisserie',
      'DJ / sonorisation',
      'Food truck / snack',
      'Coiffure / barber',
      'Réparation smartphones',
      'Micro-entreprise de service',
    ];

    return _Card(
      title: 'Votre activité',
      stepLabel: 'Étape 3/4',
      accent: const Color(0xFF26A65B),
      icon: Icons.work_outline_rounded,
      subtitle:
          'Choisissez votre activité principale. Vous pouvez ajouter un détail projet si besoin.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _InfoBox(
            icon: Icons.work_outline_rounded,
            title: 'Pourquoi cette étape ?',
            text:
                'Votre activité influence la réglementation, les assurances recommandées et les interlocuteurs à contacter ensuite.',
          ),
          const SizedBox(height: 14),
          _buildFullWidthActivitySelector(),
          const SizedBox(height: 14),
          const Text('Suggestions rapides'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: suggestions
                .map(
                  (activity) => ActionChip(
                    label: Text(
                      activity,
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 0,
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      setState(() {
                        _selectedActivity = activity;
                        _activityType = _resolveActivityTypeFromSelection(
                          activity,
                        );
                        if (_projectCtrl.text.trim().isEmpty) {
                          _projectCtrl.text = activity;
                        }
                      });
                      _onAnyFieldChanged();
                    },
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          const _SectionTitle('Précision du projet - optionnel'),
          const SizedBox(height: 8),
          TextField(
            controller: _projectCtrl,
            decoration: InputDecoration(
              hintText: 'Ex : Vente de gâteaux sur commande à domicile',
              prefixIcon: const Icon(Icons.edit_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepRegion() {
    final regions = kFrenchCitiesData.map((c) => c.region).toSet().toList()
      ..sort();

    return _Card(
      title: "Votre région",
      stepLabel: "Étape 1/4",
      accent: kOrange,
      icon: Icons.location_on_outlined,
      subtitle:
          'Confirmez votre territoire pour personnaliser les aides, contacts et priorités locales.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Ta région personnalise les aides, les contacts et ton plan d'action.",
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => _showRegionPicker(regions),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _region.isNotEmpty ? kBlue : Colors.grey.shade400,
                  width: _region.isNotEmpty ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.place_outlined,
                    color: _region.isNotEmpty ? kBlue : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _region.isNotEmpty ? _region : 'Choisir votre région...',
                      style: TextStyle(
                        color: _region.isNotEmpty
                            ? const Color(0xFF111827)
                            : Colors.grey.shade500,
                        fontWeight: _region.isNotEmpty
                            ? FontWeight.w700
                            : FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Icon(Icons.expand_more, color: Colors.grey.shade600),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _departementCtrl,
            decoration: InputDecoration(
              labelText: "Département (ex: 971) – optionnel",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (v) {
              setState(() => _departement = v.trim());
              _onAnyFieldChanged();
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _communeCtrl,
            decoration: InputDecoration(
              labelText: "Commune – optionnel",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (v) {
              setState(() => _commune = v.trim());
              _onAnyFieldChanged();
            },
          ),
          if (_region.isEmpty) ...[
            const SizedBox(height: 12),
            const _InfoBox(
              icon: Icons.info_outline,
              title: "Pourquoi choisir sa région d'abord ?",
              text:
                  "Les aides, les guichets (CCI, CMA, BGE...) et certains dispositifs varient selon votre territoire. En choisissant votre région maintenant, le plan est personnalisé dès le départ.",
            ),
          ],
          if (_region.isNotEmpty && isDROM(_region)) ...[
            const SizedBox(height: 12),
            const _ResultCallout(
              icon: Icons.flight_outlined,
              title: 'Territoire Outre-mer détecté',
              text:
                  'Des aides spécifiques (LODEOM, LADOM, FEDER...) sont disponibles pour les créateurs d\'entreprise dans les DROM.',
              tone: kBlue,
            ),
          ],
        ],
      ),
    );
  }

  void _showRegionPicker(List<String> regions) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RegionPickerSheet(
        regions: regions,
        currentRegion: _region,
        onSelect: (r) {
          setState(() {
            _region = r;
            _showStarterErrors = false;
          });
          Navigator.pop(ctx);
          _onAnyFieldChanged();
        },
      ),
    );
  }

  Widget _buildNavButtons() {
    final canNext =
        (_step == 1 && _starterStepValid) ||
        (_step == 2 && _step2Valid) ||
        (_step == 3 && _step3Valid) ||
        (_step == 4 && _step4Valid);
    final isFinalStep = _step == kTotalSteps;

    return Container(
      padding: const EdgeInsets.fromLTRB(6, 12, 6, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _step == 1
                ? 'Choisissez votre région pour passer à l’étape suivante.'
                : _step == 2
                ? 'Sélectionnez votre statut actuel pour continuer.'
                : _step == 3
                ? 'Choisissez votre activité pour accéder à la vérification finale.'
                : 'Dernière étape avant l’ouverture du parcours personnalisé.',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _step > 1
                      ? _back
                      : () => Navigator.of(context).maybePop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF111827),
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text("Retour"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: canNext
                      ? (isFinalStep ? _completeJourney : _next)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kBlue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: kBlue.withValues(alpha: 0.35),
                    disabledForegroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: Icon(
                    _step < kTotalSteps
                        ? Icons.arrow_forward
                        : Icons.check_circle_outline,
                  ),
                  label: Text(
                    _step < kTotalSteps
                        ? 'Continuer'
                        : 'Voir mon parcours personnalisé',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMyPath() {
    // Always show "Mon parcours", but if nothing typed, show a gentle empty state
    final hasAny =
        _projectCtrl.text.trim().isNotEmpty ||
        _situation.isNotEmpty ||
        _region.isNotEmpty;
    if (!hasAny) {
      return const _Card(
        title: "Mon parcours",
        child: _InfoBox(
          icon: Icons.route_outlined,
          title: "Commence par l'étape 1",
          text:
              "Dès que tu saisis ton projet, on génère automatiquement : statut conseillé, alertes, coûts, aides et plan 30 jours.",
        ),
      );
    }

    final statut = (_recommendation['statut'] ?? '—') as String;
    final why = (_recommendation['why'] ?? '') as String;
    final planB = (_recommendation['planB'] ?? '') as String;
    final prios =
        (_recommendation['priorites'] as List?)?.map((e) => '$e').toList() ??
        [];

    final formalites =
        (_costs['formalitesEstimees'] as Map?)?.cast<String, dynamic>() ?? {};
    final fMin = formalites['min'] ?? 0;
    final fMax = formalites['max'] ?? 0;
    final relevantAidesCount = _aides
        .where((a) => (a['relevant'] ?? true) as bool)
        .length;
    final completedTasksCount = _plan30
        .where((t) => (t['done'] ?? false) as bool)
        .length;
    final hasBlockingAlerts = _blockingAlerts.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Card(
          title: "Mon parcours",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _RecommendationHero(
                statut: statut,
                why: why,
                color: kBlue,
                helper: hasBlockingAlerts
                    ? 'Des points de vigilance sont identifies avant execution.'
                    : 'La recommandation est exploitable immediatement pour cadrer la suite.',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ResultMetricTile(
                      icon: Icons.priority_high_rounded,
                      label: 'Alertes',
                      value: '${_blockingAlerts.length}',
                      tone: hasBlockingAlerts
                          ? const Color(0xFFD97706)
                          : const Color(0xFF0F766E),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ResultMetricTile(
                      icon: Icons.volunteer_activism_outlined,
                      label: 'Aides utiles',
                      value: '$relevantAidesCount',
                      tone: kBlue,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ResultMetricTile(
                      icon: Icons.task_alt_rounded,
                      label: 'Plan avance',
                      value: '$completedTasksCount/${_plan30.length}',
                      tone: const Color(0xFF7C3AED),
                    ),
                  ),
                ],
              ),
              if (planB.isNotEmpty) ...[
                const SizedBox(height: 12),
                _ResultCallout(
                  icon: Icons.swap_horiz,
                  title: 'Plan B si ca grossit',
                  text: planB,
                  tone: const Color(0xFF7C3AED),
                ),
              ],
              if (prios.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Priorites identifiees',
                  style: TextStyle(
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: prios
                      .map((p) => _PriorityChip(label: p, color: kBlue))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
        if (_blockingAlerts.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Card(
            title: "Alertes à vérifier",
            child: Column(
              children: _blockingAlerts
                  .map(
                    (a) => _Bullet(icon: Icons.warning_amber_rounded, text: a),
                  )
                  .toList(),
            ),
          ),
        ],
        const SizedBox(height: 12),
        _Card(
          title: "Coûts estimés",
          child: Column(
            children: [
              _CostRow(
                icon: Icons.receipt_long_outlined,
                label: "Frais de formalités",
                value: "≈ $fMin à $fMax €",
              ),
              _CostRow(
                icon: Icons.campaign_outlined,
                label: "Annonce légale",
                value: "≈ ${_costs['annonceLegale'] ?? 0} €",
              ),
              _CostRow(
                icon: Icons.shield_outlined,
                label: "Assurance pro / an",
                value: "≈ ${_costs['assuranceProAn'] ?? 0} €",
              ),
              _CostRow(
                icon: Icons.calculate_outlined,
                label: "Comptable / an",
                value: "≈ ${_costs['comptableAn'] ?? 0} €",
              ),
              _CostRow(
                icon: Icons.account_balance_wallet_outlined,
                label: "Banque + outils / an",
                value: "≈ ${_costs['banqueOutilsAn'] ?? 0} €",
              ),
              const SizedBox(height: 8),
              _ResultCallout(
                icon: Icons.info_outline,
                title: 'Note de lecture',
                text: "${_costs['note'] ?? ''}",
                tone: const Color(0xFF6B7280),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Card(
          title: "Aides & financements",
          child: Column(
            children: _aides.map((a) {
              final relevant = (a['relevant'] ?? true) as bool;
              if (!relevant) return const SizedBox.shrink();
              return _AidStatusTile(
                name: "${a['name']}",
                description: "${a['desc']}",
                status: (a['status'] ?? 'à checker') as String,
                onChanged: (v) async {
                  if (v == null) return;
                  setState(() => a['status'] = v);
                  await _saveDraft();
                },
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        _Card(
          title: "Plan d'action 30 jours et organismes à contacter",
          child: Column(
            children: _plan30.map((t) {
              return _PlanTaskTile(
                title: "${t['label']}",
                week: "${t['week']}",
                completed: (t['done'] ?? false) as bool,
                contacts: _planContactsForTask(
                  _region,
                  "${t['label']}",
                  activity: _selectedActivity,
                  currentStatus: _normalizedSituation,
                ),
                onOpenContact: (url) => _launchUrl(url),
                onChanged: (v) async {
                  setState(() => t['done'] = v ?? false);
                  await _saveDraft();
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletionActionsCard() {
    return _Card(
      title: 'Actions après validation',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Tu peux rouvrir ce parcours pour le corriger ou repartir d'un nouveau brouillon.",
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _reopenJourneyForEditing,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Modifier'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _startNewJourney,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kBlue,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Nouveau'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRegionGuichets() {
    final resources = getRegionResources(_region);
    if (resources.isEmpty) return const SizedBox.shrink();

    return _Card(
      title: "Contacts & guichets – $_region",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Organismes officiels pour créer votre entreprise en $_region.",
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          ...resources.map(
            (r) => _ResourceLinkTile(
              name: r.name,
              description: r.description,
              url: r.url,
              onTap: () => _launchUrl(r.url),
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------
// Reusable Widgets
// -------------------------------------
class _HeaderCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool outlined;
  final bool light;

  const _HeaderCircleButton({
    required this.icon,
    required this.onTap,
    required this.outlined,
    this.light = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Material(
        color: outlined
            ? (light
                  ? Colors.white.withValues(alpha: 0.14)
                  : const Color(0xFFF5F7FB))
            : Colors.transparent,
        shape: outlined
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
                side: BorderSide(
                  color: light
                      ? Colors.white.withValues(alpha: 0.24)
                      : const Color(0xFFDCE2EE),
                ),
              )
            : const CircleBorder(),
        child: InkWell(
          customBorder: outlined ? null : const CircleBorder(),
          borderRadius: outlined ? BorderRadius.circular(999) : null,
          onTap: onTap,
          child: Icon(
            icon,
            size: 24,
            color: light ? Colors.white : const Color(0xFF071B4D),
          ),
        ),
      ),
    );
  }
}

class _StepperBar extends StatelessWidget {
  final int step;
  const _StepperBar({required this.step});

  @override
  Widget build(BuildContext context) {
    final activeLabel = step == 1
        ? 'Région en cours de sélection'
        : step == 2
        ? 'Projet en cours de cadrage'
        : 'Situation en cours de qualification';

    Widget dot(int n, String label) {
      final active = step == n;
      final done = step > n;
      final color = done
          ? const Color(0xFF1A73E8)
          : active
          ? const Color(0xFF1A73E8)
          : Colors.grey.shade300;

      final txtColor = done || active ? Colors.white : Colors.grey.shade700;

      return Column(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.28),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              "$n",
              style: TextStyle(color: txtColor, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
        ],
      );
    }

    Widget line() => Expanded(
      child: Container(
        height: 3,
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(6, 12, 6, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFF8FAFF)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              dot(1, "Région"),
              line(),
              dot(2, "Projet"),
              line(),
              dot(3, "Situation"),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            activeLabel,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMetricPill extends StatelessWidget {
  final String label;
  final String value;

  const _HeroMetricPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _JourneyStatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _JourneyStatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
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

class _Card extends StatelessWidget {
  final String title;
  final String? stepLabel;
  final String? subtitle;
  final IconData? icon;
  final Color accent;
  final Widget child;

  const _Card({
    required this.title,
    required this.child,
    this.stepLabel,
    this.subtitle,
    this.icon,
    this.accent = const Color(0xFFFF6600),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.14), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: icon != null
                    ? Icon(icon, color: accent, size: 26)
                    : Text(
                        stepLabel?.split('/').first.replaceAll('Étape ', '') ??
                            '•',
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (stepLabel != null)
                      Text(
                        stepLabel!,
                        style: TextStyle(
                          color: accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    if (stepLabel != null) const SizedBox(height: 4),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF071B4D),
                        height: 1.1,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF66728A),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _HeaderInfoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accent;
  final IconData icon;
  final String eyebrow;
  final double progressValue;
  final String progressLabel;

  const _HeaderInfoCard({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.icon,
    required this.eyebrow,
    required this.progressValue,
    required this.progressLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 16, 6, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFBF7), Color(0xFFF5F8FF)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: accent.withValues(alpha: 0.12)),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eyebrow.toUpperCase(),
                      style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: progressValue,
                              minHeight: 8,
                              backgroundColor: const Color(0xFFE5E7EB),
                              valueColor: AlwaysStoppedAnimation<Color>(accent),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${(progressValue * 100).round()}%',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      progressLabel,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SelectRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _SelectRow({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF1F6FF) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? const Color(0xFF1A73E8) : const Color(0xFFE2E6EF),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFFEAF2FF)
                    : const Color(0xFFF5F7FB),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: selected
                    ? const Color(0xFF1A73E8)
                    : const Color(0xFF5F6C85),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 16,
                  color: const Color(0xFF071B4D),
                ),
              ),
            ),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.chevron_right,
              color: selected ? const Color(0xFF1A73E8) : Colors.grey.shade600,
            ),
          ],
        ),
      ),
    );
  }
}

class _StarterRecapChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _StarterRecapChip({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color(0xFF071B4D),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _InfoBox({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 12, 6, 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ), // Plus épais
                const SizedBox(height: 4),
                Text(
                  text,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
    ); // Plus épais
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        filled: true,
        fillColor: Colors.white,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (v) => onChanged(v ?? value),
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  const _NumberField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ctrl = TextEditingController(
      text: value == 0 ? '' : value.toStringAsFixed(0),
    );
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        filled: true,
        fillColor: Colors.white,
      ),
      onChanged: (v) {
        final cleaned = v.replaceAll(',', '.').trim();
        final parsed = double.tryParse(cleaned) ?? 0;
        onChanged(parsed);
      },
    );
  }
}

class _RecommendationHero extends StatelessWidget {
  final String statut;
  final String why;
  final Color color;
  final String helper;

  const _RecommendationHero({
    required this.statut,
    required this.why,
    required this.color,
    required this.helper,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.10), const Color(0xFFFFF7ED)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.workspace_premium_outlined,
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Statut conseille',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statut,
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (why.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              why,
              style: TextStyle(
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            helper,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultMetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color tone;

  const _ResultMetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 12, 6, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: tone),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCallout extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final Color tone;

  const _ResultCallout({
    required this.icon,
    required this.title,
    required this.text,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 12, 6, 12),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.withValues(alpha: 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tone, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  final String label;
  final Color color;

  const _PriorityChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Bullet({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.orange.shade700),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

/// Tuile d'information « lisible » du parcours personnalisé.
///
/// Améliore la mise en page des cartes denses (ex. « Comprendre les règles de
/// votre activité ») : au lieu d'un unique paragraphe « Titre : description »
/// très condensé, elle sépare le titre (en-tête) du corps, et met en forme
/// automatiquement le corps :
/// - une énumération séparée par « ; » devient une liste à puces lisible ;
/// - un lien (http) est isolé sur sa propre ligne, en couleur d'accent ;
/// - sinon le texte reste un paragraphe aéré (interligne confortable).
class _JourneyInfoTile extends StatelessWidget {
  final int index;
  final String title;
  final String body;

  const _JourneyInfoTile({
    required this.index,
    required this.title,
    required this.body,
  });

  /// Découpe le corps en segments lisibles. Les fiches assemblent souvent des
  /// listes avec « ; » (assurances, organismes, alertes...) : on les éclate en
  /// puces. Un paragraphe sans « ; » reste un seul segment.
  List<String> get _segments {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return const [];
    if (trimmed.contains(' ; ')) {
      return trimmed
          .split(' ; ')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return [trimmed];
  }

  @override
  Widget build(BuildContext context) {
    final segments = _segments;
    final isList = segments.length > 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EBF1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1E8),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$index',
                  style: const TextStyle(
                    color: _ToolboxJeMeLancePageState.kOrange,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _ToolboxJeMeLancePageState.kTextDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
          if (segments.isNotEmpty) ...[
            const SizedBox(height: 10),
            if (isList)
              ...segments.map((s) => _JourneyInfoBullet(text: s))
            else
              Text(
                segments.first,
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Puce d'un segment mis en forme par [_JourneyInfoTile]. Isole les liens sur
/// leur propre ligne, en couleur d'accent, pour ne pas casser la lecture.
class _JourneyInfoBullet extends StatelessWidget {
  final String text;
  const _JourneyInfoBullet({required this.text});

  @override
  Widget build(BuildContext context) {
    final isUrl = text.startsWith('http://') || text.startsWith('https://');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6.5, right: 9),
            child: Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: _ToolboxJeMeLancePageState.kOrange,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isUrl
                    ? _ToolboxJeMeLancePageState.kBlue
                    : Colors.grey.shade800,
                fontSize: 13.5,
                height: 1.45,
                decoration: isUrl ? TextDecoration.underline : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CostRow extends StatefulWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? explanation;
  const _CostRow({
    required this.icon,
    required this.label,
    required this.value,
    this.explanation,
  });

  @override
  State<_CostRow> createState() => _CostRowState();
}

class _CostRowState extends State<_CostRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final hasExplanation =
        widget.explanation != null && widget.explanation!.trim().isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: hasExplanation
              ? () => setState(() => _expanded = !_expanded)
              : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 12, 6, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        widget.icon,
                        size: 18,
                        color: const Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.label,
                        style: const TextStyle(
                          color: Color(0xFF111827),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.value,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    if (hasExplanation) ...[
                      const SizedBox(width: 4),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: _expanded
                              ? const Color(0xFFFF6600).withValues(alpha: 0.12)
                              : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _expanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 20,
                          color: _expanded
                              ? const Color(0xFFFF6600)
                              : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ],
                ),
                if (hasExplanation && _expanded) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(left: 48),
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 1),
                          child: Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.explanation!,
                            style: const TextStyle(
                              color: Color(0xFF4B5563),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AidStatusTile extends StatelessWidget {
  final String name;
  final String description;
  final String status;
  final ValueChanged<String?> onChanged;

  const _AidStatusTile({
    required this.name,
    required this.description,
    required this.status,
    required this.onChanged,
  });

  Color get _statusColor {
    switch (status) {
      case 'obtenu':
        return const Color(0xFF0F766E);
      case 'demandé':
        return const Color(0xFF1D4ED8);
      default:
        return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(6, 12, 6, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.volunteer_activism_outlined,
                  color: _statusColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: _statusColor.withValues(alpha: 0.16),
                  ),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: _statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'à checker',
                      child: Text('à checker'),
                    ),
                    DropdownMenuItem(value: 'demandé', child: Text('demandé')),
                    DropdownMenuItem(value: 'obtenu', child: Text('obtenu')),
                  ],
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanTaskTile extends StatelessWidget {
  final String title;
  final String week;
  final bool completed;
  final List<RegionResource> contacts;
  final ValueChanged<String> onOpenContact;
  final ValueChanged<bool?> onChanged;

  const _PlanTaskTile({
    required this.title,
    required this.week,
    required this.completed,
    this.contacts = const [],
    required this.onOpenContact,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
      decoration: BoxDecoration(
        color: completed ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: completed ? const Color(0xFFBBF7D0) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: completed,
            onChanged: onChanged,
            activeColor: const Color(0xFF0F766E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      week,
                      style: const TextStyle(
                        color: Color(0xFF374151),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: TextStyle(
                      color: const Color(0xFF111827),
                      fontWeight: FontWeight.w700,
                      decoration: completed ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (contacts.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Organismes à contacter pour cette étape',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: contacts
                          .map(
                            (contact) => _TaskContactLinkChip(
                              label: contact.name,
                              onTap: () => onOpenContact(contact.url),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (completed)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF0F766E),
                size: 18,
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 44),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => onRetry(),
              child: const Text("Réessayer"),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegionPickerSheet extends StatefulWidget {
  final List<String> regions;
  final String currentRegion;
  final ValueChanged<String> onSelect;

  const _RegionPickerSheet({
    required this.regions,
    required this.currentRegion,
    required this.onSelect,
  });

  @override
  State<_RegionPickerSheet> createState() => _RegionPickerSheetState();
}

class _RegionPickerSheetState extends State<_RegionPickerSheet> {
  List<String> get _regions => widget.regions;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) {
        return Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Choisir votre région',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Sélectionnez uniquement une région dans la liste. La saisie clavier est désactivée.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7280),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _regions.length,
                  itemBuilder: (_, i) {
                    final r = _regions[i];
                    final selected = r == widget.currentRegion;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      tileColor: selected
                          ? const Color(0xFF1A73E8).withValues(alpha: 0.08)
                          : null,
                      leading: Icon(
                        Icons.place_outlined,
                        color: selected
                            ? const Color(0xFF1A73E8)
                            : Colors.grey.shade600,
                      ),
                      title: Text(
                        r,
                        style: TextStyle(
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: selected
                              ? const Color(0xFF1A73E8)
                              : const Color(0xFF111827),
                        ),
                      ),
                      trailing: selected
                          ? const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF1A73E8),
                            )
                          : null,
                      onTap: () => widget.onSelect(r),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _JourneySummaryPage extends StatelessWidget {
  final String projectLabel;
  final String region;
  final String currentStatus;
  final String selectedActivity;
  final Map<String, dynamic> recommendation;
  final List<String> blockingAlerts;
  final Map<String, dynamic> costs;
  final List<Map<String, dynamic>> aides;
  final List<Map<String, dynamic>> plan30;
  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> regulationTutorial;
  final List<Map<String, dynamic>> statusWarnings;
  final Map<String, dynamic> recommendedLegalStatus;
  final List<Map<String, dynamic>> steps;

  /// Ancre utilisée pour repérer la carte "4. Faire les démarches étape par
  /// étape" dans la liste et détecter le scroll jusqu'à sa moitié (voir
  /// `_GuestSignupGate`).
  final GlobalKey _step4CardKey = GlobalKey();

  _JourneySummaryPage({
    required this.projectLabel,
    required this.region,
    required this.currentStatus,
    required this.selectedActivity,
    required this.recommendation,
    required this.blockingAlerts,
    required this.costs,
    required this.aides,
    required this.plan30,
    required this.summary,
    required this.regulationTutorial,
    required this.statusWarnings,
    required this.recommendedLegalStatus,
    required this.steps,
  });

  /// Un utilisateur "non connecté" est soit totalement déconnecté, soit
  /// seulement authentifié anonymement (session technique créée par
  /// `_bootstrap()` pour l'accès Firestore) — dans les deux cas, il n'a pas
  /// de compte iliPresto réel.
  bool get _isGuestUser {
    final user = FirebaseAuth.instance.currentUser;
    return user == null || user.isAnonymous;
  }

  Map<String, dynamic> _buildLocalSnapshot() => _buildJourneySnapshot(
    projectLabel: projectLabel,
    region: region,
    currentStatus: currentStatus,
    selectedActivity: selectedActivity,
    recommendation: recommendation,
    blockingAlerts: blockingAlerts,
    costs: costs,
    aides: aides,
    plan30: plan30,
    summary: summary,
    regulationTutorial: regulationTutorial,
    statusWarnings: statusWarnings,
    recommendedLegalStatus: recommendedLegalStatus,
    steps: steps,
  );

  static const JourneyLocalStorageService _localStorageService =
      JourneyLocalStorageService();
  static const JourneyPdfExportService _pdfExportService =
      JourneyPdfExportService();
  static final JourneyEntitlementsService _entitlementsService =
      JourneyEntitlementsService();

  /// Sauvegarde le parcours (véritable sauvegarde, distincte de
  /// l'historique auto-écrasé) et, pour les abonnements IliPresto+/ilipro,
  /// génère aussi un export PDF et ouvre le téléchargement/enregistrement.
  /// Les utilisateurs Gratuit ne sauvegardent qu'en local.
  Future<void> _handleSave(BuildContext context) async {
    final saveDecision = await _entitlementsService.evaluateLocalSave();
    if (!saveDecision.allowed) {
      if (!context.mounted) return;
      await _showSaveLimitReachedDialog(context, saveDecision);
      return;
    }

    await _localStorageService.saveSnapshot(_buildLocalSnapshot());
    await _entitlementsService.recordLocalSave();

    if (!saveDecision.entitlements.canExportPdf) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Parcours sauvegardé localement sur cet appareil.'),
        ),
      );
      return;
    }

    final pdfDecision = await _entitlementsService.evaluatePdfExport();
    if (!pdfDecision.allowed) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Parcours sauvegardé localement. Export PDF : limite mensuelle déjà atteinte.',
          ),
        ),
      );
      return;
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sauvegarde locale et génération du PDF…')),
    );

    try {
      final downloaded = await _pdfExportService.downloadJourneyPdf(
        _buildLocalSnapshot(),
      );
      if (!context.mounted) return;

      if (!downloaded) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Téléchargement PDF annulé.')),
        );
        return;
      }

      await _entitlementsService.recordPdfExport();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Parcours sauvegardé et PDF téléchargé.')),
      );
    } catch (e) {
      debugPrint('[Toolbox] pdf export failed: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Parcours sauvegardé localement, mais l’export PDF a échoué.',
          ),
        ),
      );
    }
  }

  Future<void> _showSaveLimitReachedDialog(
    BuildContext context,
    JourneySaveDecision decision,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _UpgradeBottomSheet(
          title: 'Limite de sauvegarde atteinte',
          message:
              'L’abonnement Gratuit permet de sauvegarder ${decision.entitlements.maxLocalSavesPerMonth} parcours par mois en local. '
              'Passez à IliPresto+ pour sauvegarder sans limite.',
          ctaLabel: 'Découvrir IliPresto+',
          source: 'toolbox_local_save_limit',
        );
      },
    );
  }

  Future<void> _openResourceUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final statut = (recommendation['statut'] ?? '—') as String;
    final why = (recommendation['why'] ?? '') as String;
    final prios =
        (recommendation['priorites'] as List?)?.map((e) => '$e').toList() ??
        const <String>[];
    final relevantAides = aides
        .where((item) => (item['relevant'] ?? true) as bool)
        .toList();
    final activityLabel = selectedActivity.isNotEmpty
        ? selectedActivity
        : projectLabel;
    final summaryRegion = '${summary['region'] ?? region}';
    final summaryStatus = '${summary['currentStatus'] ?? currentStatus}';
    final summaryActivity = '${summary['activity'] ?? activityLabel}';
    final vigilanceLevel =
        '${summary['vigilanceLevel'] ?? (blockingAlerts.isNotEmpty ? 'Moyen' : 'Faible')}';
    final recommendedPath =
        '${summary['recommendedPath'] ?? 'Création progressive'}';
    final tutorialProgress = steps.isEmpty
        ? 0.0
        : steps.where((step) => (step['status'] ?? 'todo') == 'done').length /
              steps.length;
    final completedSteps = steps
        .where((step) => (step['status'] ?? 'todo') == 'done')
        .length;
    final headerSubtitle = [
      if (summaryActivity.isNotEmpty) 'Créer une activité de $summaryActivity',
      if (summaryRegion.isNotEmpty) 'en $summaryRegion',
      if (summaryStatus.isNotEmpty) 'avec le statut actuel : $summaryStatus',
    ].join(' ');
    final legalRecommendation =
        (recommendedLegalStatus['recommended'] ?? statut) as String;
    final legalJustification =
        (recommendedLegalStatus['justification'] ?? why) as String;
    final legalPlanB =
        (recommendedLegalStatus['planB'] ?? recommendation['planB'] ?? '')
            as String;
    final legalDisclaimer =
        (recommendedLegalStatus['disclaimer'] ?? '') as String;
    final formalites =
        (costs['formalitesEstimees'] as Map?)?.cast<String, dynamic>() ??
        const {};
    final formalitesMin = formalites['min'] ?? 0;
    final formalitesMax = formalites['max'] ?? 0;

    return _ScreenCaptureGuard(
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: _ToolboxJeMeLancePageState.kOrange,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: const Color(0xFFF6F7FB),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                Container(
                  color: _ToolboxJeMeLancePageState.kOrange,
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top,
                  ),
                  child: SizedBox(
                    height: 64,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          _HeaderCircleButton(
                            icon: Icons.arrow_back_ios_new_rounded,
                            onTap: () => Navigator.of(context).maybePop(),
                            outlined: false,
                            light: true,
                          ),
                          const Expanded(
                            child: Text(
                              'Mon parcours personnalisé',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 44),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _GuestSignupGate(
                    enabled: _isGuestUser,
                    triggerKey: _step4CardKey,
                    listBuilder: (scrollController) => ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(8, 16, 8, 24),
                      children: [
                        _HeaderInfoCard(
                          title: 'Mon parcours personnalisé',
                          subtitle: headerSubtitle.isNotEmpty
                              ? headerSubtitle
                              : 'Votre guide de démarrage est prêt.',
                          accent: _ToolboxJeMeLancePageState.kBlue,
                          icon: Icons.route_outlined,
                          eyebrow: 'Parcours généré',
                          progressValue: tutorialProgress,
                          progressLabel:
                              '$completedSteps étape(s) terminée(s) sur ${steps.length}',
                        ),
                        const SizedBox(height: 12),
                        _Card(
                          title: 'Résumé de ma situation',
                          child: Column(
                            children: [
                              _SummaryFactRow(
                                label: 'Région',
                                value: summaryRegion,
                              ),
                              _SummaryFactRow(
                                label: 'Statut actuel',
                                value: summaryStatus,
                              ),
                              _SummaryFactRow(
                                label: 'Activité',
                                value: summaryActivity,
                              ),
                              _SummaryFactRow(
                                label: 'Niveau de vigilance',
                                value: vigilanceLevel,
                              ),
                              _SummaryFactRow(
                                label: 'Parcours recommandé',
                                value: recommendedPath,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Votre parcours est adapté à votre région, à votre situation actuelle et à votre activité. Suivez les étapes dans l’ordre pour avancer sans oublier les points importants.',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _Card(
                          title: '1. Comprendre les règles de votre activité',
                          child: Column(
                            children: regulationTutorial.isEmpty
                                ? [
                                    const _InfoBox(
                                      icon: Icons.info_outline,
                                      title:
                                          'Tutoriel réglementation à compléter',
                                      text:
                                          'La structure tutorielle est prête, mais le contenu détaillé par activité reste à enrichir.',
                                    ),
                                  ]
                                : [
                                    for (
                                      var i = 0;
                                      i < regulationTutorial.length;
                                      i++
                                    )
                                      _JourneyInfoTile(
                                        index: i + 1,
                                        title:
                                            '${regulationTutorial[i]['title'] ?? ''}',
                                        body:
                                            '${regulationTutorial[i]['description'] ?? ''}',
                                      ),
                                  ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _Card(
                          title: '2. Vérifier votre situation personnelle',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: statusWarnings.isEmpty
                                ? [
                                    const _InfoBox(
                                      icon: Icons.verified_outlined,
                                      title: 'Aucune vigilance spécifique',
                                      text:
                                          'Aucun bloc statut particulier n’a été généré à ce stade.',
                                    ),
                                  ]
                                : statusWarnings
                                      .map(
                                        (item) => _StatusGuidanceCard(
                                          title: '${item['title']}',
                                          description: '${item['description']}',
                                          checks:
                                              (item['checks'] as List?)
                                                  ?.map((e) => '$e')
                                                  .toList() ??
                                              const <String>[],
                                        ),
                                      )
                                      .toList(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _Card(
                          title: '3. Choisir le bon cadre pour démarrer',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _RecommendationHero(
                                statut: legalRecommendation,
                                why: legalJustification,
                                color: _ToolboxJeMeLancePageState.kBlue,
                                helper: blockingAlerts.isNotEmpty
                                    ? 'Des points de vigilance doivent être vérifiés avant de lancer les démarches.'
                                    : 'La recommandation est prête pour passer aux prochaines actions.',
                              ),
                              if (legalDisclaimer.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                _ResultCallout(
                                  icon: Icons.info_outline,
                                  title: 'Important',
                                  text: legalDisclaimer,
                                  tone: const Color(0xFF6B7280),
                                ),
                              ],
                              if (legalPlanB.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                _ResultCallout(
                                  icon: Icons.swap_horiz,
                                  title: 'Si votre activité se développe',
                                  text: legalPlanB,
                                  tone: const Color(0xFF7C3AED),
                                ),
                              ],
                              if (prios.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: prios
                                      .map(
                                        (item) => _PriorityChip(
                                          label: item,
                                          color:
                                              _ToolboxJeMeLancePageState.kBlue,
                                        ),
                                      )
                                      .toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        KeyedSubtree(
                          key: _step4CardKey,
                          child: _Card(
                            title: '4. Faire les démarches étape par étape',
                            child: Column(
                              children: steps.isEmpty
                                  ? [
                                      const _InfoBox(
                                        icon: Icons.route_outlined,
                                        title: 'Étapes à structurer',
                                        text:
                                            'Les étapes tutoriels seront affichées ici dès qu’elles sont générées.',
                                      ),
                                    ]
                                  : steps
                                        .map(
                                          (item) => _TutorialStepSummaryTile(
                                            order:
                                                (item['order'] as num?)
                                                    ?.toInt() ??
                                                0,
                                            title: '${item['title']}',
                                            objective: '${item['objective']}',
                                            status:
                                                '${item['status'] ?? 'todo'}',
                                            todos:
                                                (item['todos'] as List?)
                                                    ?.map((e) => '$e')
                                                    .toList() ??
                                                const <String>[],
                                          ),
                                        )
                                        .toList(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _Card(
                          title: '5. Identifier les aides possibles',
                          child: relevantAides.isEmpty
                              ? const _InfoBox(
                                  icon: Icons.volunteer_activism_outlined,
                                  title: 'Aucune aide identifiée',
                                  text:
                                      'Aucune aide spécifique n’a été remontée pour le moment.',
                                )
                              : Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: relevantAides
                                      .map(
                                        (item) => _AidStatusSummaryTile(
                                          name: '${item['name']}',
                                          description: '${item['desc']}',
                                          status:
                                              '${item['status'] ?? 'à checker'}',
                                        ),
                                      )
                                      .toList(),
                                ),
                        ),
                        const SizedBox(height: 12),
                        _Card(
                          title: '6. Prévoir les coûts de lancement',
                          child: Column(
                            children: [
                              if (blockingAlerts.isNotEmpty)
                                _ResultCallout(
                                  icon: Icons.warning_amber_rounded,
                                  title: 'Alertes à vérifier',
                                  text:
                                      '${blockingAlerts.length} point(s) de vigilance détecté(s) avant lancement.',
                                  tone: const Color(0xFFD97706),
                                ),
                              if (blockingAlerts.isNotEmpty)
                                const SizedBox(height: 10),
                              ...[
                                _CostRow(
                                  icon: Icons.receipt_long_outlined,
                                  label: 'Frais de formalités',
                                  value: '≈ $formalitesMin à $formalitesMax €',
                                  explanation:
                                      "Cette fourchette couvre surtout les frais de création et d'immatriculation. En micro-entreprise, ils restent souvent faibles. Pour une société, des frais administratifs supplémentaires peuvent s'ajouter selon la forme choisie.",
                                ),
                                _CostRow(
                                  icon: Icons.campaign_outlined,
                                  label: 'Annonce légale',
                                  value: '≈ ${costs['annonceLegale'] ?? 0} €',
                                  explanation:
                                      "Ce coût concerne principalement les sociétés comme SASU, SAS, EURL ou SARL. Il est en général nul en micro-entreprise. Le montant affiché correspond à une estimation standard de publication.",
                                ),
                                _CostRow(
                                  icon: Icons.shield_outlined,
                                  label: 'Assurance professionnelle',
                                  value: '≈ ${costs['assuranceProAn'] ?? 0} €',
                                  explanation:
                                      "Montant indicatif annuel pour une RC Pro de base. Le prix varie selon votre métier, votre niveau de risque, vos garanties et votre chiffre d'affaires.",
                                ),
                                _CostRow(
                                  icon: Icons.calculate_outlined,
                                  label: 'Comptable / an',
                                  value: '≈ ${costs['comptableAn'] ?? 0} €',
                                  explanation:
                                      "Ce budget devient surtout utile pour une société ou une EI au réel. En micro-entreprise, il peut être nul si vous gérez seul la comptabilité et les déclarations.",
                                ),
                                _CostRow(
                                  icon: Icons.account_balance_wallet_outlined,
                                  label: 'Banque + outils / an',
                                  value: '≈ ${costs['banqueOutilsAn'] ?? 0} €',
                                  explanation:
                                      "Cette estimation regroupe les frais de compte pro, de facturation et quelques outils de gestion de base. Elle peut monter si vous ajoutez des services de paiement, CRM ou automatisation.",
                                ),
                                _ResultCallout(
                                  icon: Icons.info_outline,
                                  title: 'Note de lecture',
                                  text: '${costs['note'] ?? ''}',
                                  tone: const Color(0xFF6B7280),
                                ),
                                if ((costs['ficheCoutsIndicatifs'] as List?)
                                        ?.isNotEmpty ==
                                    true) ...[
                                  const SizedBox(height: 12),
                                  const _SectionTitle(
                                    'Coûts détaillés propres à votre activité',
                                  ),
                                  const SizedBox(height: 8),
                                  ...(costs['ficheCoutsIndicatifs'] as List)
                                      .map(
                                        (item) =>
                                            _JourneyInfoBullet(text: '$item'),
                                      ),
                                ],
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _Card(
                          title: '7. Votre plan d’action sur 30 jours',
                          child: plan30.isEmpty
                              ? const _InfoBox(
                                  icon: Icons.task_alt_rounded,
                                  title: 'Plan non disponible',
                                  text:
                                      'Le plan d’action sera visible dès qu’une recommandation complète est générée.',
                                )
                              : Column(
                                  children: plan30
                                      .map(
                                        (item) => _PlanTaskSummaryTile(
                                          title: '${item['label']}',
                                          week: '${item['week']}',
                                          completed:
                                              (item['done'] ?? false) as bool,
                                          contacts: _planContactsForTask(
                                            region,
                                            '${item['label']}',
                                            activity: selectedActivity,
                                            currentStatus: currentStatus,
                                          ),
                                          onOpenContact: (url) =>
                                              _openResourceUrl(url),
                                        ),
                                      )
                                      .toList(),
                                ),
                        ),
                        const SizedBox(height: 12),
                        _Card(
                          title: 'Sauvegarde & partage',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Abonnement Gratuit : sauvegarde en local sur cet appareil. Avec IliPresto+ ou ilipro : sauvegarde en local + export PDF sur votre téléphone + partage.',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 14),
                              ElevatedButton.icon(
                                onPressed: () => _handleSave(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      _ToolboxJeMeLancePageState.kBlue,
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.save_outlined),
                                label: const Text('Sauvegarder'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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

class _ScreenCaptureGuard extends StatefulWidget {
  final Widget child;

  const _ScreenCaptureGuard({required this.child});

  @override
  State<_ScreenCaptureGuard> createState() => _ScreenCaptureGuardState();
}

class _ScreenCaptureGuardState extends State<_ScreenCaptureGuard> {
  @override
  void initState() {
    super.initState();
    unawaited(ScreenCaptureProtection.enable());
  }

  @override
  void dispose() {
    unawaited(ScreenCaptureProtection.disable());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Affiche `listBuilder` (la liste des cartes du parcours) et, pour un
/// visiteur non connecté (`enabled`), surveille le scroll pour repérer le
/// moment où il atteint la moitié de la carte marquée par `triggerKey`
/// (carte "4. Faire les démarches étape par étape"). À ce moment, une
/// bannière de connexion/inscription apparaît en bas de l'écran.
class _GuestSignupGate extends StatefulWidget {
  final Widget Function(ScrollController controller) listBuilder;
  final GlobalKey triggerKey;
  final bool enabled;

  const _GuestSignupGate({
    required this.listBuilder,
    required this.triggerKey,
    required this.enabled,
  });

  @override
  State<_GuestSignupGate> createState() => _GuestSignupGateState();
}

class _GuestSignupGateState extends State<_GuestSignupGate> {
  final ScrollController _scrollController = ScrollController();
  bool _bannerVisible = false;
  bool _bannerDismissed = false;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      _scrollController.addListener(_handleScroll);
    }
  }

  void _handleScroll() {
    if (_bannerVisible || _bannerDismissed) return;

    final viewportBox = context.findRenderObject() as RenderBox?;
    final targetBox =
        widget.triggerKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewportBox == null ||
        !viewportBox.attached ||
        targetBox == null ||
        !targetBox.attached) {
      return;
    }

    final targetMidY =
        targetBox.localToGlobal(Offset.zero, ancestor: viewportBox).dy +
        targetBox.size.height / 2;

    if (targetMidY <= viewportBox.size.height * 0.5) {
      setState(() => _bannerVisible = true);
    }
  }

  void _dismissBanner() {
    setState(() {
      _bannerVisible = false;
      _bannerDismissed = true;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(
              sigmaX: _bannerVisible ? 6 : 0,
              sigmaY: _bannerVisible ? 6 : 0,
            ),
            child: widget.listBuilder(_scrollController),
          ),
        ),
        if (_bannerVisible) ...[
          Positioned.fill(
            child: IgnorePointer(
              child: Container(color: Colors.black.withValues(alpha: 0.12)),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _GuestSignupBanner(onDismiss: _dismissBanner),
          ),
        ],
      ],
    );
  }
}

class _GuestSignupBanner extends StatelessWidget {
  final VoidCallback onDismiss;

  const _GuestSignupBanner({required this.onDismiss});

  Future<void> _openAccount(BuildContext context, {required bool signup}) {
    return Navigator.of(context)
        .push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => AccountPage(startInSignup: signup),
          ),
        )
        .then((_) => onDismiss());
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.all(12),
      child: Material(
        elevation: 18,
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Text(
                      'Pour continuer à consulter, crée ton compte gratuit',
                      style: TextStyle(
                        color: Color(0xFF111827),
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: onDismiss,
                    borderRadius: BorderRadius.circular(999),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _openAccount(context, signup: false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _ToolboxJeMeLancePageState.kOrange,
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Se connecter'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _openAccount(context, signup: true),
                      style: FilledButton.styleFrom(
                        backgroundColor: _ToolboxJeMeLancePageState.kOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Créer un compte gratuit'),
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

class _UpgradeBottomSheet extends StatelessWidget {
  final String title;
  final String message;
  final String ctaLabel;
  final String source;

  const _UpgradeBottomSheet({
    required this.title,
    required this.message,
    required this.ctaLabel,
    required this.source,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 42,
            height: 4,
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: const Color(0xFFD1D5DB),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.of(context).pop();
              await startSubscriptionCheckout(
                context,
                'ilipresto+',
                source: source,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _ToolboxJeMeLancePageState.kOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.workspace_premium_outlined),
            label: Text(ctaLabel),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Plus tard'),
          ),
        ],
      ),
    );
  }
}

class ToolboxMyParcoursPage extends StatefulWidget {
  const ToolboxMyParcoursPage({super.key});

  @override
  State<ToolboxMyParcoursPage> createState() => _ToolboxMyParcoursPageState();
}

class _ToolboxMyParcoursPageState extends State<ToolboxMyParcoursPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _loading = true;
  String? _error;
  String _projectLabel = '';
  String _region = '';
  String _currentStatus = '';
  String _selectedActivity = '';
  Map<String, dynamic> _recommendation = const {};
  List<String> _blockingAlerts = const [];
  Map<String, dynamic> _costs = const {};
  List<Map<String, dynamic>> _aides = const [];
  List<Map<String, dynamic>> _plan30 = const [];
  Map<String, dynamic> _summary = const {};
  List<Map<String, dynamic>> _regulationTutorial = const [];
  List<Map<String, dynamic>> _statusWarnings = const [];
  Map<String, dynamic> _recommendedLegalStatus = const {};
  List<Map<String, dynamic>> _steps = const [];

  @override
  void initState() {
    super.initState();
    _loadLatestParcours();
  }

  Future<void> _loadLatestParcours() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
        });
        return;
      }

      final col = _db.collection('users').doc(user.uid).collection('parcours');

      QueryDocumentSnapshot<Map<String, dynamic>>? latestDoc;

      try {
        final ordered = await col
            .orderBy('updatedAt', descending: true)
            .limit(1)
            .get();
        if (ordered.docs.isNotEmpty) {
          latestDoc = ordered.docs.first;
        }
      } catch (_) {
        final fallback = await col.limit(25).get();
        if (fallback.docs.isNotEmpty) {
          latestDoc = fallback.docs.reduce((best, current) {
            final bestTs = best.data()['updatedAt'];
            final currentTs = current.data()['updatedAt'];
            if (bestTs is Timestamp && currentTs is Timestamp) {
              return currentTs.compareTo(bestTs) > 0 ? current : best;
            }
            return best;
          });
        }
      }

      if (latestDoc == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
        });
        return;
      }

      final payload = latestDoc.data();
      final data =
          (payload['data'] as Map?)?.cast<String, dynamic>() ?? const {};
      final derived =
          (payload['derived'] as Map?)?.cast<String, dynamic>() ?? const {};

      if (!mounted) return;
      setState(() {
        _projectLabel = '${data['projectText'] ?? data['project'] ?? ''}';
        final territory =
            (data['territory'] as Map?)?.cast<String, dynamic>() ?? const {};
        _region = '${territory['region'] ?? data['region'] ?? ''}';
        _currentStatus = '${data['situation'] ?? data['currentStatus'] ?? ''}';
        _selectedActivity = '${data['selectedActivity'] ?? ''}';
        _recommendation =
            (derived['recommendation'] as Map?)?.cast<String, dynamic>() ??
            const {};
        _blockingAlerts =
            (derived['blockingAlerts'] as List?)?.map((e) => '$e').toList() ??
            const [];
        _costs =
            (derived['costs'] as Map?)?.cast<String, dynamic>() ?? const {};
        _aides =
            (derived['aides'] as List?)
                ?.map((e) => (e as Map).cast<String, dynamic>())
                .toList() ??
            const [];
        _plan30 =
            (derived['plan30'] as List?)
                ?.map((e) => (e as Map).cast<String, dynamic>())
                .toList() ??
            const [];
        _summary =
            (derived['summary'] as Map?)?.cast<String, dynamic>() ?? const {};
        _regulationTutorial =
            (derived['regulationTutorial'] as List?)
                ?.map((e) => (e as Map).cast<String, dynamic>())
                .toList() ??
            const [];
        _statusWarnings =
            (derived['statusWarnings'] as List?)
                ?.map((e) => (e as Map).cast<String, dynamic>())
                .toList() ??
            const [];
        _recommendedLegalStatus =
            (derived['recommendedLegalStatus'] as Map?)
                ?.cast<String, dynamic>() ??
            const {};
        _steps =
            (derived['steps'] as List?)
                ?.map((e) => (e as Map).cast<String, dynamic>())
                .toList() ??
            const [];
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger le dernier parcours.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: _ToolboxJeMeLancePageState.kOrange,
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text('Mon parcours'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_error!, textAlign: TextAlign.center),
          ),
        ),
      );
    }

    return GuidedJourneyPage(
      projectLabel: _projectLabel,
      region: _region,
      currentStatus: _currentStatus,
      selectedActivity: _selectedActivity,
      recommendation: _recommendation,
      blockingAlerts: _blockingAlerts,
      costs: _costs,
      aides: _aides,
      plan30: _plan30,
      summary: _summary,
      regulationTutorial: _regulationTutorial,
      statusWarnings: _statusWarnings,
      recommendedLegalStatus: _recommendedLegalStatus,
      steps: _steps,
    );
  }
}

class _AidStatusSummaryTile extends StatelessWidget {
  final String name;
  final String description;
  final String status;

  const _AidStatusSummaryTile({
    required this.name,
    required this.description,
    required this.status,
  });

  Color get _statusColor {
    switch (status) {
      case 'obtenu':
        return const Color(0xFF0F766E);
      case 'demandé':
        return const Color(0xFF1D4ED8);
      default:
        return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: TextStyle(
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w500,
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _statusColor.withValues(alpha: 0.16)),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: _statusColor,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryFactRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryFactRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : '—',
              style: const TextStyle(
                color: Color(0xFF111827),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusGuidanceCard extends StatelessWidget {
  final String title;
  final String description;
  final List<String> checks;

  const _StatusGuidanceCard({
    required this.title,
    required this.description,
    required this.checks,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFE4D5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w500,
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
          if (checks.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...checks.map((item) => _JourneyInfoBullet(text: item)),
          ],
        ],
      ),
    );
  }
}

class _TutorialStepSummaryTile extends StatelessWidget {
  final int order;
  final String title;
  final String objective;
  final String status;
  final List<String> todos;

  const _TutorialStepSummaryTile({
    required this.order,
    required this.title,
    required this.objective,
    required this.status,
    required this.todos,
  });

  Color get _tone {
    switch (status) {
      case 'done':
        return const Color(0xFF0F766E);
      case 'doing':
        return const Color(0xFF1D4ED8);
      default:
        return const Color(0xFFD97706);
    }
  }

  String get _statusLabel {
    switch (status) {
      case 'done':
        return 'Terminé';
      case 'doing':
        return 'En cours';
      default:
        return 'À faire';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _tone.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$order',
                  style: TextStyle(color: _tone, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _PriorityChip(label: _statusLabel, color: _tone),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            objective,
            style: TextStyle(
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w500,
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
          if (todos.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...todos.map((todo) => _JourneyInfoBullet(text: todo)),
          ],
        ],
      ),
    );
  }
}

class _PlanTaskSummaryTile extends StatelessWidget {
  final String title;
  final String week;
  final bool completed;
  final List<RegionResource> contacts;
  final ValueChanged<String> onOpenContact;

  const _PlanTaskSummaryTile({
    required this.title,
    required this.week,
    required this.completed,
    this.contacts = const [],
    required this.onOpenContact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: completed ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: completed ? const Color(0xFFBBF7D0) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            completed
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked,
            color: completed
                ? const Color(0xFF0F766E)
                : const Color(0xFF9CA3AF),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    week,
                    style: const TextStyle(
                      color: Color(0xFF374151),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: const Color(0xFF111827),
                    fontWeight: FontWeight.w700,
                    decoration: completed ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (contacts.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Lien direct vers l’organisme concerné',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: contacts
                        .map(
                          (contact) => _TaskContactLinkChip(
                            label: contact.name,
                            onTap: () => onOpenContact(contact.url),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskContactLinkChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TaskContactLinkChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFBFDBFE)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.open_in_new_rounded,
              size: 15,
              color: Color(0xFF1A73E8),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF1A73E8),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResourceLinkTile extends StatelessWidget {
  final String name;
  final String description;
  final String url;
  final VoidCallback onTap;

  const _ResourceLinkTile({
    required this.name,
    required this.description,
    required this.url,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.open_in_new_rounded,
                color: Color(0xFF1A73E8),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Color(0xFF1A73E8),
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 18),
          ],
        ),
      ),
    );
  }
}
