import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/utils/offer_helpers.dart';

void main() {
  group('normalisation et motif de suppression', () {
    test('normalise espaces, apostrophes et accents', () {
      expect(
        normalizeOfferDeletionReason(
          '  J’AI déjà trouvé   quelqu’un À côté d’iliPrestō  ',
        ),
        "j'ai deja trouve quelqu'un a cote d'ilipresto",
      );
      expect(
        normalizeOfferDeletionReason('Çà mêlÉ Île Ôté Ùne'),
        'ca mele ile ote une',
      );
    });

    test('reconnaît les deux motifs de mission terminée', () {
      expect(
        isOfferJobDoneDeletionReason(
          'J’ai trouvé quelqu’un grâce à iliprestō',
        ),
        isTrue,
      );
      expect(
        isOfferJobDoneDeletionReason('J’ai déjà trouvé un prestataire'),
        isTrue,
      );
      expect(isOfferJobDoneDeletionReason('Annonce en doublon'), isFalse);
      expect(isOfferJobDoneDeletionReason(null), isFalse);
    });
  });

  group('conversion des dates et échéance overlay', () {
    test('convertit Timestamp, DateTime, millisecondes et texte ISO', () {
      final date = DateTime.utc(2026, 7, 16, 9, 30);
      final timestampResult = offerDateTimeFromDynamic(Timestamp.fromDate(date));
      expect(timestampResult?.millisecondsSinceEpoch, date.millisecondsSinceEpoch);
      expect(offerDateTimeFromDynamic(date), same(date));
      expect(
        offerDateTimeFromDynamic(date.millisecondsSinceEpoch),
        DateTime.fromMillisecondsSinceEpoch(date.millisecondsSinceEpoch),
      );
      expect(
        offerDateTimeFromDynamic(date.toIso8601String()),
        DateTime.parse(date.toIso8601String()),
      );
      expect(offerDateTimeFromDynamic('date invalide'), isNull);
      expect(offerDateTimeFromDynamic(3.14), isNull);
      expect(offerDateTimeFromDynamic(null), isNull);
    });

    test('utilise les trois clés historiques par ordre de priorité', () {
      final first = DateTime.utc(2026, 7, 20);
      final second = DateTime.utc(2026, 7, 21);
      final third = DateTime.utc(2026, 7, 22);

      expect(
        offerJobDoneVisibleUntil(<String, dynamic>{
          'jobDoneOverlayVisibleUntil': first,
          'removeFromBrowseAt': second,
          'pendingScreenRemovalUntil': third,
        }),
        first,
      );
      expect(
        offerJobDoneVisibleUntil(<String, dynamic>{
          'removeFromBrowseAt': second,
          'pendingScreenRemovalUntil': third,
        }),
        second,
      );
      expect(
        offerJobDoneVisibleUntil(<String, dynamic>{
          'pendingScreenRemovalUntil': third,
        }),
        third,
      );
      expect(offerJobDoneVisibleUntil(<String, dynamic>{}), isNull);
    });
  });

  group('archivage et visibilité de l overlay', () {
    test('reconnaît tous les statuts archivés et les dates de suppression', () {
      for (final status in <String>[
        'archived',
        'ARCHIVÉ',
        'deleted',
        'removed',
        'sold',
      ]) {
        expect(isOfferArchivedLike(<String, dynamic>{'status': status}), isTrue);
      }
      expect(
        isOfferArchivedLike(<String, dynamic>{'archivedAt': DateTime.now()}),
        isTrue,
      );
      expect(
        isOfferArchivedLike(<String, dynamic>{'deletedAt': Timestamp.now()}),
        isTrue,
      );
      expect(
        isOfferArchivedLike(<String, dynamic>{'status': 'active'}),
        isFalse,
      );
    });

    test('refuse un overlay expiré, absent ou explicitement masqué', () {
      expect(isOfferJobDoneOverlayVisible(<String, dynamic>{}), isFalse);
      expect(
        isOfferJobDoneOverlayVisible(<String, dynamic>{
          'jobDoneOverlayVisibleUntil':
              DateTime.now().subtract(const Duration(minutes: 1)),
          'jobDoneOverlayVisible': true,
        }),
        isFalse,
      );
      expect(
        isOfferJobDoneOverlayVisible(<String, dynamic>{
          'jobDoneOverlayVisibleUntil':
              DateTime.now().add(const Duration(hours: 1)),
          'jobDoneOverlayVisible': false,
          'deletedReason': 'J’ai trouvé quelqu’un sur iliprestō',
        }),
        isFalse,
      );
    });

    test('affiche l overlay par flag ou motif reconnu', () {
      final future = DateTime.now().add(const Duration(hours: 2));
      expect(
        isOfferJobDoneOverlayVisible(<String, dynamic>{
          'jobDoneOverlayVisibleUntil': future,
          'jobDoneOverlayVisible': true,
          'deletedReason': 'autre motif',
        }),
        isTrue,
      );
      expect(
        isOfferJobDoneOverlayVisible(<String, dynamic>{
          'jobDoneOverlayVisibleUntil': future,
          'archiveReason': 'Déjà trouvé un prestataire',
        }),
        isTrue,
      );
      expect(
        isOfferJobDoneOverlayVisible(<String, dynamic>{
          'jobDoneOverlayVisibleUntil': future,
          'archiveReason': 'Annonce en doublon',
        }),
        isFalse,
      );
    });
  });

  group('publication et navigation publique', () {
    test('refuse toujours une offre archivée', () {
      expect(
        isPublishedOfferData(<String, dynamic>{
          'status': 'archived',
          'isPublished': true,
          'isActive': true,
        }),
        isFalse,
      );
    });

    test('accepte les contrats actifs, publiés et legacy', () {
      expect(
        isPublishedOfferData(<String, dynamic>{'status': 'active'}),
        isTrue,
      );
      expect(
        isPublishedOfferData(<String, dynamic>{'status': 'PUBLISHED'}),
        isTrue,
      );
      expect(
        isPublishedOfferData(<String, dynamic>{'isPublished': true}),
        isTrue,
      );
      expect(
        isPublishedOfferData(<String, dynamic>{'isActive': true}),
        isTrue,
      );
      expect(
        isPublishedOfferData(<String, dynamic>{
          'visibility': <String, dynamic>{'isPublic': true},
        }),
        isTrue,
      );
      expect(
        isPublishedOfferData(<String, dynamic>{
          'status': 'draft',
          'visibility': <String, dynamic>{'isPublic': false},
        }),
        isFalse,
      );
      expect(
        isPublishedOfferData(<String, dynamic>{'visibility': 'public'}),
        isFalse,
      );
    });

    test('l overlay reste visible avant les règles modernes', () {
      expect(
        isVisibleInPublicBrowse(
          <String, dynamic>{
            'status': 'archived',
            'visibility': 'private',
            'jobDoneOverlayVisibleUntil':
                DateTime.now().add(const Duration(hours: 1)),
            'jobDoneOverlayVisible': true,
          },
          preferModernListingContract: true,
        ),
        isTrue,
      );
    });

    test('applique strictement le contrat moderne', () {
      expect(
        isVisibleInPublicBrowse(
          <String, dynamic>{'status': 'active', 'visibility': 'public'},
          preferModernListingContract: true,
        ),
        isTrue,
      );
      expect(
        isVisibleInPublicBrowse(
          <String, dynamic>{'status': 'active', 'visibility': 'private'},
          preferModernListingContract: true,
        ),
        isFalse,
      );
      expect(
        isVisibleInPublicBrowse(
          <String, dynamic>{'status': 'archived', 'visibility': 'public'},
          preferModernListingContract: true,
        ),
        isFalse,
      );
      expect(
        isVisibleInPublicBrowse(
          <String, dynamic>{'status': 'published', 'visibility': 'public'},
          preferModernListingContract: true,
        ),
        isFalse,
      );
    });

    test('conserve les règles legacy par défaut', () {
      expect(
        isVisibleInPublicBrowse(<String, dynamic>{'status': 'active'}),
        isTrue,
      );
      expect(
        isVisibleInPublicBrowse(<String, dynamic>{'isActive': true}),
        isTrue,
      );
      expect(
        isVisibleInPublicBrowse(<String, dynamic>{'status': 'draft'}),
        isFalse,
      );
    });
  });

  group('libellé de publication', () {
    test('formate les minutes, heures et jours récents', () {
      expect(
        offerDetailsPublishedLabel(
          Timestamp.fromDate(
            DateTime.now().subtract(const Duration(seconds: 20)),
          ),
        ),
        'Publiee a l\'instant',
      );
      expect(
        offerDetailsPublishedLabel(
          Timestamp.fromDate(
            DateTime.now().subtract(const Duration(minutes: 12)),
          ),
        ),
        contains('12 min'),
      );
      expect(
        offerDetailsPublishedLabel(
          Timestamp.fromDate(
            DateTime.now().subtract(const Duration(hours: 3)),
          ),
        ),
        contains('3 h'),
      );
      expect(
        offerDetailsPublishedLabel(
          Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 4)),
          ),
        ),
        contains('4 j'),
      );
    });

    test('retourne le repli pour une date ancienne ou un autre type', () {
      expect(
        offerDetailsPublishedLabel(
          Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 8)),
          ),
        ),
        'Publication recente',
      );
      expect(offerDetailsPublishedLabel(DateTime.now()), 'Publication recente');
      expect(offerDetailsPublishedLabel(null), 'Publication recente');
    });
  });

  group('extraction de l image', () {
    test('retourne vide pour null ou une map sans valeur', () {
      expect(extractOfferImageUrl(null), isEmpty);
      expect(extractOfferImageUrl(<String, dynamic>{}), isEmpty);
      expect(
        extractOfferImageUrl(<String, dynamic>{
          'downloadUrl': '   ',
          'thumbnailUrl': null,
        }),
        isEmpty,
      );
    });

    test('accepte chaque clé connue et respecte leur priorité', () {
      const keys = <String>[
        'downloadUrl',
        'thumbnailUrl',
        'imageUrl',
        'photoUrl',
        'url',
        'secureUrl',
        'src',
        'storagePath',
        'filePath',
        'path',
      ];
      for (final key in keys) {
        expect(
          extractOfferImageUrl(<String, dynamic>{key: '  valeur-$key  '}),
          'valeur-$key',
        );
      }
      expect(
        extractOfferImageUrl(<String, dynamic>{
          'downloadUrl': 'premiere',
          'thumbnailUrl': 'seconde',
        }),
        'premiere',
      );
    });

    test('convertit et nettoie une valeur non map', () {
      expect(
        extractOfferImageUrl('  https://image.test/photo.jpg  '),
        'https://image.test/photo.jpg',
      );
      expect(extractOfferImageUrl(123), '123');
    });
  });
}
