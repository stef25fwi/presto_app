import 'package:flutter/material.dart';

import '../utils/keyword_suggester.dart';

class EntrepreneurToolboxPage extends StatefulWidget {
  const EntrepreneurToolboxPage({super.key});

  @override
  State<EntrepreneurToolboxPage> createState() => _EntrepreneurToolboxPageState();
}

class _EntrepreneurToolboxPageState extends State<EntrepreneurToolboxPage> {
  // Presto colors
  static const Color kPrestoOrange = Color(0xFFFF6600);
  static const Color kPrestoBlue = Color(0xFF1A73E8);
  static const Color kBg = Color(0xFFF6F7FB);

  final TextEditingController _projectCtrl = TextEditingController();

  // Step data
  String? _region; // e.g. "Guadeloupe (971)"
  String? _situation; // "Salarié" / "Demandeur d’emploi" / ...
  String? _objective; // optional (can be inferred later)

  // Suggestions enrichies avec mots-clés/poids
  final List<SuggestionItem> _suggestionItems = const [
    SuggestionItem(
      label: "Créer une entreprise de vente de gâteaux",
      keywords: ["gateau", "patisserie", "boulangerie", "sucre", "dessert"],
      tags: ["food", "artisanat"],
      popularity: 90,
      weight: 10,
    ),
    SuggestionItem(
      label: "Ouvrir une pâtisserie",
      keywords: ["patisserie", "gateau", "dessert", "sucre"],
      tags: ["food", "artisanat"],
      popularity: 85,
      weight: 8,
    ),
    SuggestionItem(
      label: "Se lancer en micro-entrepreneur",
      keywords: ["micro", "autoentrepreneur", "statut", "activite"],
      tags: ["administratif"],
      popularity: 75,
      weight: 6,
    ),
    SuggestionItem(
      label: "Ouvrir un salon de coiffure / barber",
      keywords: ["coiffure", "barbier", "salon", "beaute"],
      tags: ["beauté"],
      popularity: 80,
      weight: 7,
    ),
    SuggestionItem(
      label: "Ouvrir un food truck / snack",
      keywords: ["food", "truck", "snack", "restauration", "streetfood"],
      tags: ["food", "restauration"],
      popularity: 82,
      weight: 7,
    ),
    SuggestionItem(
      label: "Social media manager pour TPE",
      keywords: ["social", "media", "reseaux", "instagram", "facebook", "tiktok", "community"],
      tags: ["digital", "marketing"],
      popularity: 61,
      weight: 5,
    ),
    SuggestionItem(
      label: "Formations en ligne / cours particuliers",
      keywords: ["formation", "cours", "coaching", "elearning", "enligne"],
      tags: ["education"],
      popularity: 59,
      weight: 4,
    ),
    SuggestionItem(
      label: "Location de matériel (sono, outils, voitures)",
      keywords: ["location", "materiel", "sono", "outil", "voiture", "equipement"],
      tags: ["services", "location"],
      popularity: 56,
      weight: 4,
    ),
    SuggestionItem(
      label: "Service de jardinage / paysagiste",
      keywords: ["jardinage", "paysage", "tonte", "elagage", "debro"],
      tags: ["services", "exterieur"],
      popularity: 88,
      weight: 8,
    ),
    SuggestionItem(
      label: "Réparation smartphones / petits appareils",
      keywords: ["reparation", "smartphone", "telephone", "tablette", "electronique"],
      tags: ["tech", "service"],
      popularity: 76,
      weight: 6,
    ),
    SuggestionItem(
      label: "Menuiserie / agencement sur mesure",
      keywords: ["menuiserie", "bois", "agencement", "meuble", "surmesure"],
      tags: ["artisanat", "batiment"],
      popularity: 60,
      weight: 4,
    ),
    SuggestionItem(
      label: "Organisation d'événements / DJ / sono",
      keywords: ["evenement", "dj", "sono", "animation", "mariage"],
      tags: ["event", "music"],
      popularity: 84,
      weight: 7,
    ),
    SuggestionItem(
      label: "Services à domicile seniors (aide, courses)",
      keywords: ["senior", "aide", "domicile", "courses", "accompagnement"],
      tags: ["services", "social"],
      popularity: 71,
      weight: 6,
    ),
  ];

  List<String> get _chipSuggestions {
    final computed = KeywordSuggester.compute(
      query: _projectCtrl.text,
      items: _suggestionItems,
      region: _region,
      situation: _situation,
      limit: 8,
    );

    if (computed.isNotEmpty) {
      return computed.map((e) => e.label).toList(growable: false);
    }

    // Fallback : top popularités si rien ne matche
    return _suggestionItems
        .take(6)
        .map((e) => e.label)
        .toList(growable: false);
  }

