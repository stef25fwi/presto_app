import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../services/geo_api_gouv_service.dart';
import '../services/location_text_normalizer.dart';

String _normalize(String value) => normalizeLocationLookupKey(value);

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
    final cps = (j['cps'] as List?)?.map((e) => e.toString()).toList() ??
        const <String>[];
    return CityEntry(
      name: name,
      dept: dept,
      cps: cps,
      nameNorm: _normalize(name),
    );
  }

  factory CityEntry.fromGeoApiGouv(GeoApiGouvCommune commune) {
    return CityEntry(
      name: commune.name,
      dept: commune.departmentCode,
      cps: commune.postalCodes,
      nameNorm: _normalize(commune.name),
    );
  }
}

class CityPostalService {
  /// Instance partagée : `cities_compact.json` (2,2 Mio) ne doit être
  /// téléchargé/décodé qu'une seule fois par session, pas à chaque montage.
  static final CityPostalService instance = CityPostalService();

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
    if (cp5.startsWith('97') || cp5.startsWith('98')) {
      return <String>[cp5.substring(0, 3)];
    }
    if (cp5.startsWith('20')) return <String>['2A', '2B']; // Corse
    return <String>[cp5.substring(0, 2)];
  }

  List<CityEntry> search(String query, {String? cpHint, int limit = 50}) {
    final all = _all ?? const <CityEntry>[];
    final q = normalizeLocationLookupKey(query);
    if (q.isEmpty) return const <CityEntry>[];

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

  /// Retourne la première entrée locale dont le CP correspond,
  /// en filtrant optionnellement par département.
  CityEntry? findByPostalCode(String cp, {String? dept}) {
    if (cp.isEmpty) return null;
    final all = _all ?? const <CityEntry>[];
    for (final entry in all) {
      if (!entry.cps.contains(cp)) continue;
      if (dept != null && dept.isNotEmpty && entry.dept != dept) continue;
      return entry;
    }
    return null;
  }
}

/// Widget à utiliser dans tes formulaires.
/// - Tape la ville => suggestions
/// - Geo API Gouv est interrogée après debounce si la recherche est précise
/// - Fallback local si l'API est indisponible
/// - Clique => remplit ville + CP
/// - Si plusieurs CP => choix via bottom sheet
class CityPostalAutocompleteField extends StatefulWidget {
  final TextEditingController cityController;
  final TextEditingController postalCodeController;
  final InputDecoration decoration;
  final ValueChanged<CityEntry>? onSelected;

  const CityPostalAutocompleteField({
    super.key,
    required this.cityController,
    required this.postalCodeController,
    required this.decoration,
    this.onSelected,
  });

  @override
  State<CityPostalAutocompleteField> createState() =>
      _CityPostalAutocompleteFieldState();
}

