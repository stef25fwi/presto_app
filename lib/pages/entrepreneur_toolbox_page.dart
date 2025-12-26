import 'package:flutter/material.dart';

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

  // Suggestions (simple demo)
  final List<String> _projectSuggestions = const [
    "Créer une entreprise de vente de gâteaux",
    "Ouvrir une pâtisserie",
    "Se lancer en micro-entrepreneur",
    "Créer une activité de prestation de services",
  ];

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
          const SizedBox(height: 12),

          // STEP 1 - Project
          _StepCard(
            step: 1,
            title: "Que souhaitez-vous faire ?",
            subtitle: "Décrivez votre projet en une phrase.",
            child: Column(
              children: [
                TextField(
                  controller: _projectCtrl,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: "Ex : Créer une entreprise de vente de gâteaux",
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
                _SuggestionChips(
                  items: _projectSuggestions,
                  onTap: (s) {
                    _projectCtrl.text = s;
                    setState(() {});
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // STEP 2 - Situation
          _StepCard(
            step: 2,
            title: "Votre situation actuelle",
            subtitle: "Choisissez l’option qui vous correspond.",
            trailing: const Text("Étape 2/3", style: TextStyle(color: Colors.black45)),
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

          const SizedBox(height: 12),

          // STEP 3 - Region
          _StepCard(
            step: 3,
            title: "Votre territoire",
            subtitle: "Les organismes locaux s’adaptent à votre région.",
            trailing: const Text("Étape 3/3", style: TextStyle(color: Colors.black45)),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
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
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrestoOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        // Placeholder: here you'd call geolocator / places API.
                        // For demo we set Guadeloupe.
                        setState(() => _region = "Guadeloupe (971)");
                      },
                      child: const Text("Géolocaliser"),
                    ),
                  ],
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
        gradient: LinearGradient(
          colors: [orange, blue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
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

  const _StepCard({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
              CircleAvatar(
                radius: 14,
                backgroundColor: Colors.black.withOpacity(.06),
                child: Text(
                  "$step",
                  style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.black87),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 12),
          child,
        ],
      ),
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
}

class _Choice {
  final String label;
  final IconData icon;
  const _Choice(this.label, this.icon);
}
