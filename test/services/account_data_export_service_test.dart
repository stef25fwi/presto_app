import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/account_data_export_service.dart';

void main() {
  group('AccountDataExportService', () {
    test('fetchExport retourne les données brutes renvoyées par le backend', () async {
      final service = AccountDataExportService(
        caller: () async => <String, dynamic>{
          'ok': true,
          'profile': <String, dynamic>{'displayName': 'Alex'},
          'listings': <dynamic>[],
        },
      );

      final data = await service.fetchExport();

      expect(data['ok'], isTrue);
      expect(data['profile'], <String, dynamic>{'displayName': 'Alex'});
      expect(data['listings'], isEmpty);
    });

    test('fetchExport tolère une réponse vide', () async {
      final service = AccountDataExportService(caller: () async => null);

      final data = await service.fetchExport();

      expect(data, isEmpty);
    });

    test('exportAndDownload encode les données en JSON indenté et déclenche la sauvegarde', () async {
      Uint8List? savedBytes;
      String? savedFileName;
      final service = AccountDataExportService(
        caller: () async => <String, dynamic>{'profile': <String, dynamic>{'uid': 'u1'}},
        saver: ({required bytes, required fileName}) async {
          savedBytes = bytes;
          savedFileName = fileName;
          return true;
        },
      );

      final result = await service.exportAndDownload(fileName: 'export-test.json');

      expect(result, isTrue);
      expect(savedFileName, 'export-test.json');
      final decoded = jsonDecode(utf8.decode(savedBytes!)) as Map<String, dynamic>;
      expect(decoded['profile'], <String, dynamic>{'uid': 'u1'});
    });

    test('exportAndDownload répercute un échec de sauvegarde', () async {
      final service = AccountDataExportService(
        caller: () async => <String, dynamic>{},
        saver: ({required bytes, required fileName}) async => false,
      );

      final result = await service.exportAndDownload();

      expect(result, isFalse);
    });
  });
}
