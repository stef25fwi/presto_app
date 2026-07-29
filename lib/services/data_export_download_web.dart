// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:typed_data';

Future<bool> saveDataExportBytes({
  required Uint8List bytes,
  required String fileName,
}) async {
  if (bytes.isEmpty) {
    throw StateError('Les données exportées sont vides.');
  }

  final blob = html.Blob(<Object>[bytes], 'application/json');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';

  html.document.body?.append(anchor);
  try {
    anchor.click();
  } finally {
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  }

  return true;
}