  final List<String> _regions = const [
    "Guadeloupe (971)",
    "Martinique (972)",
    "Guyane (973)",
    "La Réunion (974)",
    "Mayotte (976)",
    "France métropolitaine",
  ];

  final List<_Choice> _situations = const [
    _Choice("Salarié", Icons.work_outline),
    _Choice("Demandeur d’emploi", Icons.search),
    _Choice("Créateur / Entrepreneur", Icons.rocket_launch_outlined),
    _Choice("Étudiant / En formation", Icons.school_outlined),
  ];

  // Simple validation
  bool get _canContinue =>
      _projectCtrl.text.trim().isNotEmpty && _region != null && _situation != null;

  @override
  void dispose() {
    _projectCtrl.dispose();
    super.dispose();
  }

  void _onSubmit() {
    if (!_canContinue) return;

    final payload = {
      "project": _projectCtrl.text.trim(),
      "region": _region,
      "situation": _situation,
      "objective": _objective, // can remain null
    };

    // TODO: Navigate to results page or call your rules engine.
    // For now: show a summary.
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Votre demande", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            _kv("Projet", payload["project"] as String),
            _kv("Situation", payload["situation"] as String),
            _kv("Région", payload["region"] as String),
            if (payload["objective"] != null) _kv("Objectif", payload["objective"] as String),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrestoOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.check),
                label: const Text("OK"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(k, style: const TextStyle(color: Colors.black54))),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kPrestoOrange,
        foregroundColor: Colors.white,
        title: const Text("Boîte à Outils"),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
        children: [
          _HeaderCard(
            orange: kPrestoOrange,
            blue: kPrestoBlue,
          ),
          const SizedBox(height: 20),
          
          // Horizontal Progress Stepper
          _HorizontalStepper(
            totalSteps: 3,
            currentStep: _getCurrentStep(),
            orange: kPrestoOrange,
          ),
          const SizedBox(height: 20),

          // STEP 1 - Project
          _StepCard(
            step: 1,
            title: "Que souhaitez-vous faire ?",
            subtitle: "Décrivez votre projet en une phrase.",
            trailing: const Text("Étape 1/3", style: TextStyle(color: Colors.black45)),
            isCompleted: _projectCtrl.text.trim().isNotEmpty,
            showConnector: true,
            orange: kPrestoOrange,
            child: Column(
              children: [
                TextField(
                  controller: _projectCtrl,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                  onTap: () {
                    // Sélectionne tout le texte au clic pour faciliter la réécriture
                    _projectCtrl.selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: _projectCtrl.text.length,
                    );
                  },
                  style: const TextStyle(fontSize: 16),
                  decoration: InputDecoration(
                    hintText: "Ex : Créer une entreprise de vente de gâteaux",
                    hintStyle: const TextStyle(fontSize: 16),
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.black.withOpacity(.08)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.black.withOpacity(.08)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: kPrestoBlue, width: 1.4),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Suggestions basées sur votre saisie",
                    style: TextStyle(color: Colors.black.withOpacity(.55), fontSize: 12),
                  ),
                ),
                const SizedBox(height: 6),
                _SuggestionChips(
                  items: _chipSuggestions,
                  onTap: (s) {
                    _projectCtrl.text = s;
                    setState(() {});
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 0),

          // STEP 2 - Situation
          _StepCard(
            step: 2,
            title: "Votre situation actuelle",
            subtitle: "Choisissez l'option qui vous correspond.",
            trailing: const Text("Étape 2/3", style: TextStyle(color: Colors.black45)),
            isCompleted: _situation != null,
            showConnector: true,
            orange: kPrestoOrange,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _situations.map((c) {
                final selected = _situation == c.label;
                return _ChoiceChipCard(
                  label: c.label,
                  icon: c.icon,
                  selected: selected,
                  orange: kPrestoOrange,
                  blue: kPrestoBlue,
                  onTap: () => setState(() => _situation = c.label),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 0),

          // STEP 3 - Region
          _StepCard(
            step: 3,
            title: "Votre territoire",
            subtitle: "Les organismes locaux s'adaptent à votre région.",
            trailing: const Text("Étape 3/3", style: TextStyle(color: Colors.black45)),
            isCompleted: _region != null,
            showConnector: false,
            orange: kPrestoOrange,
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: _region,
                  items: _regions
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) => setState(() => _region = v),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.place_outlined),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.black.withOpacity(.08)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.black.withOpacity(.08)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black.withOpacity(.06)),
                  ),
                  child: const Text(
                    "Les liens nationaux restent identiques (INPI, URSSAF...). "
                    "Les liens locaux changent (CCI, Région, Département, France Travail…).",
                    style: TextStyle(color: Colors.black54, height: 1.25),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // CTA
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrestoBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
              ),
              onPressed: _canContinue ? _onSubmit : null,
              icon: const Icon(Icons.arrow_forward),
              label: const Text(
                "Voir mon parcours personnalisé",
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              "Accédez aux étapes, coûts et aides adaptés à votre projet.",
              style: TextStyle(color: Colors.black45),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final Color orange;
  final Color blue;

  const _HeaderCard({required this.orange, required this.blue});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: blue,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(.10), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: const [
          Icon(Icons.construction, color: Colors.white, size: 28),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "Décrivez votre projet et on vous guide\navec les bons organismes et démarches.",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, height: 1.2),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final int step;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;
  final bool isCompleted;
  final bool showConnector;
  final Color orange;

  const _StepCard({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.isCompleted,
    required this.showConnector,
    required this.orange,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stepper column on the left
        Column(
          children: [
            // Circle with number
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted ? orange : Colors.white,
                border: Border.all(
                  color: isCompleted ? orange : Colors.black.withOpacity(.2),
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  "$step",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: isCompleted ? Colors.white : Colors.black87,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            // Connector line
            if (showConnector)
              Container(
                width: 2,
                height: 60,
                color: orange.withOpacity(0.3),
              ),
          ],
        ),
        const SizedBox(width: 12),
        // Card content
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.black.withOpacity(.06)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 14, offset: const Offset(0, 6)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    ),
                    if (trailing != null) trailing!,
                    if (trailing != null) trailing!,
                  ],
                ),
                const SizedBox(height: 6),
                Text(subtitle, style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 12),
                child,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SuggestionChips extends StatelessWidget {
  final List<String> items;
  final void Function(String) onTap;

  const _SuggestionChips({required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((s) {
        return InkWell(
          onTap: () => onTap(s),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(.04),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.black.withOpacity(.06)),
            ),
            child: Text(s, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        );
      }).toList(),
    );
  }
}

class _ChoiceChipCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color orange;
  final Color blue;
  final VoidCallback onTap;

  const _ChoiceChipCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.orange,
    required this.blue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? orange : Colors.white;
    final fg = selected ? Colors.white : Colors.black87;
    final bd = selected ? orange : Colors.black.withOpacity(.08);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: (MediaQuery.of(context).size.width - 16 * 2 - 10) / 2,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: bd),
        ),
        child: Row(
          children: [
            Icon(icon, color: fg),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: fg, fontWeight: FontWeight.w800),
              ),
            ),
            Icon(selected ? Icons.check_circle : Icons.chevron_right, color: fg),
          ],
        ),
      ),
    );
  }

  // Determine current step based on filled fields
  int _getCurrentStep() {
    if (_projectCtrl.text.isNotEmpty && _situation != null && _region != null) {
      return 3;
    } else if (_projectCtrl.text.isNotEmpty && _situation != null) {
      return 2;
    } else if (_projectCtrl.text.isNotEmpty) {
      return 1;
    }
    return 0;
  }
}

