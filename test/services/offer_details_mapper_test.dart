import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/offers/offer_details_page.dart';
import 'package:presto_app/services/offer_details_mapper.dart';

void main() {
  group('buildOfferDetailsOffer', () {
    test('maps a complete marketplace listing', () {
      final createdAt = Timestamp.fromDate(DateTime(2026, 8, 7, 10));
      final publishedAt = Timestamp.fromDate(DateTime(2026, 8, 7, 11));
      final offer = buildOfferDetailsOffer(
        offerId: 'offer-1',
        data: <String, dynamic>{
          'title': 'Jardinage',
          'location': 'Les Abymes',
          'postalCode': '97139',
          'category': 'Maison',
          'categoryId': 'maison',
          'cityId': 'les-abymes',
          'description': 'Entretien du jardin',
          'isUrgent': true,
          'budget': 80,
          'createdAt': createdAt,
          'publishedAt': publishedAt,
          'status': 'active',
          'moderationStatus': 'approved',
          'visibility': 'public',
          'mediaProcessingStatus': 'ready',
          'imageUrls': <dynamic>[
            'https://example.test/a.webp',
            <String, dynamic>{'downloadUrl': 'https://example.test/b.webp'},
          ],
          'media': <dynamic>[
            <String, dynamic>{'thumbnailUrl': 'https://example.test/c.webp'},
          ],
          'thumbnailUrl': 'https://example.test/d.webp',
          'userId': 'user-1',
          'userName': 'Alex',
          'verified': true,
          'rating': 4.8,
          'offersCount': 4,
          'reviewsCount': 7,
          'seniorityLabel': 'Membre depuis 2025',
          'avatarUrl': 'https://example.test/avatar.webp',
          'availability': 'Disponible demain',
          'serviceArea': 'Grande-Terre',
          'canTravel': false,
          'schedule': 'Matin',
          'missionDelay': '24 h',
          'paymentMethod': 'À convenir',
          'serviceType': 'Ponctuel',
          'actionType': 'booking',
        },
      );

      expect(offer.id, 'offer-1');
      expect(offer.listingId, 'offer-1');
      expect(offer.title, 'Jardinage');
      expect(offer.price, 80.0);
      expect(offer.city, 'Les Abymes');
      expect(offer.postalCode, '97139');
      expect(offer.isUrgent, isTrue);
      expect(offer.isMarketplace, isTrue);
      expect(offer.imageUrls, containsAll(<String>[
        'https://example.test/a.webp',
        'https://example.test/b.webp',
        'https://example.test/c.webp',
        'https://example.test/d.webp',
      ]));
      expect(offer.advertiser.name, 'Alex');
      expect(offer.advertiser.verified, isTrue);
      expect(offer.practicalInfo.serviceArea, 'Grande-Terre');
      expect(offer.actionType, OfferActionType.booking);
      expect(offer.statusBadges, contains('Urgent'));
      expect(offer.statusBadges, contains('Verifie'));
    });

    test('uses defensive defaults for sparse legacy data', () {
      final offer = buildOfferDetailsOffer(
        offerId: 'legacy',
        data: <String, dynamic>{
          'cp': '97200',
          'city': '',
          'urgent': false,
          'pseudo': '',
          'actionType': 'contact',
          'imageUrl': 'https://example.test/only.webp',
        },
      );

      expect(offer.title, 'Annonce');
      expect(offer.price, 0);
      expect(offer.category, 'Categorie non precisee');
      expect(offer.city, 'Lieu non precise');
      expect(offer.postalCode, '97200');
      expect(offer.shortDescription, contains('Consultez le detail'));
      expect(offer.imageUrls, <String>['https://example.test/only.webp']);
      expect(offer.advertiser.name, 'Annonceur Presto');
      expect(offer.advertiser.offersCount, 1);
      expect(offer.actionType, OfferActionType.contact);
      expect(offer.similarOffers, isEmpty);
    });

    test('deduplicates media URLs and accepts alternate media keys', () {
      final offer = buildOfferDetailsOffer(
        offerId: 'media',
        data: <String, dynamic>{
          'imageUrls': <dynamic>[
            <String, dynamic>{'url': 'https://example.test/shared.webp'},
            'https://example.test/shared.webp',
          ],
          'media': <dynamic>[
            <String, dynamic>{'secureUrl': 'https://example.test/secure.webp'},
            <String, dynamic>{'path': 'storage/listings/media.webp'},
          ],
          'thumbnailUrl': 'https://example.test/shared.webp',
          'ownerId': 'owner',
        },
      );

      expect(offer.imageUrls, <String>[
        'https://example.test/shared.webp',
        'https://example.test/secure.webp',
        'storage/listings/media.webp',
      ]);
      expect(offer.isMarketplace, isTrue);
    });
  });
}
