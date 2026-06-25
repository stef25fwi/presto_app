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
import 'package:presto_app/services/toolbox_cache_service.dart';
import 'package:url_launcher/url_launcher.dart';
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

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _cacheService = ToolboxCacheService();

  // UI state
  int _step = 1; // 1..3
  bool _loading = true;
  bool _saving = false;
  bool _isLocalOnlyMode = false;
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

  String _situation = ''; // Salarié / Fonctionnaire / etc.

  String _region = '';
  String _departement = '';
  String _commune = '';

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
        _step = step.clamp(1, 3);
        _journeyStatus = status == 'completed' ? 'completed' : 'draft';
        _isLocalOnlyMode = false;
        _isFromCache = false;

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
    if (_situation == 'Fonctionnaire / agent public') {
      blocking.add(
          "Cumul : demande écrite hiérarchique + règles spécifiques (temps partiel / durée encadrée).");
    }
    if (_situation == "Demandeur d'emploi") {
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
          _situation == "Demandeur d'emploi"),
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
    if (_ambition.contains('Croissance') || _caVise > 60000)
      p.add('Croissance');
    if (p.isEmpty) return ['Simplicité', 'Coût', 'Rapidité'];
    return p.take(3).toList();
  }

  // --------------------------
  // Navigation
  // --------------------------
  bool get _step1Valid => _region.isNotEmpty;
  bool get _step2Valid => _projectCtrl.text.trim().length >= 6;
  bool get _step3Valid => _situation.isNotEmpty;

  Future<void> _next() async {
    if (_step == 1 && !_step1Valid) return;
    if (_step == 2 && !_step2Valid) return;
    if (_step == 3 && !_step3Valid) return;

    setState(() => _step = (_step + 1).clamp(1, 3));
    await _saveDraft();
    // If we moved past 3, we stay on 3 and show "Mon parcours" below.
  }

  Future<void> _completeJourney() async {
    if (!_step3Valid) return;

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
    setState(() => _step = (_step - 1).clamp(1, 3));
    await _saveDraft();
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
        return 'Ta région';
      case 2:
        return 'Ton projet';
      case 3:
        return 'Ta situation';
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
        return 'Ta région personnalise les aides, les contacts locaux et le plan d action.';
      case 2:
        return 'Posez les bases du projet pour lancer une premiere recommandation exploitable.';
      case 3:
        return 'On ajuste les alertes et aides selon votre contexte personnel et professionnel.';
      default:
        return 'Décrivez ton projet, ta situation et ton territoire.';
    }
  }

  IconData get _currentStepIcon {
    switch (_step) {
      case 1:
        return Icons.place_outlined;
      case 2:
        return Icons.explore_outlined;
      case 3:
        return Icons.badge_outlined;
      default:
        return Icons.auto_awesome;
    }
  }

  Widget _buildHeroHighlights() {
    final items = <Map<String, String>>[
      {
        'label': 'Etape',
        'value': _journeyStatus == 'completed' ? 'Finalise' : '$_step/3',
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
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kOrange,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text("Boîte à outils"),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(
                child: SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _bootstrap)
              : SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(6, 14, 6, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _HeaderInfoCard(
                          title: _currentStepTitle,
                          subtitle: _currentStepDescription,
                          accent: kBlue,
                          icon: _currentStepIcon,
                          eyebrow: _journeyStatus == 'completed'
                              ? 'Parcours finalise'
                              : 'Etape $_step sur 3',
                          progressValue:
                              _journeyStatus == 'completed' ? 1 : _step / 3,
                          progressLabel: _journeyStatus == 'completed'
                              ? 'Parcours pret a relire ou modifier'
                              : 'Progression active du parcours',
                          footer: _buildHeaderStatusPanel(),
                        ),
                        if (_isLocalOnlyMode) ...[
                          const SizedBox(height: 12),
                          const _InfoBox(
                            icon: Icons.cloud_off_outlined,
                            title: 'Mode local non sauvegardé',
                            text:
                                "Tes réponses restent utilisables sur cet écran, mais elles ne seront pas reprises automatiquement plus tard tant que la persistance n'est pas disponible.",
                          ),
                        ],
                        if (_journeyStatus == 'completed') ...[
                          const SizedBox(height: 12),
                          _InfoBox(
                            icon: Icons.verified_outlined,
                            title: 'Parcours validé',
                            text: _isLocalOnlyMode
                                ? 'Ce parcours a été validé localement. Toute nouvelle modification remettra le parcours en brouillon.'
                                : 'Ce parcours a été validé et sauvegardé. Toute nouvelle modification remettra le parcours en brouillon.',
                          ),
                          const SizedBox(height: 12),
                          _buildCompletionActionsCard(),
                        ],
                        const SizedBox(height: 12),
                        _StepperBar(step: _step),
                        const SizedBox(height: 12),

                        // Step content
                        if (_step == 1) _buildStepRegion(),
                        if (_step == 2) _buildStepProject(),
                        if (_step == 3) _buildStepSituation(),

                        const SizedBox(height: 14),
                        _buildNavButtons(),

                        const SizedBox(height: 18),
                        _buildMyPath(),
                      ],
                    ),
                  ),
                ),
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
      stepLabel: "Étape 2/3",
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
    final items = <String>[
      "Salarié",
      "Fonctionnaire / agent public",
      "Activité secondaire",
      "Demandeur d'emploi",
      "Créateur / Entrepreneur (temps plein)",
      "Étudiant / En formation",
    ];

    return _Card(
      title: "Votre situation actuelle",
      stepLabel: "Étape 3/3",
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
      stepLabel: "Étape 1/3",
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
          setState(() => _region = r);
          Navigator.pop(ctx);
          _onAnyFieldChanged();
        },
      ),
    );
  }

  Widget _buildNavButtons() {
    final canNext = (_step == 1 && _step1Valid) ||
        (_step == 2 && _step2Valid) ||
        (_step == 3 && _step3Valid);
    final isFinalStep = _step == 3;

    return Container(
      padding: const EdgeInsets.fromLTRB(6, 12, 6, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
                      canNext ? (isFinalStep ? _completeJourney : _next) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kBlue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: kBlue.withOpacity(0.35),
                    disabledForegroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: Icon(
                    _step < 3
                        ? Icons.arrow_forward
                        : Icons.check_circle_outline,
                  ),
                  label: Text(
                    _step < 3
                        ? "Suivant"
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
                        color: color.withOpacity(0.28),
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
            color: Colors.black.withOpacity(0.035),
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
        color: Colors.white.withOpacity(0.82),
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
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.22)),
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
  final Widget child;

  const _Card({
    required this.title,
    required this.child,
    this.stepLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Color(0xFFF8F9FC),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
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
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  stepLabel?.split('/').first.replaceAll('Étape ', '') ?? '•',
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800, // Plus épais
                  ),
                ),
              ),
              if (stepLabel != null)
                Text(
                  stepLabel!,
                  style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
            ],
          ),
          const SizedBox(height: 10),
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
  final Widget? footer;
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
    this.footer,
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
            color: Colors.black.withOpacity(0.05),
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
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: accent.withOpacity(0.12)),
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
          if (footer != null) footer!,
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
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? Colors.grey.shade300 // Sélection gris clair
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? const Color(0xFF1A73E8) : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color:
                    selected ? const Color(0xFF1A73E8) : Colors.grey.shade700),
            const SizedBox(width: 10),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500)),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade600),
          ],
        ),
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
            color.withOpacity(0.10),
            const Color(0xFFFFF7ED),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.18)),
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
                  color: Colors.white.withOpacity(0.72),
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
        color: tone.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.withOpacity(0.16)),
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
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.18)),
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
                  color: _statusColor.withOpacity(0.10),
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
                  color: _statusColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _statusColor.withOpacity(0.16)),
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
                  value: status,
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
                          ? const Color(0xFF1A73E8).withOpacity(0.08)
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
