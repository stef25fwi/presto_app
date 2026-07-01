import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';

import '../../services/firebase_functions_region.dart';

import '../../utils/retry.dart';

double? _doubleOrNull(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

List<String>? _stringListOrNull(Object? value) {
  if (value == null) return null;
  if (value is List) {
    final out = <String>[];
    for (final item in value) {
      if (item == null) continue;
      out.add(item.toString());
    }
    return out;
  }
  return null;
}

Map<String, dynamic>? _mapOrNull(Object? value) {
  if (value == null) return null;
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

String? _firstNonEmptyStringFromMap(
  Map<String, dynamic> data,
  List<String> keys,
) {
  for (final key in keys) {
    final value = data[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return null;
}

Map<String, dynamic> _mapStringDynamic(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  throw const FormatException('Expected a Map payload from Cloud Functions');
}

class OfferBudget {
  final String? type;
  final double? min;
  final double? max;
  final String? currency;

  const OfferBudget({
    this.type,
    this.min,
    this.max,
    this.currency,
  });

  factory OfferBudget.fromMap(Map<String, dynamic> map) => OfferBudget(
        type: map['type']?.toString(),
        min: _doubleOrNull(map['min']),
        max: _doubleOrNull(map['max']),
        currency: map['currency']?.toString() ?? map['devise']?.toString(),
      );
}

class OfferDraft {
  final String? title;
  final String? description;
  final String? category;
  final String? city;
  final String? postalCode;
  final String? shortDescription;
  final String? sector;
  final String? availability;
  final List<String>? bullets;
  final List<String>? constraints;
  final List<String>? suggestedTitles;
  final List<String>? details;
  final List<String>? requiredSkills;
  final List<String>? requesterMaterials;
  final List<String>? providerMaterials;
  final List<String>? questions;
  final OfferBudget? budget;

  OfferDraft({
    this.title,
    this.description,
    this.category,
    this.city,
    this.postalCode,
    this.shortDescription,
    this.sector,
    this.availability,
    this.bullets,
    this.constraints,
    this.suggestedTitles,
    this.details,
    this.requiredSkills,
    this.requesterMaterials,
    this.providerMaterials,
    this.questions,
    this.budget,
  });

  factory OfferDraft.fromMap(Map<String, dynamic> m) => OfferDraft(
        title: m['title']?.toString(),
        description: m['description']?.toString(),
        category: _firstNonEmptyStringFromMap(m, const [
          'category',
          'categorie',
          'catégorie',
          'mainCategory',
          'main_category',
        ]),
        city: _firstNonEmptyStringFromMap(m, const [
          'city',
          'ville',
          'commune',
          'locality',
          'location',
          'lieu',
        ]),
        postalCode: _firstNonEmptyStringFromMap(m, const [
          'postalCode',
          'codePostal',
          'code_postal',
          'postal_code',
          'zipCode',
          'zipcode',
          'zip',
          'cp',
        ]),
        shortDescription: m['description_courte']?.toString() ??
            m['shortDescription']?.toString(),
        sector: m['secteur']?.toString() ?? m['sector']?.toString(),
        availability:
            m['disponibilites']?.toString() ?? m['availability']?.toString(),
        bullets: _stringListOrNull(m['bullets']),
        constraints: _stringListOrNull(m['constraints']),
        suggestedTitles: _stringListOrNull(m['suggestions_titres']) ??
            _stringListOrNull(m['suggestedTitles']),
        details: _stringListOrNull(m['details']),
        requiredSkills: _stringListOrNull(m['competences_requises']) ??
            _stringListOrNull(m['requiredSkills']),
        requesterMaterials: _stringListOrNull(
                _mapOrNull(m['materiel'])?['fourni_par_demandeur']) ??
            _stringListOrNull(m['requesterMaterials']),
        providerMaterials: _stringListOrNull(
                _mapOrNull(m['materiel'])?['a_prevoir_par_prestataire']) ??
            _stringListOrNull(m['providerMaterials']),
        questions: _stringListOrNull(m['questions_a_poser']) ??
            _stringListOrNull(m['questions']),
        budget: _mapOrNull(m['budget']) == null
            ? null
            : OfferBudget.fromMap(_mapOrNull(m['budget'])!),
      );

  String composedDescription({String? transcript}) {
    final sections = <String>[];

    void addSentence(String? value) {
      final text = (value ?? '').trim();
      if (text.isEmpty) return;
      sections.add(text);
    }

    String joinList(String prefix, List<String>? items) {
      final clean = (items ?? const <String>[])
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
      if (clean.isEmpty) return '';
      return '$prefix ${clean.join(', ')}.';
    }

    addSentence(description);
    if ((description ?? '').trim().isEmpty) {
      addSentence(shortDescription);
    }
    addSentence(joinList('Détails à prévoir :', details));
    addSentence(joinList('Compétences recherchées :', requiredSkills));
    addSentence(joinList('Matériel déjà disponible :', requesterMaterials));
    addSentence(joinList('Matériel à apporter :', providerMaterials));
    addSentence(availability == null || availability!.trim().isEmpty
        ? ''
        : 'Disponibilités : ${availability!.trim()}');

    if (sections.isEmpty) {
      addSentence(transcript);
    }

    return sections.join('\n\n').trim();
  }

  String bestTitle() {
    final direct = (title ?? '').trim();
    if (direct.isNotEmpty) return direct;
    for (final suggestion in suggestedTitles ?? const <String>[]) {
      final clean = suggestion.trim();
      if (clean.isNotEmpty) return clean;
    }
    return '';
  }

  int? inferredFixedBudgetAmount() {
    final typeValue = (budget?.type ?? '').trim().toLowerCase();
    if (typeValue != 'fixe') return null;

    final minValue = budget?.min;
    final maxValue = budget?.max;
    if (minValue == null && maxValue == null) return null;
    if (minValue != null && maxValue != null && minValue != maxValue) {
      return null;
    }

    final chosen = minValue ?? maxValue;
    if (chosen == null || chosen <= 0) return null;
    return chosen.round();
  }

  bool hasBudgetHint() {
    return budget?.min != null ||
        budget?.max != null ||
        (budget?.type ?? '').trim().isNotEmpty;
  }
}

class AiOfferService {
  /// Génère un brouillon à partir d'un texte (sans audio), avec retry.
  static Future<OfferDraft> generateDraft({
    required String hint,
    required String currentCity,
    required String currentCategory,
    FirebaseFunctions? functions,
  }) async {
    final res = await retry(
      () => callPrestoFunction<dynamic>(
        functions: functions ?? prestoFirebaseFunctions,
        name: 'generateOfferDraft',
        timeout: const Duration(seconds: 30),
        parameters: <String, dynamic>{
          'hint': hint,
          'city': currentCity,
          'category': currentCategory,
          'lang': 'fr',
        },
      ),
      maxAttempts: 2,
      retryIf: (e) {
        if (e is TimeoutException) return true;
        if (e is FirebaseFunctionsException) {
          return e.code == 'unavailable' ||
              e.code == 'deadline-exceeded' ||
              e.code == 'internal' ||
              e.code == 'resource-exhausted';
        }
        return false;
      },
    );

    final data = _mapStringDynamic(res.data);
    return OfferDraft.fromMap(data);
  }
}