// Horizontal Stepper Widget
class _HorizontalStepper extends StatelessWidget {
  final int totalSteps;
  final int currentStep;
  final Color orange;

  const _HorizontalStepper({
    required this.totalSteps,
    required this.currentStep,
    required this.orange,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps, (index) {
        final stepNum = index + 1;
        final isCompleted = currentStep > stepNum;
        final isCurrent = currentStep == stepNum;
        
        return Expanded(
          child: Column(
            children: [
              // Step circle and connector
              Row(
                children: [
                  // Step circle
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCompleted || isCurrent ? orange : Colors.white,
                      border: Border.all(
                        color: isCompleted || isCurrent ? orange : Colors.grey.shade300,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: isCompleted
                          ? Icon(Icons.check, color: Colors.white, size: 18)
                          : Text(
                              '$stepNum',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isCompleted || isCurrent ? Colors.white : Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                    ),
                  ),
                  // Connector line (except for last step)
                  if (index < totalSteps - 1)
                    Expanded(
                      child: Container(
                        height: 2,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        color: isCompleted ? orange : Colors.grey.shade300,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // Step label
              Text(
                _getStepLabel(stepNum),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isCompleted || isCurrent ? FontWeight.w600 : FontWeight.normal,
                  color: isCompleted || isCurrent ? orange : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  String _getStepLabel(int step) {
    switch (step) {
      case 1:
        return "Projet";
      case 2:
        return "Situation";
      case 3:
        return "Région";
      default:
        return "";
    }
  }

class _Choice {
  final String label;
  final IconData icon;
  const _Choice(this.label, this.icon);
}
