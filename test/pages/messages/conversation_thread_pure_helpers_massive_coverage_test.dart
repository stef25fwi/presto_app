import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/messages/conversation_thread_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  });

  dynamic createState() => const ConversationThreadPage(
    conversationId: 'conversation-helper',
    offerTitle: 'Peinture salon',
    currentUserId: 'user-current',
  ).createState();

  test('normalise les codes et messages d erreur de messagerie', () {
    final state = createState();

    expect(
      state.messagingErrorCode(
        FirebaseException(plugin: 'firestore', code: 'permission-denied'),
      ),
      'permission-denied',
    );
    expect(
      state.messagingErrorCode(
        FirebaseFunctionsException(code: 'not-found', message: ''),
      ),
      'not-found',
    );
    expect(
      state.messagingErrorCode('Exception: unauthenticated session'),
      'unauthenticated',
    );
    expect(
      state.messagingErrorCode('failed-precondition: blocked'),
      'failed-precondition',
    );
    expect(state.messagingErrorCode('erreur inconnue'), isEmpty);
    expect(state.messagingErrorCode(null), isEmpty);

    final moderationCases = <String, String>{
      'messaging_text_blocked':
          'Le message contient des termes non conformes aux CGU.',
      'messaging_image_blocked':
          'Une image du message ne respecte pas les CGU.',
      'messaging_content_review_required':
          'Le message doit être revu avant de pouvoir être envoyé dans ce mode de modération.',
    };
    for (final entry in moderationCases.entries) {
      expect(
        state.sendMessageErrorMessage(
          FirebaseFunctionsException(
            code: 'invalid-argument',
            message: '',
            details: <String, dynamic>{'reason': entry.key},
          ),
        ),
        entry.value,
      );
    }

    final sendCases = <String, String>{
      'not-found':
          'La conversation n’existe pas encore. Revenez depuis l’annonce pour la créer avant d’envoyer le premier message.',
      'permission-denied':
          'Ouverture de la conversation en cours. Ferme puis rouvre la conversation si le message ne part pas.',
      'unauthenticated': 'Connectez-vous pour envoyer un message.',
      'failed-precondition':
          'L’envoi est indisponible car la conversation est bloquée ou incomplète.',
      'internal': 'L’envoi du message a échoué. Réessayez dans un instant.',
    };
    for (final entry in sendCases.entries) {
      expect(
        state.sendMessageErrorMessage(
          FirebaseFunctionsException(code: entry.key, message: ''),
        ),
        entry.value,
      );
    }

    final subscriptionCases = <String, String>{
      'subscription_document_required':
          'Les documents et autres fichiers sont réservés à ilipresto+.',
      'free_plan_photo_limit_reached':
          'Le plan Gratuit est limité à 1 photo par conversation.',
      'free_plan_audio_limit_reached':
          'Le plan Gratuit est limité à 1 note audio par conversation.',
    };
    for (final entry in subscriptionCases.entries) {
      expect(
        state.attachmentUploadErrorMessage(
          FirebaseFunctionsException(
            code: 'failed-precondition',
            message: '',
            details: <String, dynamic>{'reason': entry.key},
          ),
        ),
        entry.value,
      );
    }

    final uploadCases = <String, String>{
      'unauthenticated': 'Connectez-vous pour envoyer une pièce jointe.',
      'permission-denied': 'Vous n’avez pas accès à cette conversation.',
      'failed-precondition':
          'Cette pièce jointe ne peut pas être envoyée dans l’état actuel de la conversation.',
      'resource-exhausted':
          'Trop d’envois en peu de temps. Réessayez dans un instant.',
      'internal': 'La pièce jointe n’a pas pu être envoyée.',
    };
    for (final entry in uploadCases.entries) {
      expect(
        state.attachmentUploadErrorMessage(
          FirebaseFunctionsException(code: entry.key, message: ''),
        ),
        entry.value,
      );
    }
  });

  test('lit les valeurs de conversation et les sources de profil', () {
    final state = createState();

    expect(
      state.conversationValue(
        <String, dynamic>{'first': null, 'second': 42},
        <String>['missing', 'first', 'second'],
      ),
      42,
    );
    expect(
      state.conversationValue(<String, dynamic>{}, <String>['missing']),
      isNull,
    );

    expect(
      state.readText(
        <String, dynamic>{'name': ' ', 'displayName': ' Alice '},
        <String>['name', 'displayName'],
      ),
      'Alice',
    );
    expect(state.readText(<String, dynamic>{}, <String>['name']), isEmpty);

    expect(
      state.readStringMap(
        <String, dynamic>{
          'names': <dynamic, dynamic>{
            ' user-a ': ' Alice ',
            '': 'vide',
            'user-b': ' ',
            'user-c': 12,
          },
        },
        <String>['missing', 'names'],
      ),
      <String, String>{'user-a': 'Alice', 'user-c': '12'},
    );
    expect(
      state.readStringMap(
        <String, dynamic>{'names': 'invalid'},
        <String>['names'],
      ),
      isEmpty,
    );

    expect(
      state.firstProfilePhotoValue(<String, dynamic>{
        'photoUrl': ' ',
        'avatarURL': ' https://img/a.png ',
      }),
      'https://img/a.png',
    );
    expect(state.firstProfilePhotoValue(<String, dynamic>{}), isEmpty);
    expect(
      state.firstStoredProfilePhotoPath(<String, dynamic>{
        'profilePhotoPath': ' profilePhotos/u/a.webp ',
      }),
      'profilePhotos/u/a.webp',
    );

    expect(state.isResolvableStorageProfilePhoto('gs://bucket/a.webp'), isTrue);
    expect(
      state.isResolvableStorageProfilePhoto('profilePhotos/u/a.webp'),
      isTrue,
    );
    expect(
      state.isResolvableStorageProfilePhoto('https://img/a.webp'),
      isFalse,
    );
    expect(state.isNetworkProfilePhoto(' HTTPS://img/a.webp '), isTrue);
    expect(state.isNetworkProfilePhoto('http://img/a.webp'), isTrue);
    expect(state.isNetworkProfilePhoto('gs://bucket/a.webp'), isFalse);

    expect(
      state.isSameCalendarDay(
        DateTime(2026, 7, 22, 1),
        DateTime(2026, 7, 22, 23),
      ),
      isTrue,
    );
    expect(
      state.isSameCalendarDay(DateTime(2026, 7, 22), DateTime(2026, 7, 23)),
      isFalse,
    );
    expect(state.isSameCalendarDay(null, DateTime(2026, 7, 22)), isFalse);
  });

  test('normalise noms MIME et types de pièces jointes', () {
    final state = createState();

    expect(
      state.safeAttachmentName(' Mon fichier été.pdf ', 'fallback.pdf'),
      'Mon_fichier_t_.pdf',
    );
    expect(state.safeAttachmentName(' ', 'document.pdf'), 'document.pdf');
    expect(state.safeAttachmentName('***', '***'), 'piece-jointe');

    final mimeCases = <String, String>{
      'photo.jpg': 'image/jpeg',
      'photo.JPEG': 'image/jpeg',
      'photo.png': 'image/png',
      'photo.webp': 'image/webp',
      'photo.gif': 'image/gif',
      'audio.mp3': 'audio/mpeg',
      'audio.wav': 'audio/wav',
      'audio.ogg': 'audio/ogg',
      'audio.oga': 'audio/ogg',
      'audio.m4a': 'audio/mp4',
      'audio.aac': 'audio/aac',
      'audio.webm': 'audio/webm',
      'doc.pdf': 'application/pdf',
      'table.csv': 'text/csv',
      'note.txt': 'text/plain',
      'note.rtf': 'application/rtf',
      'doc.doc': 'application/msword',
      'doc.docx':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'doc.odt': 'application/vnd.oasis.opendocument.text',
      'table.xls': 'application/vnd.ms-excel',
      'table.xlsx':
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'slide.ppt': 'application/vnd.ms-powerpoint',
      'slide.pptx':
          'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    };
    for (final entry in mimeCases.entries) {
      expect(
        state.mimeTypeForName(entry.key, 'application/octet-stream'),
        entry.value,
        reason: entry.key,
      );
    }
    expect(
      state.mimeTypeForName('archive.zip', 'application/zip'),
      'application/zip',
    );

    expect(state.attachmentTypeForFile('voice.bin', 'audio/mpeg'), 'audio');
    for (final name in <String>[
      'voice.mp3',
      'voice.wav',
      'voice.ogg',
      'voice.oga',
      'voice.m4a',
      'voice.aac',
      'voice.webm',
    ]) {
      expect(state.attachmentTypeForFile(name, ''), 'audio', reason: name);
    }
    expect(
      state.attachmentTypeForFile('document.pdf', 'application/pdf'),
      'document',
    );
  });

  test('normalise les pièces jointes et leur texte métier', () {
    final state = createState();

    final image = MessageAttachment.fromMap(<String, dynamic>{
      'type': 'image',
      'name': ' ',
      'downloadUrl': 'https://cdn/photo.webp',
      'thumbnailUrl': '',
      'storagePath': 'messages/photo.webp',
      'mimeType': 'image/webp',
      'sizeBytes': '1250',
    });
    expect(image, isNotNull);
    expect(image!.name, 'Photo');
    expect(image.url, 'https://cdn/photo.webp');
    expect(image.thumbnailUrl, 'https://cdn/photo.webp');
    expect(image.sizeBytes, 1250);

    final audio = MessageAttachment.fromMap(<String, dynamic>{
      'type': 'audio',
      'url': 'https://cdn/audio.webm',
      'sizeBytes': 9.6,
    });
    expect(audio, isNotNull);
    expect(audio!.name, 'Note vocale');
    expect(audio.sizeBytes, 10);

    final document = MessageAttachment.fromMap(<String, dynamic>{
      'type': 'document',
      'name': 'devis.pdf',
      'url': 'https://cdn/devis.pdf',
      'storagePath': 'messages/devis.pdf',
      'mimeType': 'application/pdf',
      'sizeBytes': 200,
    });
    expect(document, isNotNull);
    expect(document!.name, 'devis.pdf');

    expect(
      MessageAttachment.fromMap(<String, dynamic>{
        'type': 'video',
        'url': 'https://cdn/video.mp4',
      }),
      isNull,
    );
    expect(
      MessageAttachment.fromMap(<String, dynamic>{'type': 'image', 'url': ' '}),
      isNull,
    );
    expect(MessageAttachment.fromList('invalid'), isEmpty);
    expect(
      MessageAttachment.fromList(<Object?>[
        <String, dynamic>{'type': 'image', 'url': 'https://cdn/a.webp'},
        <String, dynamic>{'type': 'invalid', 'url': 'https://cdn/b'},
        'invalid',
      ]),
      hasLength(1),
    );

    expect(state.attachmentMessageText(image), 'Photo : Photo');
    expect(state.attachmentMessageText(audio), 'Note vocale');
    expect(state.attachmentMessageText(document), 'Document : devis.pdf');
    expect(
      state.shouldHideAttachmentText('Photo : Photo', <MessageAttachment>[
        image,
      ]),
      isTrue,
    );
    expect(
      state.shouldHideAttachmentText('Autre texte', <MessageAttachment>[image]),
      isFalse,
    );
    expect(
      state.shouldHideAttachmentText(
        'Document : devis.pdf',
        <MessageAttachment>[document],
      ),
      isFalse,
    );
    expect(
      state.shouldHideAttachmentText('', <MessageAttachment>[image]),
      isFalse,
    );
    expect(
      state.shouldHideAttachmentText(
        'Photo : Photo',
        const <MessageAttachment>[],
      ),
      isFalse,
    );

    expect(document.toInput().toJson(), <String, dynamic>{
      'type': 'document',
      'name': 'devis.pdf',
      'url': 'https://cdn/devis.pdf',
      'storagePath': 'messages/devis.pdf',
      'mimeType': 'application/pdf',
      'sizeBytes': 200,
    });
  });

  test('applique la modération et les états optimistes', () {
    final none = MessageModeration.fromMap(null);
    expect(none.status, isEmpty);
    expect(none.visibility, 'visible');
    expect(none.shouldHideContent, isFalse);
    expect(none.placeholderText, 'Message modéré');

    final rejected = MessageModeration.fromMap(<String, dynamic>{
      'status': ' Rejected ',
      'visibility': 'visible',
    });
    expect(rejected.shouldHideContent, isTrue);
    expect(rejected.placeholderText, 'Message retiré par la modération');

    final manual = MessageModeration.fromMap(<String, dynamic>{
      'status': 'manual_review',
    });
    expect(manual.shouldHideContent, isTrue);
    expect(manual.placeholderText, 'Message masqué en attente de vérification');

    final pendingHidden = MessageModeration.fromMap(<String, dynamic>{
      'status': 'pending',
      'visibility': 'hidden',
    });
    expect(pendingHidden.shouldHideContent, isTrue);
    expect(pendingHidden.placeholderText, 'Message en cours de vérification');

    final pendingVisible = MessageModeration.fromMap(<String, dynamic>{
      'status': 'pending',
      'visibility': 'visible',
    });
    expect(pendingVisible.shouldHideContent, isFalse);

    final optimistic = OptimisticMessage(
      id: 'local-1',
      text: 'Bonjour',
      sentAt: DateTime(2026, 7, 22, 9),
      senderName: 'Alice',
      status: OptimisticMessageStatus.sending,
    );
    expect(optimistic.copyWith().status, OptimisticMessageStatus.sending);
    final failed = optimistic.copyWith(status: OptimisticMessageStatus.failed);
    expect(failed.id, optimistic.id);
    expect(failed.text, optimistic.text);
    expect(failed.sentAt, optimistic.sentAt);
    expect(failed.senderName, optimistic.senderName);
    expect(failed.status, OptimisticMessageStatus.failed);
  });

  test('construit les aperçus d annonce depuis les formats historiques', () {
    final direct = OfferPreview.fromMap('offer-1', <String, dynamic>{
      'title': ' Peinture salon ',
      'price': 125.5,
      'thumbnailUrl': ' https://cdn/direct.webp ',
    });
    expect(direct.id, 'offer-1');
    expect(direct.title, 'Peinture salon');
    expect(direct.priceLabel, '125.5 €');
    expect(direct.imageUrl, 'https://cdn/direct.webp');

    final legacy = OfferPreview.fromMap('offer-2', <String, dynamic>{
      'listingTitle': 'Montage meuble',
      'budget': '90',
      'imageUrls': <Object?>[' ', 'https://cdn/list.webp'],
    });
    expect(legacy.title, 'Montage meuble');
    expect(legacy.priceLabel, '90 €');
    expect(legacy.imageUrl, 'https://cdn/list.webp');

    final media = OfferPreview.fromMap('offer-3', <String, dynamic>{
      'offerTitle': 'Jardinage',
      'amount': 100,
      'media': <Object?>[
        'invalid',
        <String, dynamic>{'downloadUrl': 'https://cdn/media.webp'},
      ],
    });
    expect(media.priceLabel, '100 €');
    expect(media.imageUrl, 'https://cdn/media.webp');

    final empty = OfferPreview.fromMap('offer-4', <String, dynamic>{
      'price': 0,
      'imageUrls': <Object?>[],
      'media': <Object?>[],
    });
    expect(empty.title, isEmpty);
    expect(empty.priceLabel, isEmpty);
    expect(empty.imageUrl, isEmpty);

    expect(
      OfferPreview.fromMap('offer-5', <String, dynamic>{
        'salary': '75 €',
      }).priceLabel,
      '75 €',
    );
    expect(
      OfferPreview.fromMap('offer-6', <String, dynamic>{
        'dailyRate': ' ',
      }).priceLabel,
      isEmpty,
    );
  });

  test('formate les dates, présences et identités supprimées', () {
    expect(formatMessageTimestamp(null), 'Envoi...');
    expect(formatMessageTimestamp(DateTime(2026, 7, 22, 9, 5)), '22/07 09:05');
    expect(formatThreadDateLabel(null), '--/--/----');

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 12);
    final yesterday = today.subtract(const Duration(days: 1));
    expect(formatThreadDateLabel(today), 'Aujourd’hui');
    expect(formatThreadDateLabel(yesterday), 'Hier');
    expect(formatThreadDateLabel(DateTime(2020, 1, 2, 12)), '02/01/2020');

    expect(
      formatPresenceSeenAt(
        DateTime.now().subtract(const Duration(seconds: 20)),
      ),
      'à l’instant',
    );
    expect(
      formatPresenceSeenAt(DateTime.now().subtract(const Duration(minutes: 5))),
      contains('min'),
    );
    expect(
      formatPresenceSeenAt(DateTime.now().subtract(const Duration(hours: 2))),
      contains('h'),
    );
    expect(
      formatPresenceSeenAt(DateTime.now().subtract(const Duration(days: 1))),
      'hier',
    );
    expect(
      formatPresenceSeenAt(DateTime.now().subtract(const Duration(days: 5))),
      startsWith('le '),
    );

    expect(isDeletedUserMap(null), isTrue);
    expect(isDeletedUserMap(<String, dynamic>{'isDeleted': true}), isTrue);
    expect(isDeletedUserMap(<String, dynamic>{'status': 'removed'}), isTrue);
    expect(isDeletedUserMap(<String, dynamic>{}), isFalse);
    expect(deletedAwareDisplayName(null, 'Alice'), 'Utilisateur n’existe plus');
    expect(deletedAwareDisplayName(<String, dynamic>{}, ' Alice '), 'Alice');
    expect(deletedAwareDisplayName(<String, dynamic>{}, ' '), 'Utilisateur');
  });

  testWidgets('retourne l avatar supprimé ou le fallback actif', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: deletedAwareAvatar(
            data: <String, dynamic>{'accountDeleted': true},
            fallback: const Icon(Icons.person),
            radius: 18,
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.person_off_rounded), findsOneWidget);
    expect(find.byIcon(Icons.person), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: deletedAwareAvatar(
            data: <String, dynamic>{},
            fallback: const Icon(Icons.person),
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.person), findsOneWidget);
    expect(find.byIcon(Icons.person_off_rounded), findsNothing);
  });
}
