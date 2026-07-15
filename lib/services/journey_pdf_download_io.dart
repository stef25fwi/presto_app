import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<bool> saveJourneyPdfBytes({
  required Uint8List bytes,
  required String fileName,
}) async {
  final savedPath = await FilePicker.saveFile(
    dialogTitle: 'Télécharger mon parcours personnalisé',
    fileName: fileName,
    type: FileType.custom,
    allowedExtensions: const ['pdf'],
    bytes: bytes,
  );

  return savedPath != null;
}
