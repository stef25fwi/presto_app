import 'dart:typed_data';

import 'data_export_download_io.dart'
    if (dart.library.html) 'data_export_download_web.dart' as platform;

/// Propose le téléchargement d'un export de données (JSON) à l'utilisateur.
/// Retourne `true` si le fichier a été enregistré/proposé au téléchargement.
Future<bool> saveDataExportBytes({
  required Uint8List bytes,
  required String fileName,
}) {
  return platform.saveDataExportBytes(bytes: bytes, fileName: fileName);
}
