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

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:presto_app/services/toolbox_cache_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_core.dart';
import '../data/city_postal_data.dart';
import '../services/region_resources_service.dart';

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
  static const double kPageHorizontalPadding = 16;

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _cacheService = ToolboxCacheService();

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

  Timer? _autosaveDebounce;

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
      final snap =
          await col.orderBy('updatedAt', descending: true).limit(1).get();
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

      final profileRegion = [
        territory?['region'],
        profile?['region'],
        data['region'],
      ]
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
        final doc =
            _db.collection('users').doc(user.uid).collection('parcours').doc();

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
        _recomputeDerived();
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
      };

  void _importDerived(Map<String, dynamic> derived) {
    _recommendation =
        (derived['recommendation'] as Map?)?.cast<String, dynamic>() ?? {};
    _blockingAlerts =
        (derived['blockingAlerts'] as List?)?.map((e) => '$e').toList() ?? [];
    _costs = (derived['costs'] as Map?)?.cast<String, dynamic>() ?? {};
    _plan30 = (derived['plan30'] as List?)
            ?.map((e) => (e as Map).cast<String, dynamic>())
            .toList() ??
        [];
    _aides = (derived['aides'] as List?)
            ?.map((e) => (e as Map).cast<String, dynamic>())
            .toList() ??
        [];
  }

  // --------------------------
  // Derived computation (RULES + CACHE)
  // --------------------------
  Future<void> _recomputeDerivedWithCache() async {
    // Essayer de récupérer depuis le cache
    final cachedJourney = await _cacheService.fetchExistingJourney(
      typeProjet: _activityType,
      domaine: _projectCtrl.text.trim(),
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
      final r = _computeRecommendationRules();
      _recommendation = r['recommendation'] as Map<String, dynamic>;
      _blockingAlerts = (r['blockingAlerts'] as List).cast<String>();
      _costs = (r['costs'] as Map).cast<String, dynamic>();
      _plan30 = (r['plan30'] as List)
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
      _aides = (r['aides'] as List)
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();

      // Sauvegarder le nouveau parcours généré en cache
      final journeyContent = {
        'recommendation': _recommendation,
        'blockingAlerts': _blockingAlerts,
        'costs': _costs,
        'plan30': _plan30,
        'aides': _aides,
      };

      unawaited(
        _cacheService.saveNewJourney(
          typeProjet: _activityType,
          domaine: _projectCtrl.text.trim(),
          region: _region,
          journeyContent: journeyContent,
        ),
      );
    }
  }

  void _recomputeDerived() {
    _isFromCache = false;
    final r = _computeRecommendationRules();
    _recommendation = r['recommendation'] as Map<String, dynamic>;
    _blockingAlerts = (r['blockingAlerts'] as List).cast<String>();
    _costs = (r['costs'] as Map).cast<String, dynamic>();
    _plan30 = (r['plan30'] as List)
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
    _aides = (r['aides'] as List)
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
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
    final wantsGrowth = _ambition.contains('Croissance') ||
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
          "Activité potentiellement réglementée : vérification (diplômes/assurances/autorisations) recommandée avant création.");
    }
    if (_normalizedSituation == 'Fonctionnaire / agent public') {
      blocking.add(
          "Cumul : demande écrite hiérarchique + règles spécifiques (temps partiel / durée encadrée).");
    }
    if (_normalizedSituation == "Demandeur d'emploi") {
      blocking.add(
          "Aides France Travail : attention au timing (ARCE/ACRE) avant certaines démarches.");
    }

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
      'annonceLegale':
          (statut.contains('SAS') || statut.contains('EURL')) ? 180 : 0,
      'assuranceProAn': 250,
      'comptableAn':
          (statut.contains('SAS') || statut.contains('EURL')) ? 1200 : 0,
      'banqueOutilsAn': 120,
      'note':
          "Estimations indicatives. Les montants varient selon activité et département.",
    };

    // Aides (checklist)
    final aides = <Map<String, dynamic>>[
      _aid("ACRE", "Exonération partielle de cotisations au démarrage", true),
      _aid("ARCE", "Capital France Travail (si ARE + conditions)",
          _normalizedSituation == "Demandeur d'emploi"),
      _aid("Prêt d'honneur", "Initiative France / Réseau Entreprendre", true),
      _aid("Aides territoriales",
          "Région / Département / Agglo (selon territoire)", true),
      _aid("Fonds européens",
          "FEDER / FSE+ / FEADER (via programmes régionaux)", true),
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
          "Semaine 3", "Préparer dossier subvention (résumé + budget + devis)"),
      _task("Semaine 4", "Déposer formalités via guichet unique"),
      _task("Semaine 4", "Assurances + compte bancaire pro si nécessaire"),
      _task("Semaine 4",
          "1ère action commerciale (prospection / pub / partenariats)"),
    ];

    return {
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
    };
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
  bool get _starterStepValid =>
      _region.isNotEmpty &&
      _situation.isNotEmpty &&
      _selectedActivity.trim().isNotEmpty;
  bool get _step2Valid => _projectCtrl.text.trim().length >= 6;
  bool get _step3Valid => _situation.isNotEmpty;
  bool get _step4Valid => true;

  Future<void> _next() async {
    if (_step == 1 && !_starterStepValid) return;
    if (_step == 2 && !_step2Valid) return;
    if (_step == 3 && !_step3Valid) return;
    if (_step == 4 && !_step4Valid) return;

    if (_step == 1 && _projectCtrl.text.trim().isEmpty) {
      _projectCtrl.text = _selectedActivity;
    }

    setState(() {
      _showStarterErrors = false;
      _step = (_step + 1).clamp(1, kTotalSteps);
    });
    await _saveDraft();
  }

  Future<void> _completeJourney() async {
    if (!_step4Valid) return;

    setState(() => _journeyStatus = 'completed');
    await _saveDraft();

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
        builder: (_) => _JourneySummaryPage(
          projectLabel: _projectCtrl.text.trim(),
          region: _region,
          recommendation: Map<String, dynamic>.from(_recommendation),
          blockingAlerts: List<String>.from(_blockingAlerts),
          aides: _aides
              .map((item) => Map<String, dynamic>.from(item))
              .toList(),
          plan30: _plan30
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
        content:
            Text('Le parcours est repassé en brouillon pour modification.'),
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
      final doc =
          _db.collection('users').doc(user.uid).collection('parcours').doc();
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

  Future<void> _back() async {
    setState(() => _step = (_step - 1).clamp(1, kTotalSteps));
    await _saveDraft();
  }

  Future<void> _continueStarterStep() async {
    if (!_starterStepValid) {
      setState(() => _showStarterErrors = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Complétez les 3 informations pour personnaliser votre parcours.',
          ),
        ),
      );
      return;
    }

    await _next();
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d\'ouvrir $url')),
      );
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

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips,
    );
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
        return 'Je me lance';
      case 2:
        return 'Ton projet';
      case 3:
        return 'Ta situation';
      case 4:
        return 'Validation';
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
        return 'Renseignez vos informations de départ pour personnaliser la suite du parcours.';
      case 2:
        return 'Posez les bases du projet pour lancer une premiere recommandation exploitable.';
      case 3:
        return 'On ajuste les alertes et aides selon votre contexte personnel et professionnel.';
      case 4:
        return 'Vérifiez le récapitulatif généré avant de valider votre parcours.';
      default:
        return 'Décrivez ton projet, ta situation et ton territoire.';
    }
  }

  IconData get _currentStepIcon {
    switch (_step) {
      case 1:
        return Icons.track_changes_rounded;
      case 2:
        return Icons.explore_outlined;
      case 3:
        return Icons.badge_outlined;
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
        'value': _journeyStatus == 'completed' ? 'Finalise' : '$_step/$kTotalSteps',
      },
      {
        'label': 'Sortie',
        'value': 'Statut + aides',
      },
      {
        'label': 'Cadence',
        'value': _saving ? 'Synchro' : 'Auto-save',
      },
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items
          .map(
            (item) => _HeroMetricPill(
              label: item['label']!,
              value: item['value']!,
            ),
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
                            padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_step == 1) _buildStarterCard(),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(
                                        horizontal: kPageHorizontalPadding,
                                      ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (_isLocalOnlyMode) ...[
                                        const _InfoBox(
                                          icon: Icons.cloud_off_outlined,
                                          title: 'Mode local non sauvegardé',
                                          text:
                                              "Tes réponses restent utilisables sur cet écran, mais elles ne seront pas reprises automatiquement plus tard tant que la persistance n'est pas disponible.",
                                        ),
                                        const SizedBox(height: 12),
                                      ],
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
                                      if (_step == 2) _buildStepProject(),
                                      if (_step == 3) _buildStepSituation(),
                                      if (_step == 4) _buildReviewStep(),
                                      if (_step > 1) ...[
                                        const SizedBox(height: 14),
                                        _buildNavButtons(),
                                      ],
                                      const SizedBox(height: 18),
                                      _buildMyPath(),
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
          const Text(
            'Votre région a déjà été prise en compte depuis la première carte. Vérifiez maintenant le parcours généré avant validation finale.',
          ),
          const SizedBox(height: 12),
          _ResultCallout(
            icon: Icons.place_outlined,
            title: 'Territoire pris en compte',
            text: _region.isNotEmpty
                ? _region
                : 'Aucune région renseignée',
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
        height: 64,
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
              const Expanded(
                child: Text(
                  'Je me lance',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
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

  Widget _buildTopProgressBar() {
    final stepLabel = _journeyStatus == 'completed' ? kTotalSteps : _step;

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
                  text: 'Étape ',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: kBlue,
                  ),
                ),
                TextSpan(
                  text: '$stepLabel',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: kBlue,
                  ),
                ),
                const TextSpan(
                  text: ' sur 4',
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
              _buildProgressCircle(number: 1, active: stepLabel == 1, done: stepLabel > 1),
              _buildProgressLine(active: stepLabel > 1),
              _buildProgressCircle(number: 2, active: stepLabel == 2, done: stepLabel > 2),
              _buildProgressLine(active: stepLabel > 2),
              _buildProgressCircle(number: 3, active: stepLabel == 3, done: stepLabel > 3),
              _buildProgressLine(active: stepLabel > 3),
              _buildProgressCircle(number: 4, active: stepLabel == 4, done: false),
            ],
          ),
          if (_step > 1) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StarterRecapChip(
                  icon: Icons.location_on_outlined,
                  color: kOrange,
                  label: _region.isNotEmpty ? _region : 'Région',
                ),
                _StarterRecapChip(
                  icon: Icons.person_outline_rounded,
                  color: kBlue,
                  label: _situation.isNotEmpty ? _situation : 'Statut',
                ),
                _StarterRecapChip(
                  icon: Icons.work_outline_rounded,
                  color: const Color(0xFF26A65B),
                  label: _selectedActivity.isNotEmpty
                      ? _selectedActivity
                      : 'Activité',
                ),
              ],
            ),
          ],
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
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 370;

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
                        'Commencez votre parcours',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: kTextDark,
                          height: 1.1,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Renseignez ces 3 informations pour\npersonnaliser votre accompagnement.',
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
            label: 'Région',
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
          const SizedBox(height: 14),
          _buildStarterSelector(
            icon: Icons.person_outline_rounded,
            iconColor: kBlue,
            iconBackground: const Color(0xFFEEF4FF),
            label: 'Statut actuel',
            value: _situation.isNotEmpty ? _situation : 'Choisir un statut',
            helper: const SizedBox.shrink(),
            onTap: _showStatusPicker,
            isError: _showStarterErrors && _situation.isEmpty,
            minHeight: 100,
          ),
          const SizedBox(height: 14),
          _buildStarterSelector(
            icon: Icons.work_outline_rounded,
            iconColor: const Color(0xFF26A65B),
            iconBackground: const Color(0xFFEAF8EF),
            label: 'Activité',
            value: _selectedActivity.isNotEmpty
                ? _selectedActivity
                : 'Choisir une activité',
            helper: Row(
              children: const [
                Icon(
                  Icons.search_rounded,
                  size: 22,
                  color: Color(0xFF6B7280),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Recherchez et sélectionnez votre activité',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
              ],
            ),
            onTap: _showActivityPicker,
            isError: _showStarterErrors && _selectedActivity.trim().isEmpty,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: _starterStepValid
                    ? const LinearGradient(
                        colors: [Color(0xFFFF8A1F), Color(0xFFFF6600)],
                      )
                    : null,
                color: _starterStepValid ? null : const Color(0xFFF0F2F6),
                borderRadius: BorderRadius.circular(18),
              ),
              child: ElevatedButton(
                onPressed: _starterStepValid ? _continueStarterStep : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: _starterStepValid
                      ? Colors.white
                      : const Color(0xFF9AA3B2),
                  disabledBackgroundColor: Colors.transparent,
                  disabledForegroundColor: const Color(0xFF9AA3B2),
                  shadowColor: Colors.transparent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(
                  'Continuer',
                  style: TextStyle(
                    fontSize: isCompact ? 17 : 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
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
                                fontWeight:
                                    hasValue ? FontWeight.w600 : FontWeight.w500,
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
                  (status) => ListTile(
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
        var query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = _availableActivities
                .where(
                  (activity) => activity
                      .toLowerCase()
                      .contains(query.trim().toLowerCase()),
                )
                .toList();

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
                ),
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
                    const SizedBox(height: 14),
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Rechercher une activité',
                        prefixIcon: const Icon(Icons.search_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                      ),
                      onChanged: (value) {
                        setModalState(() {
                          query = value;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, index) {
                          final activity = filtered[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(activity),
                            trailing: _selectedActivity == activity
                                ? const Icon(Icons.check_circle, color: kBlue)
                                : null,
                            onTap: () {
                              setState(() {
                                _selectedActivity = activity;
                                _activityType =
                                    _resolveActivityTypeFromSelection(activity);
                                _showStarterErrors = false;
                              });
                              Navigator.of(sheetContext).pop();
                              _onAnyFieldChanged();
                            },
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
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
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
                .map((s) => ActionChip(
                      label: Text(s),
                      onPressed: () {
                        _projectCtrl.text = s;
                        _onAnyFieldChanged();
                      },
                    ))
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
      title: "Votre situation actuelle",
      stepLabel: "Étape 4/4",
      accent: const Color(0xFF7C3AED),
      icon: Icons.badge_outlined,
      subtitle:
          'Validez votre contexte actuel pour ajuster les alertes et les aides pertinentes.',
      child: Column(
        children: items
            .map((s) => _SelectRow(
                  icon: Icons.work_outline,
                  title: s,
                  selected: _situation == s,
                  onTap: () {
                    setState(() => _situation = s);
                    _onAnyFieldChanged();
                  },
                ))
            .toList(),
      ),
    );
  }

  Widget _buildStepRegion() {
    final regions = kFrenchCitiesData.map((c) => c.region).toSet().toList()
      ..sort();

    return _Card(
      title: "Ta région",
      stepLabel: "Étape 2/4",
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
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
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
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
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
    final canNext = (_step == 1 && _starterStepValid) ||
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
            isFinalStep
                ? 'Derniere etape avant validation du parcours.'
                : _step == 1
                    ? 'Ces 3 informations lancent votre parcours personnalisé.'
                    : 'Continuez pour enrichir la recommandation automatiquement.',
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
                  onPressed: _step > 1 ? _back : null,
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
                  onPressed:
                    canNext
                      ? (isFinalStep
                        ? _completeJourney
                        : (_step == 1 ? _continueStarterStep : _next))
                      : null,
                  style: ElevatedButton.styleFrom(
                  backgroundColor: _step == 1 ? kOrange : kBlue,
                    foregroundColor: Colors.white,
                  disabledBackgroundColor: _step == 1
                    ? const Color(0xFFF0F2F6)
                    : kBlue.withValues(alpha: 0.35),
                  disabledForegroundColor: _step == 1
                    ? const Color(0xFF9AA3B2)
                    : Colors.white,
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
                        ? "Continuer"
                        : (_journeyStatus == 'completed'
                            ? "Revalider"
                            : "Valider"),
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
    final hasAny = _projectCtrl.text.trim().isNotEmpty ||
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
    final relevantAidesCount =
        _aides.where((a) => (a['relevant'] ?? true) as bool).length;
    final completedTasksCount =
        _plan30.where((t) => (t['done'] ?? false) as bool).length;
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
                      .map(
                        (p) => _PriorityChip(
                          label: p,
                          color: kBlue,
                        ),
                      )
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
                  .map((a) =>
                      _Bullet(icon: Icons.warning_amber_rounded, text: a))
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
                  value: "≈ $fMin à $fMax €"),
              _CostRow(
                  icon: Icons.campaign_outlined,
                  label: "Annonce légale",
                  value: "≈ ${_costs['annonceLegale'] ?? 0} €"),
              _CostRow(
                  icon: Icons.shield_outlined,
                  label: "Assurance pro / an",
                  value: "≈ ${_costs['assuranceProAn'] ?? 0} €"),
              _CostRow(
                  icon: Icons.calculate_outlined,
                  label: "Comptable / an",
                  value: "≈ ${_costs['comptableAn'] ?? 0} €"),
              _CostRow(
                  icon: Icons.account_balance_wallet_outlined,
                  label: "Banque + outils / an",
                  value: "≈ ${_costs['banqueOutilsAn'] ?? 0} €"),
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
          title: "Plan d'action 30 jours",
          child: Column(
            children: _plan30.map((t) {
              return _PlanTaskTile(
                title: "${t['label']}",
                week: "${t['week']}",
                completed: (t['done'] ?? false) as bool,
                onChanged: (v) async {
                  setState(() => t['done'] = v ?? false);
                  await _saveDraft();
                },
              );
            }).toList(),
          ),
        ),
        if (_region.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildRegionGuichets(),
        ],
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
                color: Colors.grey.shade700, fontWeight: FontWeight.w600),
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
            ? (light ? Colors.white.withValues(alpha: 0.14) : const Color(0xFFF5F7FB))
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
          customBorder:
              outlined ? null : const CircleBorder(),
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
          Text(label,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
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
          colors: [
            Colors.white,
            Color(0xFFF8FAFF),
          ],
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
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
                        stepLabel?.split('/').first.replaceAll('Étape ', '') ?? '•',
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
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    if (stepLabel != null) const SizedBox(height: 4),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
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
          colors: [
            Color(0xFFFFFBF7),
            Color(0xFFF5F8FF),
          ],
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
          color: selected
              ? const Color(0xFFF1F6FF)
              : Colors.white,
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
                color: selected ? const Color(0xFF1A73E8) : const Color(0xFF5F6C85),
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
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15)), // Plus épais
                const SizedBox(height: 4),
                Text(text,
                    style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600)),
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
    return Text(text,
        style: const TextStyle(
            fontWeight: FontWeight.w800, fontSize: 16)); // Plus épais
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
          colors: [
            color.withValues(alpha: 0.10),
            const Color(0xFFFFF7ED),
          ],
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
                child: Icon(Icons.workspace_premium_outlined,
                    color: color, size: 22),
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

class _CostRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _CostRow({
    required this.icon,
    required this.label,
    required this.value,
  });

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
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: const Color(0xFF374151)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 15)), // Plus épais
        ],
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                  border:
                      Border.all(color: _statusColor.withValues(alpha: 0.16)),
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
                        value: 'à checker', child: Text('à checker')),
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
  final ValueChanged<bool?> onChanged;

  const _PlanTaskTile({
    required this.title,
    required this.week,
    required this.completed,
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
  final _searchCtrl = TextEditingController();
  List<String> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.regions;
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      _filtered = q.isEmpty
          ? widget.regions
          : widget.regions.where((r) => r.toLowerCase().contains(q)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
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
                    const SizedBox(height: 10),
                    TextField(
                      controller: _searchCtrl,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Rechercher une région...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF6F7FB),
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
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) {
                    final r = _filtered[i];
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
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w600,
                          color: selected
                              ? const Color(0xFF1A73E8)
                              : const Color(0xFF111827),
                        ),
                      ),
                      trailing: selected
                          ? const Icon(Icons.check_circle_rounded,
                              color: Color(0xFF1A73E8))
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
  final Map<String, dynamic> recommendation;
  final List<String> blockingAlerts;
  final List<Map<String, dynamic>> aides;
  final List<Map<String, dynamic>> plan30;

  const _JourneySummaryPage({
    required this.projectLabel,
    required this.region,
    required this.recommendation,
    required this.blockingAlerts,
    required this.aides,
    required this.plan30,
  });

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
    final resources = region.isNotEmpty ? getRegionResources(region) : const [];

    return AnnotatedRegion<SystemUiOverlayStyle>(
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
                padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
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
                            'Mon parcours',
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
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    if (projectLabel.isNotEmpty || region.isNotEmpty)
                      _Card(
                        title: 'Synthèse du parcours',
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (projectLabel.isNotEmpty)
                              _PriorityChip(
                                label: projectLabel,
                                color: _ToolboxJeMeLancePageState.kBlue,
                              ),
                            if (region.isNotEmpty)
                              _PriorityChip(
                                label: region,
                                color: _ToolboxJeMeLancePageState.kOrange,
                              ),
                          ],
                        ),
                      ),
                    if (projectLabel.isNotEmpty || region.isNotEmpty)
                      const SizedBox(height: 12),
                    _Card(
                      title: 'Statut conseillé',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _RecommendationHero(
                            statut: statut,
                            why: why,
                            color: _ToolboxJeMeLancePageState.kBlue,
                            helper: blockingAlerts.isNotEmpty
                                ? 'Des points de vigilance doivent être vérifiés avant de lancer les démarches.'
                                : 'La recommandation est prête pour passer aux prochaines actions.',
                          ),
                          if (prios.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: prios
                                  .map(
                                    (item) => _PriorityChip(
                                      label: item,
                                      color: _ToolboxJeMeLancePageState.kBlue,
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _Card(
                      title: 'Alertes à vérifier',
                      child: blockingAlerts.isEmpty
                          ? const _InfoBox(
                              icon: Icons.verified_outlined,
                              title: 'Aucune alerte bloquante',
                              text: 'Aucun point critique n’a été détecté à ce stade.',
                            )
                          : Column(
                              children: blockingAlerts
                                  .map(
                                    (item) => _Bullet(
                                      icon: Icons.warning_amber_rounded,
                                      text: item,
                                    ),
                                  )
                                  .toList(),
                            ),
                    ),
                    const SizedBox(height: 12),
                    _Card(
                      title: 'Aides & financements',
                      child: relevantAides.isEmpty
                          ? const _InfoBox(
                              icon: Icons.volunteer_activism_outlined,
                              title: 'Aucune aide identifiée',
                              text: 'Aucune aide spécifique n’a été remontée pour le moment.',
                            )
                          : Column(
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
                      title: 'Plan d\'action 30 jours',
                      child: plan30.isEmpty
                          ? const _InfoBox(
                              icon: Icons.task_alt_rounded,
                              title: 'Plan non disponible',
                              text: 'Le plan d’action sera visible dès qu’une recommandation complète est générée.',
                            )
                          : Column(
                              children: plan30
                                  .map(
                                    (item) => _PlanTaskSummaryTile(
                                      title: '${item['label']}',
                                      week: '${item['week']}',
                                      completed:
                                          (item['done'] ?? false) as bool,
                                    ),
                                  )
                                  .toList(),
                            ),
                    ),
                    const SizedBox(height: 12),
                    _Card(
                      title: region.isNotEmpty
                          ? 'Contacts & guichets région'
                          : 'Contacts & guichets région',
                      child: resources.isEmpty
                          ? const _InfoBox(
                              icon: Icons.place_outlined,
                              title: 'Aucun contact local identifié',
                              text: 'Renseignez une région reconnue pour afficher les organismes utiles.',
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Organismes officiels pour créer votre entreprise${region.isNotEmpty ? ' en $region' : ''}.',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                ...resources.map(
                                  (resource) => _ResourceLinkTile(
                                    name: resource.name,
                                    description: resource.description,
                                    url: resource.url,
                                    onTap: () => _openResourceUrl(resource.url),
                                  ),
                                ),
                              ],
                            ),
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
  Map<String, dynamic> _recommendation = const {};
  List<String> _blockingAlerts = const [];
  List<Map<String, dynamic>> _aides = const [];
  List<Map<String, dynamic>> _plan30 = const [];

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
      final data = (payload['data'] as Map?)?.cast<String, dynamic>() ?? const {};
      final derived =
          (payload['derived'] as Map?)?.cast<String, dynamic>() ?? const {};

      if (!mounted) return;
      setState(() {
        _projectLabel = '${data['projectText'] ?? data['project'] ?? ''}';
        final territory =
            (data['territory'] as Map?)?.cast<String, dynamic>() ?? const {};
        _region = '${territory['region'] ?? data['region'] ?? ''}';
        _recommendation =
            (derived['recommendation'] as Map?)?.cast<String, dynamic>() ??
                const {};
        _blockingAlerts = (derived['blockingAlerts'] as List?)
                ?.map((e) => '$e')
                .toList() ??
            const [];
        _aides = (derived['aides'] as List?)
                ?.map((e) => (e as Map).cast<String, dynamic>())
                .toList() ??
            const [];
        _plan30 = (derived['plan30'] as List?)
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
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

    return _JourneySummaryPage(
      projectLabel: _projectLabel,
      region: _region,
      recommendation: _recommendation,
      blockingAlerts: _blockingAlerts,
      aides: _aides,
      plan30: _plan30,
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

class _PlanTaskSummaryTile extends StatelessWidget {
  final String title;
  final String week;
  final bool completed;

  const _PlanTaskSummaryTile({
    required this.title,
    required this.week,
    required this.completed,
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
            completed ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            color: completed ? const Color(0xFF0F766E) : const Color(0xFF9CA3AF),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
              ],
            ),
          ),
        ],
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
