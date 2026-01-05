import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

class CityEntry {
    /// Affichage user-friendly pour Paris arrondissements
    String get displayName {
      final match = RegExp(r'^PARIS (\d{2})').firstMatch(name);
      if (match != null) {
        final num = int.parse(match.group(1)!);
        final suffix = num == 1 ? 'er' : 'e';
        return 'Paris $num$suffix arrondissement';
      }
      return name;
    }
  final String name;
  final String dept; // "75", "971", "2A", "987"...
  final List<String> cps; // ["75001","75002",...]
  final String nameNorm;

  CityEntry({
    required this.name,
    required this.dept,
    required this.cps,
    required this.nameNorm,
  });

  factory CityEntry.fromJson(Map<String, dynamic> j) {
    final name = (j['name'] ?? '').toString();
    final dept = (j['dept'] ?? '').toString();
    final cps = (j['cps'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
    return CityEntry(
      name: name,
      dept: dept,
      cps: cps,
      nameNorm: _normalize(name),
    );
  }

  static String _normalize(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r"['']"), "'")
      .replaceAll(RegExp(r"[^\p{Letter}\p{Number}\s-]+", unicode: true), ' ')
      .replaceAll(RegExp(r"\s+"), " ")
      .trim();
}

class CityPostalService {
  List<CityEntry>? _all;

  Future<void> init() async {
    if (_all != null) return;
    final raw = await rootBundle.loadString('assets/data/cities_compact.json');
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    _all = list.map(CityEntry.fromJson).toList(growable: false);
  }

  String? _cp5(String text) {
    final m = RegExp(r'\b(\d{5})\b').firstMatch(text);
    return m?.group(1);
  }

  List<String> _deptCandidatesFromCp(String cp5) {
    if (cp5.startsWith('97') || cp5.startsWith('98')) return [cp5.substring(0, 3)];
    if (cp5.startsWith('20')) return ['2A', '2B']; // Corse
    return [cp5.substring(0, 2)];
  }

  List<CityEntry> search(String query, {String? cpHint, int limit = 50}) {
    final all = _all ?? const <CityEntry>[];
    final q = CityEntry._normalize(query);
    if (q.isEmpty) return const [];

    final cp = cpHint != null ? _cp5(cpHint) : null;
    final deptFilter = cp != null ? _deptCandidatesFromCp(cp) : null;

    final seen = <String>{};
    final out = <CityEntry>[];

    bool addCity(CityEntry c) {
      final key = '${c.name}|${c.dept}';
      if (seen.contains(key)) return false;
      if (deptFilter != null && !deptFilter.contains(c.dept)) return false;
      out.add(c);
      seen.add(key);
      return out.length >= limit;
    }

    // Alias Paris => retourne tous les arrondissements rapidement
    if (q == 'paris') {
      for (final c in all) {
        if (c.nameNorm.startsWith('paris')) {
          if (addCity(c)) break;
        }
      }
      if (out.length >= limit) return out;
    }

    for (final c in all) {
      if (c.nameNorm.startsWith(q)) {
        if (addCity(c)) break;
      }
    }

    if (out.length < limit) {
      for (final c in all) {
        if (c.nameNorm.contains(q)) {
          if (addCity(c)) break;
        }
      }
    }

    return out;
  }
}

/// Widget à utiliser dans tes formulaires.
/// - Tape la ville => suggestions
/// - Clique => remplit ville + CP
/// - Si plusieurs CP => choix via bottom sheet
class CityPostalAutocompleteField extends StatefulWidget {
  final TextEditingController cityController;
  final TextEditingController postalCodeController;
  final InputDecoration decoration;

  const CityPostalAutocompleteField({
    super.key,
    required this.cityController,
    required this.postalCodeController,
    required this.decoration,
  });

  @override
  State<CityPostalAutocompleteField> createState() => _CityPostalAutocompleteFieldState();
}

class _CityPostalAutocompleteFieldState extends State<CityPostalAutocompleteField> {
  final CityPostalService _service = CityPostalService();
  Timer? _debounce;
  List<CityEntry> _options = const [];

  @override
  void initState() {
    super.initState();
    _service.init();
    widget.cityController.addListener(_onCityChanged);
  }

  @override
  void dispose() {
    widget.cityController.removeListener(_onCityChanged);
    _debounce?.cancel();
    super.dispose();
  }

  void _onCityChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), () async {
      await _service.init();

      final q = widget.cityController.text.trim();
      if (q.isEmpty) {
        if (!mounted) return;
        setState(() => _options = const []);
        return;
      }

      final res = _service.search(
        q,
        cpHint: widget.postalCodeController.text,
        limit: 50,
      );

      if (!mounted) return;
      setState(() => _options = res);
    });
  }

  Future<void> _applySelection(CityEntry c) async {
    widget.cityController.text = c.name;

    if (c.cps.isEmpty) return;

    // 1 seul CP => auto
    if (c.cps.length == 1) {
      widget.postalCodeController.text = c.cps.first;
      return;
    }

    // Si user a déjà tapé un CP qui match => on garde
    final typed = RegExp(r'\b(\d{5})\b').firstMatch(widget.postalCodeController.text)?.group(1);
    if (typed != null && c.cps.contains(typed)) {
      widget.postalCodeController.text = typed;
      return;
    }

    // Sinon choix
    final picked = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: Text("Choisir le code postal – ${c.name}",
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          ...c.cps.map((cp) => ListTile(
                title: Text(cp),
                onTap: () => Navigator.pop(context, cp),
              )),
          const SizedBox(height: 12),
        ],
      ),
    );

    if (picked != null) widget.postalCodeController.text = picked;
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<CityEntry>(
      optionsBuilder: (_) => _options,
      displayStringForOption: (c) => c.displayName,
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        controller.value = widget.cityController.value;
        return TextFormField(
          controller: widget.cityController,
          focusNode: focusNode,
          decoration: widget.decoration,
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final list = options.toList();
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300, maxWidth: 520),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final c = list[i];
                  final cpLabel = c.cps.isEmpty
                      ? ""
                      : (c.cps.length == 1 ? c.cps.first : "${c.cps.first} … (+${c.cps.length - 1})");
                  return ListTile(
                    dense: true,
                    title: Text(c.displayName),
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