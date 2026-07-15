import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/admin/messaging/models/admin_attachment_model.dart';

void main() {
  test('fromData parses complete attachment data', () {
    final createdAt = Timestamp.fromDate(DateTime.utc(2026, 7, 1, 10));
    final deletedAt = Timestamp.fromDate(DateTime.utc(2026, 7, 2, 11));

    final model = AdminAttachmentModel.fromData(
      id: 'attachment-1',
      data: <String, dynamic>{
        'conversationId': 'conversation-1',
        'messageId': 'message-1',
        'senderId': 'sender-1',
        'storagePath': 'messages/file.pdf',
        'fileType': 'document',
        'fileSize': 1234.9,
        'mimeType': 'application/pdf',
        'moderationStatus': 'approved',
        'reportCount': 3.8,
        'createdAt': createdAt,
        'deletedAt': deletedAt,
      },
    );

    expect(model.id, 'attachment-1');
    expect(model.conversationId, 'conversation-1');
    expect(model.messageId, 'message-1');
    expect(model.senderId, 'sender-1');
    expect(model.storagePath, 'messages/file.pdf');
    expect(model.fileType, 'document');
    expect(model.fileSize, 1234);
    expect(model.mimeType, 'application/pdf');
    expect(model.moderationStatus, 'approved');
    expect(model.reportCount, 3);
    expect(model.createdAt?.toUtc(), DateTime.utc(2026, 7, 1, 10));
    expect(model.deletedAt?.toUtc(), DateTime.utc(2026, 7, 2, 11));
  });

  test('fromData parses numeric file size strings', () {
    final model = AdminAttachmentModel.fromData(
      id: 'attachment-2',
      data: <String, dynamic>{'fileSize': '2048'},
    );

    expect(model.fileSize, 2048);
  });

  test('fromData applies defaults for missing and invalid values', () {
    final model = AdminAttachmentModel.fromData(
      id: 'attachment-3',
      data: <String, dynamic>{
        'fileSize': 'invalid',
        'reportCount': '4',
        'createdAt': 'invalid',
        'deletedAt': false,
      },
    );

    expect(model.conversationId, isEmpty);
    expect(model.messageId, isEmpty);
    expect(model.senderId, isEmpty);
    expect(model.storagePath, isEmpty);
    expect(model.fileType, 'other');
    expect(model.fileSize, 0);
    expect(model.mimeType, 'application/octet-stream');
    expect(model.moderationStatus, 'unknown');
    expect(model.reportCount, 0);
    expect(model.createdAt, isNull);
    expect(model.deletedAt, isNull);
  });

  test('fromData stringifies non-string identifiers consistently', () {
    final model = AdminAttachmentModel.fromData(
      id: 'attachment-4',
      data: <String, dynamic>{
        'conversationId': 12,
        'messageId': true,
        'senderId': 42,
        'storagePath': Uri.parse('https://example.test/file'),
        'fileType': 7,
        'mimeType': false,
        'moderationStatus': 9,
      },
    );

    expect(model.conversationId, '12');
    expect(model.messageId, 'true');
    expect(model.senderId, '42');
    expect(model.storagePath, 'https://example.test/file');
    expect(model.fileType, '7');
    expect(model.mimeType, 'false');
    expect(model.moderationStatus, '9');
  });
}
