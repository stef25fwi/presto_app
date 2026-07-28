import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<bool> saveDataExportBytes({
  required Uint8List bytes,
  required String fileName,
}) async {
  final savedPath = await FilePicker.saveFile(
    dialogTitle: 'Télécharger mes données iliprestō',
    fileName: fileName,
    type: FileType.custom,
    allowedExtensions: const ['json'],
    bytes: bytes,
  );

  return savedPath != null;
}
