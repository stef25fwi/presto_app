from pathlib import Path

source_path = Path('lib/pages/messages/conversation_thread_page.dart')
source = source_path.read_text()
replacements = {
    'enum _VoiceNotePreviewAction': 'enum VoiceNotePreviewAction',
    'class _PendingVoiceNote': 'class PendingVoiceNote',
    'const _PendingVoiceNote({': 'const PendingVoiceNote({',
    'class _VoiceNotePreviewSheet': 'class VoiceNotePreviewSheet',
    'final _PendingVoiceNote preview;': 'final PendingVoiceNote preview;',
    'const _VoiceNotePreviewSheet({': 'const VoiceNotePreviewSheet({',
}
for old, new in replacements.items():
    if old not in source:
        raise SystemExit(f'missing source marker: {old}')
    source = source.replace(old, new)
source = source.replace('_PendingVoiceNote(', 'PendingVoiceNote(')
source = source.replace('_VoiceNotePreviewSheet(', 'VoiceNotePreviewSheet(')
source = source.replace('_VoiceNotePreviewAction.', 'VoiceNotePreviewAction.')
source_path.write_text(source)

test_path = Path('test/pages/messages/conversation_thread_voice_preview_coverage_test.dart')
test_path.write_text("""import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/messages/conversation_thread_page.dart';

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

  testWidgets('rend la prévisualisation et déclenche ses trois actions', (
    tester,
  ) async {
    var cancelCalls = 0;
    var rerecordCalls = 0;
    var sendCalls = 0;

    await tester.binding.setSurfaceSize(const Size(430, 932));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VoiceNotePreviewSheet(
            preview: const PendingVoiceNote(
              duration: Duration(minutes: 1, seconds: 5),
              previewSource: '',
              previewIsLocalFile: false,
              mimeType: 'audio/webm',
              extension: 'webm',
            ),
            onCancel: () => cancelCalls += 1,
            onRerecord: () => rerecordCalls += 1,
            onSend: () => sendCalls += 1,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Relire la note vocale'), findsOneWidget);
    expect(find.text('Durée 01:05'), findsOneWidget);
    expect(find.text('Annuler'), findsOneWidget);
    expect(find.text('Refaire'), findsOneWidget);
    expect(find.text('Envoyer'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

    await tester.tap(find.text('Annuler'));
    await tester.tap(find.text('Refaire'));
    await tester.tap(find.text('Envoyer'));
    await tester.pump();

    expect(cancelCalls, 1);
    expect(rerecordCalls, 1);
    expect(sendCalls, 1);
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
""")
