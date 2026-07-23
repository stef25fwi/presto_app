import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/messages/conversation_thread_page.dart';

void main() {
  test('les composants visuels publics préservent leurs clés Flutter', () {
    const tileKey = ValueKey<String>('attachment-tile');
    const bannerKey = ValueKey<String>('conversation-banner');
    const patternKey = ValueKey<String>('conversation-pattern');
    const recorderKey = ValueKey<String>('voice-recorder');

    final tile = AttachmentActionTile(
      key: tileKey,
      icon: Icons.description_outlined,
      title: 'Document',
      subtitle: 'Ajouter une pièce jointe',
      onTap: () {},
    );
    const banner = ConversationBanner(
      key: bannerKey,
      icon: Icons.info_outline,
      color: Colors.orange,
      message: 'Information',
    );
    const pattern = ConversationPatternBackground(key: patternKey);
    final recorder = VoiceRecordingSheet(
      key: recorderKey,
      onCancel: () {},
      onSend: () {},
    );

    expect(tile.key, tileKey);
    expect(banner.key, bannerKey);
    expect(pattern.key, patternKey);
    expect(recorder.key, recorderKey);
    expect(
      ConversationPatternPainter().shouldRepaint(
        ConversationPatternPainter(),
      ),
      isFalse,
    );
  });
}
