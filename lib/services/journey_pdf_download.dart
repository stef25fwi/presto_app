import 'dart:typed_data';

import 'journey_pdf_download_io.dart'
    if (dart.library.html) 'journey_pdf_download_web.dart' as platform;

Future<bool> saveJourneyPdfBytes({
  required Uint8List bytes,
  required String fileName,
}) {
  return platform.saveJourneyPdfBytes(bytes: bytes, fileName: fileName);
}
