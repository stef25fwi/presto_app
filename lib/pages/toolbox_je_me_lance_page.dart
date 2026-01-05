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

  // UI state
  int _step = 1; // 1..3
  bool _loading = true;
  bool _saving = false;
  String? _error;

  // Parcours Firestore
  String? _parcoursId;

  // Form fields
  final TextEditingController _projectCtrl = TextEditingController();
  String _activityType = 'Prestation de services'; // default
  String _clientele = 'Particuliers (B2C)';
  String _businessModel = 'Ponctuel';

  String _situation = ''; // Salarié / Fonctionnaire / etc.

  String _region = '';
  String _departement = '';
  String _commune = '';

  // Extra fields (optional but useful)
  String _ambition = 'Tester l’idée';
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
      debugPrint('[Toolbox] latest parcours orderBy failed: $e');
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
      debugPrint('[Toolbox] latest parcours fallback failed: $e');
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

        _recomputeDerived();
      } else {
        final d = latest;
        _parcoursId = d.id;

        final map = d.data();
        final data = (map['data'] as Map<String, dynamic>?) ?? {};
        final derived = (map['derived'] as Map<String, dynamic>?) ?? {};
        final step = (map['step'] as num?)?.toInt() ?? 1;

        _importData(data);
        _importDerived(derived);
        _step = step.clamp(1, 3);

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
      final isDenied = e.code.toLowerCase() == 'permission-denied';
      if (isDenied) {
        // Si Firestore est inaccessible (App Check / règles / auth), on laisse l'utilisateur
        // accéder à la toolbox en mode local (sans persistance).
        _parcoursId = null;
        _recomputeDerived();
        setState(() {
          _loading = false;
          _error = null;
        });
        return;
      }

      setState(() {
        _loading = false;
        _error = "Erreur de chargement : ${e.message ?? e.code}";
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = "Erreur de chargement : $e";
      });
    }
  }

  // --------------------------
  // Autosave
  // --------------------------
  void _onAnyFieldChanged() {
    _autosaveDebounce?.cancel();
    _autosaveDebounce = Timer(const Duration(milliseconds: 500), () async {
      await _saveDraft();
    });
  }

  Future<void> _saveDraft({bool recompute = true}) async {
    final user = _auth.currentUser;
    if (user == null || _parcoursId == null) return;

    setState(() => _saving = true);
    try {
      if (recompute) _recomputeDerived();

      await _db
          .collection('users')
          .doc(user.uid)
          .collection('parcours')
          .doc(_parcoursId)
          .set({
        'status': 'draft',
        'step': _step,
        'updatedAt': FieldValue.serverTimestamp(),
        'data': _exportData(),
        'derived': _exportDerived(),
      }, SetOptions(merge: true));

      if (mounted) setState(() => _saving = false);
    } on FirebaseException catch (e) {
      // Ne bloque pas l'écran si Firestore est interdit; on continue en mode non persistant.
      if (mounted) {
        setState(() {
          _saving = false;
          if (e.code.toLowerCase() != 'permission-denied') {
            _error = "Erreur de sauvegarde : ${e.message ?? e.code}";
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = "Erreur de sauvegarde : $e";
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
  // Derived computation (RULES)
  // --------------------------
  void _recomputeDerived() {
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
          "Cumul : demande écrite hiérarchique + règles spécifiques (temps partiel / durée encadrée)." );
    }
    if (_situation == "Demandeur d’emploi") {
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
          "Plus adapté si tu as beaucoup de frais : déduction plus fine qu’en micro.";
      planB =
          "Créer une EURL/SASU si besoin de séparation plus forte ou d’associés.";
    } else if (wantsGrowth ||
        _association ||
        _businessModel == 'Marketplace/plateforme') {
      statut = "SASU / SAS";
      why =
          "Adapté à la croissance, crédibilité, possible ouverture à des associés/investisseurs.";
      planB =
          "EURL/SARL si tu veux un cadre plus ‘classique’ et souvent moins coûteux à gérer selon cas.";
    } else {
      statut = "EURL / SARL";
      why =
          "Cadre stable et ‘classique’, souvent apprécié pour une petite structure.";
      planB = "SASU/SAS si projet innovant, croissance, associés, levée.";
    }

    // Costs (rough placeholders; you can localize later)
    final costs = <String, dynamic>{
      'formalitesEstimees': _estimateFormalites(statut),
      'annonceLegale':
          (statut.contains('SAS') || statut.contains('EURL')) ? 180 : 0,
      'assuranceProAn': 250,
      'comptableAn': (statut.contains('SAS') || statut.contains('EURL')) ? 1200 : 0,
      'banqueOutilsAn': 120,
      'note':
          "Estimations indicatives. Les montants varient selon activité et département.",
    };

    // Aides (checklist)
    final aides = <Map<String, dynamic>>[
      _aid("ACRE", "Exonération partielle de cotisations au démarrage", true),
      _aid("ARCE", "Capital France Travail (si ARE + conditions)",
          _situation == "Demandeur d’emploi"),
      _aid("Prêt d’honneur", "Initiative France / Réseau Entreprendre", true),
      _aid("Aides territoriales",
          "Région / Département / Agglo (selon territoire)", true),
      _aid(
          "Fonds européens",
          "FEDER / FSE+ / FEADER (via programmes régionaux)",
          true),
    ];

    // Plan 30 jours
    final plan = <Map<String, dynamic>>[
      _task("Semaine 1", "Vérifier activité réglementée (si concerné)"),
      _task("Semaine 1", "Choisir statut + option TVA"),
      _task("Semaine 1", "Lister 10 clients cibles + offre + tarif"),
      _task("Semaine 2", "Contacter CCI/CMA/BGE et prendre 1 RDV"),
      _task("Semaine 2", "Chercher aides via Aides-territoires + Région"),
      _task("Semaine 3", "Monter dossier ACRE / France Travail (si concerné)"),
      _task("Semaine 3", "Préparer dossier subvention (résumé + budget + devis)"),
      _task("Semaine 4", "Déposer formalités via guichet unique"),
      _task("Semaine 4", "Assurances + compte bancaire pro si nécessaire"),
      _task("Semaine 4", "1ère action commerciale (prospection / pub / partenariats)"),
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
    if (_ambition.contains('Croissance') || _caVise > 60000) p.add('Croissance');
    if (p.isEmpty) return ['Simplicité', 'Coût', 'Rapidité'];
    return p.take(3).toList();
  }

  // --------------------------
  // Navigation
  // --------------------------
  bool get _step1Valid => _projectCtrl.text.trim().length >= 6;
  bool get _step2Valid => _situation.isNotEmpty;
  bool get _step3Valid => _region.isNotEmpty && _departement.isNotEmpty;

  Future<void> _next() async {
    if (_step == 1 && !_step1Valid) return;
    if (_step == 2 && !_step2Valid) return;
    if (_step == 3 && !_step3Valid) return;

    setState(() => _step = (_step + 1).clamp(1, 3));
    await _saveDraft();
    // If we moved past 3, we stay on 3 and show "Mon parcours" below.
  }

  Future<void> _back() async {
    setState(() => _step = (_step - 1).clamp(1, 3));
    await _saveDraft();
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
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _HeaderInfoCard(
                          title: "Je me lance",
                          subtitle:
                              "Décris ton projet, ta situation et ton territoire. On génère un parcours personnalisé avec statut conseillé, aides, coûts et plan 30 jours.",
                          accent: kBlue,
                        ),
                        const SizedBox(height: 12),
                        _StepperBar(step: _step),
                        const SizedBox(height: 12),

                        // Step content
                        if (_step == 1) _buildStepProject(),
                        if (_step == 2) _buildStepSituation(),
                        if (_step == 3) _buildStepTerritory(),

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
      "Organisation d’événements / DJ / sono",
      "Ouvrir un food truck / snack",
      "Ouvrir un salon de coiffure / barber",
      "Réparation smartphones / petits appareils",
      "Se lancer en micro-entrepreneur",
    ];

    return _Card(
      title: "Que souhaitez-vous faire ?",
      stepLabel: "Étape 1/3",
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
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
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
            label: "Type d’activité",
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
              "Tester l’idée",
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
            title: const Text("Besoin de s’associer ?"),
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
      "Demandeur d’emploi",
      "Créateur / Entrepreneur (temps plein)",
      "Étudiant / En formation",
    ];

    return _Card(
      title: "Votre situation actuelle",
      stepLabel: "Étape 2/3",
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

  Widget _buildStepTerritory() {
    return _Card(
      title: "Votre territoire",
      stepLabel: "Étape 3/3",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("Les organismes locaux s’adaptent à votre région."),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              labelText: "Région",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (v) {
              setState(() => _region = v.trim());
              _onAnyFieldChanged();
            },
            controller: TextEditingController(text: _region),
          ),
          const SizedBox(height: 10),
          TextField(
            decoration: InputDecoration(
              labelText: "Département (ex: 971)",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (v) {
              setState(() => _departement = v.trim());
              _onAnyFieldChanged();
            },
            controller: TextEditingController(text: _departement),
          ),
          const SizedBox(height: 10),
          TextField(
            decoration: InputDecoration(
              labelText: "Commune (optionnel)",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (v) {
              setState(() => _commune = v.trim());
              _onAnyFieldChanged();
            },
            controller: TextEditingController(text: _commune),
          ),
          const SizedBox(height: 12),
          const _InfoBox(
            icon: Icons.info_outline,
            title: "Astuce",
            text:
                "Même si tu ne connais pas encore tous les contacts, ce parcours te sort déjà une liste de guichets incontournables (CCI/CMA/BGE/URSSAF/INPI/France Travail).",
          ),
        ],
      ),
    );
  }

  Widget _buildNavButtons() {
    final canNext = (_step == 1 && _step1Valid) ||
        (_step == 2 && _step2Valid) ||
        (_step == 3 && _step3Valid);

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _step > 1 ? _back : null,
            icon: const Icon(Icons.arrow_back),
            label: const Text("Retour"),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: canNext ? _next : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: kBlue,
              foregroundColor: Colors.white,
              disabledBackgroundColor: kBlue.withOpacity(0.35),
              disabledForegroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.arrow_forward),
            label: Text(_step < 3 ? "Suivant" : "Valider"),
          ),
        ),
      ],
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
          title: "Commence par l’étape 1",
          text:
              "Dès que tu saisis ton projet, on génère automatiquement : statut conseillé, alertes, coûts, aides et plan 30 jours.",
        ),
      );
    }

    final statut = (_recommendation['statut'] ?? '—') as String;
    final why = (_recommendation['why'] ?? '') as String;
    final planB = (_recommendation['planB'] ?? '') as String;
    final prios = (_recommendation['priorites'] as List?)
            ?.map((e) => '$e')
            .toList() ??
        [];

    final formalites = (_costs['formalitesEstimees'] as Map?)?.cast<String, dynamic>() ?? {};
    final fMin = formalites['min'] ?? 0;
    final fMax = formalites['max'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Card(
          title: "Mon parcours",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PillRow(
                title: "Statut conseillé",
                value: statut,
                color: kBlue,
              ),
              const SizedBox(height: 10),
              if (why.isNotEmpty)
                _InfoBox(icon: Icons.lightbulb_outline, title: "Pourquoi", text: why),
              if (planB.isNotEmpty) ...[
                const SizedBox(height: 10),
                _InfoBox(
                    icon: Icons.swap_horiz, title: "Plan B si ça grossit", text: planB),
              ],
              if (prios.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: prios.map((p) => Chip(label: Text(p))).toList(),
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
                  .map((a) => _Bullet(icon: Icons.warning_amber_rounded, text: a))
                  .toList(),
            ),
          ),
        ],

        const SizedBox(height: 12),
        _Card(
          title: "Coûts estimés",
          child: Column(
            children: [
              _CostRow(label: "Frais de formalités", value: "≈ $fMin à $fMax €"),
              _CostRow(
                  label: "Annonce légale", value: "≈ ${_costs['annonceLegale'] ?? 0} €"),
              _CostRow(
                  label: "Assurance pro / an", value: "≈ ${_costs['assuranceProAn'] ?? 0} €"),
              _CostRow(
                  label: "Comptable / an", value: "≈ ${_costs['comptableAn'] ?? 0} €"),
              _CostRow(
                  label: "Banque + outils / an", value: "≈ ${_costs['banqueOutilsAn'] ?? 0} €"),
              const SizedBox(height: 8),
              Text(
                "${_costs['note'] ?? ''}",
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
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
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.check_circle_outline),
                title: Text("${a['name']}"),
                subtitle: Text("${a['desc']}"),
                trailing: DropdownButton<String>(
                  value: (a['status'] ?? 'à checker') as String,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 'à checker', child: Text("à checker")),
                    DropdownMenuItem(value: 'demandé', child: Text("demandé")),
                    DropdownMenuItem(value: 'obtenu', child: Text("obtenu")),
                  ],
                  onChanged: (v) async {
                    if (v == null) return;
                    setState(() => a['status'] = v);
                    await _saveDraft();
                  },
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 12),
        _Card(
          title: "Plan d’action 30 jours",
          child: Column(
            children: _plan30.map((t) {
              return CheckboxListTile(
                value: (t['done'] ?? false) as bool,
                onChanged: (v) async {
                  setState(() => t['done'] = v ?? false);
                  await _saveDraft();
                },
                title: Text("${t['label']}"),
                subtitle: Text("${t['week']}"),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              );
            }).toList(),
          ),
        ),
      ],
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
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          dot(1, "Projet"),
          line(),
          dot(2, "Situation"),
          line(),
          dot(3, "Région"),
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
        color: _ToolboxJeMeLancePageState.kCardBg, // Fond gris clair
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
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
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w600),
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

  const _HeaderInfoCard({
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: _ToolboxJeMeLancePageState.kCardBg, // Fond gris clair
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.auto_awesome, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800, // Plus épais
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),
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
                  style: const TextStyle(fontWeight: FontWeight.w700)), // Plus épais
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
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
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
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)), // Plus épais
                const SizedBox(height: 4),
                Text(text, style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
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
    return Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)); // Plus épais
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
          items:
              items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
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

class _PillRow extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _PillRow({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withOpacity(0.35)),
          ),
          child: Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
        )
      ],
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
  final String label;
  final String value;
  const _CostRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)), // Plus épais
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
