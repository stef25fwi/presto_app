import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/messages/conversation_thread_page.dart';

const _preview = PendingVoiceNote(
  duration: Duration(minutes: 1, seconds: 5),
  previewSource: '',
  previewIsLocalFile: false,
  mimeType: 'audio/webm',
  extension: 'webm',
);

Future<void> _pumpPreview(
  WidgetTester tester, {
  required VoidCallback onCancel,
  required VoidCallback onRerecord,
  required VoidCallback onSend,
}) async {
  await tester.binding.setSurfaceSize(const Size(430, 932));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: VoiceNotePreviewSheet(
          preview: _preview,
          onCancel: onCancel,
          onRerecord: onRerecord,
          onSend: onSend,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  test('conserve toutes les métadonnées de la note vocale préparée', () {
    final preview = PendingVoiceNote(
      duration: const Duration(minutes: 2, seconds: 7),
      bytes: Uint8List.fromList(const <int>[1, 2, 3]),
      filePath: '/tmp/note.m4a',
      previewSource: 'https://cdn.ilipresto.fr/note.m4a',
      previewIsLocalFile: false,
      mimeType: 'audio/mp4',
      extension: 'm4a',
      usesGeneratedPreviewSource: true,
    );

    expect(preview.duration, const Duration(minutes: 2, seconds: 7));
    expect(preview.bytes, orderedEquals(const <int>[1, 2, 3]));
    expect(preview.filePath, '/tmp/note.m4a');
    expect(preview.previewSource, 'https://cdn.ilipresto.fr/note.m4a');
    expect(preview.previewIsLocalFile, isFalse);
    expect(preview.mimeType, 'audio/mp4');
    expect(preview.extension, 'm4a');
    expect(preview.usesGeneratedPreviewSource, isTrue);
  });

  testWidgets('rend la prévisualisation vocale et sa durée', (tester) async {
    await _pumpPreview(
      tester,
      onCancel: _noop,
      onRerecord: _noop,
      onSend: _noop,
    );

    expect(find.text('Relire la note vocale'), findsOneWidget);
    expect(find.text('Durée 01:05'), findsOneWidget);
    expect(find.text('Annuler'), findsOneWidget);
    expect(find.text('Refaire'), findsOneWidget);
    expect(find.text('Envoyer'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
  });

  testWidgets('déclenche Annuler', (tester) async {
    var calls = 0;
    await _pumpPreview(
      tester,
      onCancel: () => calls += 1,
      onRerecord: _noop,
      onSend: _noop,
    );
    await tester.tap(find.text('Annuler'));
    await tester.pump();
    expect(calls, 1);
  });

  testWidgets('déclenche Refaire', (tester) async {
    var calls = 0;
    await _pumpPreview(
      tester,
      onCancel: _noop,
      onRerecord: () => calls += 1,
      onSend: _noop,
    );
    await tester.tap(find.text('Refaire'));
    await tester.pump();
    expect(calls, 1);
  });

  testWidgets('déclenche Envoyer', (tester) async {
    var calls = 0;
    await _pumpPreview(
      tester,
      onCancel: _noop,
      onRerecord: _noop,
      onSend: () => calls += 1,
    );
    await tester.tap(find.text('Envoyer'));
    await tester.pump();
    expect(calls, 1);
  });

  testWidgets('rend une source locale sans casser le lecteur', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VoiceNotePreviewSheet(
            preview: const PendingVoiceNote(
              duration: Duration(seconds: 9),
              filePath: '/tmp/local-note.m4a',
              previewSource: '',
              previewIsLocalFile: true,
              mimeType: 'audio/mp4',
              extension: 'm4a',
            ),
            onCancel: _noop,
            onRerecord: _noop,
            onSend: _noop,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Durée 00:09'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
  });
}

void _noop() {}
