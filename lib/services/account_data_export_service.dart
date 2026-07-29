import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';

import 'data_export_download.dart';
import 'firebase_functions_region.dart';

typedef DataExportCaller = Future<Object?> Function();
typedef DataExportSaver = Future<bool> Function({
  required Uint8List bytes,
  required String fileName,
});

/// Export RGPD des données personnelles (droit à la portabilité) : récupère
/// le profil, les annonces, les avis et les métadonnées de conversation de
/// l'utilisateur connecté, puis propose le téléchargement en JSON.
class AccountDataExportService {
  AccountDataExportService({
    FirebaseFunctions? functions,
    DataExportCaller? caller,
    DataExportSaver? saver,
  })  : _functionsOverride = functions,
        _caller = caller,
        _saver = saver;

  final FirebaseFunctions? _functionsOverride;
  final DataExportCaller? _caller;
  final DataExportSaver? _saver;

  FirebaseFunctions get _functions =>
      _functionsOverride ?? prestoFirebaseFunctions;

  Future<Object?> _call() async {
    final caller = _caller;
    if (caller != null) return caller();
    final response = await callPrestoFunction<dynamic>(
      functions: _functions,
      name: 'exportMyData',
      timeout: const Duration(seconds: 30),
    );
    return response.data;
  }

  Future<Map<String, dynamic>> fetchExport() async {
    final rawData = await _call();
    return Map<String, dynamic>.from(
      (rawData as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{},
    );
  }

  /// Récupère l'export puis déclenche son téléchargement en JSON.
  /// Retourne `true` si le fichier a bien été proposé au téléchargement.
  Future<bool> exportAndDownload({
    String fileName = 'mes-donnees-ilipresto.json',
  }) async {
    final data = await fetchExport();
    final bytes = Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(data)),
    );
    final save = _saver ?? saveDataExportBytes;
    return save(bytes: bytes, fileName: fileName);
  }
}
