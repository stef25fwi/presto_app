import 'dart:async';
import 'package:flutter/material.dart';
import '../services/city_repo_compact.dart';

class CityPostalAutocompleteCompact extends StatefulWidget {
  final CityRepoCompact repo;
  final TextEditingController cityCtrl;
  final TextEditingController cpCtrl;
  final InputDecoration decoration;

  const CityPostalAutocompleteCompact({
    super.key,
    required this.repo,
    required this.cityCtrl,
    required this.cpCtrl,
    required this.decoration,
  });

  @override
  State<CityPostalAutocompleteCompact> createState() => _CityPostalAutocompleteCompactState();
}

class _CityPostalAutocompleteCompactState extends State<CityPostalAutocompleteCompact> {
  Timer? _debounce;
  List<CityEntry> _options = const [];

  @override
  void initState() {
    super.initState();
    widget.repo.init(); // fire & forget (le 1er search attendra _all dispo)
    widget.cityCtrl.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.cityCtrl.removeListener(_onChanged);
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), () async {
      await widget.repo.init();
      final q = widget.cityCtrl.text.trim();
      if (q.isEmpty) {
        if (mounted) setState(() => _options = const []);
        return;
      }
      final res = widget.repo.search(q, cpHint: widget.cpCtrl.text, limit: 15);
      if (!mounted) return;
      setState(() => _options = res);
    });
  }

  Future<void> _applySelection(CityEntry c) async {
    widget.cityCtrl.text = c.name;

    if (c.cps.isEmpty) return;

    // Si 1 seul CP => auto
    if (c.cps.length == 1) {
      widget.cpCtrl.text = c.cps.first;
      return;
    }

    // Si user a déjà tapé un CP qui match => on garde
    final typed = RegExp(r'\b(\d{5})\b').firstMatch(widget.cpCtrl.text)?.group(1);
    if (typed != null && c.cps.contains(typed)) {
      widget.cpCtrl.text = typed;
      return;
    }

    // Sinon: choix
    final picked = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ListView(
        shrinkWrap: true,
        children: [
          const ListTile(
            title: Text("Choisir le code postal", style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          ...c.cps.map((cp) => ListTile(
                title: Text(cp),
                onTap: () => Navigator.pop(context, cp),
              )),
          const SizedBox(height: 12),
        ],
      ),
    );

    if (picked != null) widget.cpCtrl.text = picked;
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<CityEntry>(
      optionsBuilder: (_) => _options,
      displayStringForOption: (c) => c.name,
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        controller.value = widget.cityCtrl.value;
        return TextFormField(
          controller: widget.cityCtrl,
          focusNode: focusNode,
          decoration: widget.decoration,
          validator: (v) => (v == null || v.trim().isEmpty) ? "Ville obligatoire" : null,
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300, maxWidth: 520),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: options.length,
                itemBuilder: (context, i) {
                  final c = options.elementAt(i);
                  final cpLabel = c.cps.isEmpty
                      ? ""
                      : (c.cps.length == 1 ? c.cps.first : "${c.cps.first} … (+${c.cps.length - 1})");
                  return ListTile(
                    dense: true,
                    title: Text(c.name),
                    subtitle: Text("${c.dept}${cpLabel.isNotEmpty ? " • $cpLabel" : ""}"),
                    onTap: () => onSelected(c),
                  );
                },
              ),
            ),
          ),
        );
      },
      onSelected: (c) => _applySelection(c),
    );
  }
}