class _CityPostalAutocompleteFieldState
    extends State<CityPostalAutocompleteField> {
  final CityPostalService _localService = CityPostalService.instance;
  final GeoApiGouvService _geoService = GeoApiGouvService();

  Timer? _debounce;
  Timer? _postalDebounce;
  List<CityEntry> _options = const <CityEntry>[];
  int _citySerial = 0;
  int _postalSerial = 0;
  bool _isApplyingSelection = false;

  /// Vrai dès que l'utilisateur a modifié le champ ville manuellement
  /// (frappe directe, pas une sélection dans la liste).
  /// Quand ce flag est actif, la modification du CP ne doit PAS écraser la ville.
  bool _cityEnteredManually = false;

  @override
  void initState() {
    super.initState();
    _localService.init();
    widget.cityController.addListener(_onCityChanged);
    widget.postalCodeController.addListener(_onPostalCodeChanged);
  }

  @override
  void dispose() {
    widget.cityController.removeListener(_onCityChanged);
    widget.postalCodeController.removeListener(_onPostalCodeChanged);
    _debounce?.cancel();
    _postalDebounce?.cancel();
    _geoService.close();
    super.dispose();
  }

  void _onCityChanged() {
    // Si ce n'est pas une mise à jour programmatique (via _applySelection),
    // l'utilisateur est en train de taper : on protège la ville contre
    // un éventuel remplacement automatique depuis le champ CP.
    if (!_isApplyingSelection) {
      _cityEnteredManually = true;
    }

    _debounce?.cancel();

    _debounce = Timer(const Duration(milliseconds: 280), () async {
      final serial = ++_citySerial;

      await _localService.init();

      final q = widget.cityController.text.trim();
      final cpHint = widget.postalCodeController.text.trim();

      if (q.isEmpty) {
        if (!mounted || serial != _citySerial) return;
        setState(() => _options = const <CityEntry>[]);
        return;
      }

      // Résultat local immédiat : l'app reste utilisable même sans réseau.
      final localResults = _localService.search(
        q,
        cpHint: cpHint,
        limit: 50,
      );

      if (!mounted || serial != _citySerial) return;
      setState(() => _options = localResults);

      // Geo API Gouv seulement si la recherche est assez précise.
      if (!_shouldQueryGeoApi(q, cpHint)) return;

      final geoResults = await _searchGeoApiGouv(q, cpHint: cpHint);

      if (!mounted || serial != _citySerial) return;

      final merged = _mergeCityEntries(
        <CityEntry>[
          ...geoResults,
          ...localResults,
        ],
        limit: 50,
      );

      if (merged.isNotEmpty) {
        setState(() => _options = merged);
      }
    });
  }

  void _onPostalCodeChanged() {
    if (_isApplyingSelection) return;

    _postalDebounce?.cancel();
    _postalDebounce = Timer(const Duration(milliseconds: 280), () async {
      final serial = ++_postalSerial;
      final cp = _extractPostalCode(widget.postalCodeController.text.trim());

      // UX voulue :
      // - 1 à 4 chiffres : aucune auto-complétion ville.
      // - 5 chiffres : recherche CP -> commune.
      if (cp == null || cp.length != 5) {
        if (!mounted || serial != _postalSerial) return;
        setState(() => _options = const <CityEntry>[]);
        return;
      }

      await _localService.init();

      final queryHint = widget.cityController.text.trim();

      final localResults = _localService.search(
        queryHint.isEmpty ? cp : queryHint,
        cpHint: cp,
        limit: 50,
      );

      final geoCommunes = await _geoService.findCommunesByPostalCode(
        cp,
        limit: 20,
      );

      if (!mounted || serial != _postalSerial) return;

      final geoResults = geoCommunes
          .map(CityEntry.fromGeoApiGouv)
          .where((entry) => entry.name.trim().isNotEmpty)
          .toList(growable: false);

      final merged = _mergeCityEntries(
        <CityEntry>[
          ...geoResults,
          ...localResults,
        ],
        limit: 50,
      );

      if (merged.isEmpty) {
        setState(() => _options = const <CityEntry>[]);
        return;
      }

      // On garde aussi les suggestions disponibles sous le champ ville.
      setState(() => _options = merged);

      // CP complet => remplissage automatique de la ville.
      // On prend d'abord l'entrée locale (nom issu de cities_compact.json,
      // cohérent avec les documents seedés dans Firestore). Fallback sur
      // le premier résultat merged si aucune entrée locale ne correspond.
      final localEntry = _localService.findByPostalCode(cp);
      final selected = localEntry ??
          merged.firstWhere(
            (entry) => entry.cps.contains(cp),
            orElse: () => merged.first,
          );

      final officialCity = selected.name.trim();
      if (officialCity.isEmpty) return;

      // N'auto-remplir la ville que si le champ est vide ou n'a pas été
      // saisi manuellement, pour ne pas écraser une correction utilisateur.
      final currentCity = widget.cityController.text.trim();
      final canOverwriteCity = currentCity.isEmpty || !_cityEnteredManually;

      if (canOverwriteCity && currentCity != officialCity) {
        _isApplyingSelection = true;
        try {
          widget.cityController.text = officialCity;
        } finally {
          _isApplyingSelection = false;
        }
      }
    });
  }

  bool _shouldQueryGeoApi(String query, String cpHint) {
    final q = query.trim();
    final cp = _extractPostalCode(cpHint);

    if (cp != null && cp.length == 5) return true;

    // Évite les appels API à chaque petite frappe.
    return q.length >= 3;
  }

  Future<List<CityEntry>> _searchGeoApiGouv(
    String query, {
    required String cpHint,
  }) async {
    final q = query.trim();
    final cp = _extractPostalCode(cpHint);

    final communes = await _geoService.searchCommunesByName(
      q,
      postalCodeHint: cp,
      limit: 20,
    );

    return communes
        .map(CityEntry.fromGeoApiGouv)
        .where((entry) => entry.name.trim().isNotEmpty)
        .toList(growable: false);
  }

  List<CityEntry> _mergeCityEntries(
    List<CityEntry> entries, {
    required int limit,
  }) {
    final seen = <String>{};
    final out = <CityEntry>[];

    for (final entry in entries) {
      // Normalise les accents pour dédupliquer "Péron" (geo.api.gouv.fr)
      // et "PERON" (cities_compact.json) comme la même ville.
      // On utilise le premier CP comme représentant plutôt que la liste
      // entière, car l'ordre et le contenu peuvent différer selon la source.
      final normalizedName = normalizeLocationLookupKey(entry.name);
      final primaryCp = entry.cps.isNotEmpty ? entry.cps.first : '';
      final key = '$normalizedName|${entry.dept}|$primaryCp';
      if (seen.contains(key)) continue;

      seen.add(key);
      out.add(entry);

      if (out.length >= limit) break;
    }

    return out;
  }

  String? _extractPostalCode(String text) {
    final match = RegExp(r'\b(\d{5})\b').firstMatch(text);
    return match?.group(1);
  }

  Future<void> _applySelection(CityEntry c) async {
    await _localService.init();

    // Résoudre vers l'entrée locale pour garantir que le nom stocké dans le
    // contrôleur correspond au document seedé en Firestore.
    final primaryCp = c.cps.isNotEmpty ? c.cps.first : '';
    final resolved =
        _localService.findByPostalCode(primaryCp, dept: c.dept) ?? c;

    // L'utilisateur a explicitement choisi une ville dans la liste →
    // on réinitialise le flag "saisie manuelle" pour que le CP puisse
    // à nouveau mettre à jour la ville si l'utilisateur le modifie ensuite.
    _cityEnteredManually = false;
    _isApplyingSelection = true;
    try {
      widget.cityController.text = resolved.name;
    } finally {
      _isApplyingSelection = false;
    }

    final cps = resolved.cps.isNotEmpty ? resolved.cps : c.cps;
    if (cps.isEmpty) return;

    // 1 seul CP => auto
    if (cps.length == 1) {
      _isApplyingSelection = true;
      try {
        widget.postalCodeController.text = cps.first;
      } finally {
        _isApplyingSelection = false;
      }
      widget.onSelected?.call(resolved);
      return;
    }

    // Si user a déjà tapé un CP qui match => on garde
    final typed = RegExp(r'\b(\d{5})\b')
        .firstMatch(widget.postalCodeController.text)
        ?.group(1);
    if (typed != null && cps.contains(typed)) {
      _isApplyingSelection = true;
      try {
        widget.postalCodeController.text = typed;
      } finally {
        _isApplyingSelection = false;
      }
      widget.onSelected?.call(resolved);
      return;
    }

    // Sinon choix
    final picked = await showModalBottomSheet<String>(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: Text(
              'Choisir le code postal – ${resolved.name}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          ...cps.map(
            (cp) => ListTile(
              title: Text(cp),
              onTap: () => Navigator.pop(context, cp),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );

    if (picked != null) {
      _isApplyingSelection = true;
      try {
        widget.postalCodeController.text = picked;
      } finally {
        _isApplyingSelection = false;
      }
      widget.onSelected?.call(resolved);
    }
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
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final c = list[i];
                  final cpLabel = c.cps.isEmpty ? '' : c.cps.join(', ');
                  return ListTile(
                    dense: true,
                    title: Text(
                      c.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: cpLabel.isEmpty
                        ? Text('Département ${c.dept}')
                        : Text('$cpLabel · Département ${c.dept}'),
                    onTap: () => onSelected(c),
                  );
                },
              ),
            ),
          ),
        );
      },
      onSelected: _applySelection,
    );
  }
}
