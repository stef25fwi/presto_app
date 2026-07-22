import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/models/marketplace_enums.dart';
import 'package:presto_app/models/marketplace_listing_draft.dart';
import 'package:presto_app/models/marketplace_report.dart';

void main() {
  group('ListingMediaInput', () {
    test('sérialise tous les attributs optionnels', () {
      const media = ListingMediaInput(
        storagePath: 'offers/o1/photo.jpg',
        downloadUrl: 'https://cdn.example.com/photo.jpg',
        thumbnailUrl: 'https://cdn.example.com/thumb.jpg',
        width: 1600,
        height: 900,
        mimeType: ' image/jpeg ',
        sizeBytes: 123456,
      );

      expect(media.toMap(), <String, dynamic>{
        'storagePath': 'offers/o1/photo.jpg',
        'downloadUrl': 'https://cdn.example.com/photo.jpg',
        'thumbnailUrl': 'https://cdn.example.com/thumb.jpg',
        'width': 1600,
        'height': 900,
        'mimeType': ' image/jpeg ',
        'sizeBytes': 123456,
      });
    });

    test('omet les attributs absents ou vides', () {
      const media = ListingMediaInput(
        storagePath: 'offers/o1/photo.jpg',
        downloadUrl: 'https://cdn.example.com/photo.jpg',
        thumbnailUrl: 'https://cdn.example.com/thumb.jpg',
        mimeType: '   ',
      );

      expect(media.toMap(), <String, dynamic>{
        'storagePath': 'offers/o1/photo.jpg',
        'downloadUrl': 'https://cdn.example.com/photo.jpg',
        'thumbnailUrl': 'https://cdn.example.com/thumb.jpg',
      });
    });
  });

  group('MarketplaceListingDraft', () {
    test('normalise et sérialise tous les champs optionnels', () {
      const draft = MarketplaceListingDraft(
        id: 'draft-1',
        ownerId: 'user-1',
        title: '  Besoin d aide  ',
        description: '  Description  ',
        price: 80,
        categoryId: ' services ',
        cityId: ' baie-mahault ',
        media: <ListingMediaInput>[],
        status: ListingStatus.pending,
        phone: ' 0690123456 ',
        budgetType: ' forfait ',
        missionDelay: ' urgent ',
        isUrgent: true,
        subCategory: ' bricolage ',
        category: ' services ',
        city: ' Baie-Mahault ',
        location: ' Destrellan ',
        postalCode: ' 97122 ',
        cp: ' 97122 ',
        dept: ' 971 ',
        region: ' Guadeloupe ',
        communeName: ' Baie-Mahault ',
        departmentCode: ' 971 ',
        regionCode: ' GP ',
        locationSource: ' manual ',
        cityCategoryKey: ' baie-mahault_services ',
        budgetValue: 80,
        hidePhone: true,
      );

      expect(draft.toFirestore(), <String, dynamic>{
        'ownerId': 'user-1',
        'title': 'Besoin d aide',
        'description': 'Description',
        'price': 80.0,
        'categoryId': 'services',
        'cityId': 'baie-mahault',
        'media': <Map<String, dynamic>>[],
        'status': 'pending',
        'phone': '0690123456',
        'budgetType': 'forfait',
        'missionDelay': 'urgent',
        'isUrgent': true,
        'subCategory': 'bricolage',
        'category': 'services',
        'city': 'Baie-Mahault',
        'location': 'Destrellan',
        'postalCode': '97122',
        'cp': '97122',
        'dept': '971',
        'region': 'Guadeloupe',
        'communeName': 'Baie-Mahault',
        'departmentCode': '971',
        'regionCode': 'GP',
        'locationSource': 'manual',
        'cityCategoryKey': 'baie-mahault_services',
        'budgetValue': 80.0,
        'hidePhone': true,
      });
    });

    test('omet tous les champs optionnels vides', () {
      const draft = MarketplaceListingDraft(
        ownerId: 'user-1',
        title: 'Titre',
        description: 'Description',
        price: 0,
        categoryId: 'cat',
        cityId: 'city',
        media: <ListingMediaInput>[],
        phone: ' ',
        budgetType: '',
        missionDelay: ' ',
        subCategory: '',
        category: ' ',
        city: '',
        location: ' ',
        postalCode: '',
        cp: ' ',
        dept: '',
        region: ' ',
        communeName: '',
        departmentCode: ' ',
        regionCode: '',
        locationSource: ' ',
        cityCategoryKey: '',
      );

      final map = draft.toFirestore();
      expect(map['status'], 'draft');
      expect(map['isUrgent'], isFalse);
      expect(map.containsKey('phone'), isFalse);
      expect(map.containsKey('budgetType'), isFalse);
      expect(map.containsKey('missionDelay'), isFalse);
      expect(map.containsKey('subCategory'), isFalse);
      expect(map.containsKey('category'), isFalse);
      expect(map.containsKey('city'), isFalse);
      expect(map.containsKey('location'), isFalse);
      expect(map.containsKey('postalCode'), isFalse);
      expect(map.containsKey('cp'), isFalse);
      expect(map.containsKey('dept'), isFalse);
      expect(map.containsKey('region'), isFalse);
      expect(map.containsKey('communeName'), isFalse);
      expect(map.containsKey('departmentCode'), isFalse);
      expect(map.containsKey('regionCode'), isFalse);
      expect(map.containsKey('locationSource'), isFalse);
      expect(map.containsKey('cityCategoryKey'), isFalse);
      expect(map.containsKey('budgetValue'), isFalse);
      expect(map.containsKey('hidePhone'), isFalse);
    });
  });

  group('ListingReportDraft', () {
    test('sérialise une raison et son texte', () {
      const report = ListingReportDraft(
        listingId: 'listing-1',
        reasonCode: ListingReportReasonCode.fraud,
        reasonText: 'Paiement suspect',
      );

      expect(report.toMap(), <String, dynamic>{
        'listingId': 'listing-1',
        'reasonCode': 'fraud',
        'reasonText': 'Paiement suspect',
      });
    });

    test('conserve explicitement un texte null', () {
      const report = ListingReportDraft(
        listingId: 'listing-2',
        reasonCode: ListingReportReasonCode.other,
      );

      expect(report.toMap(), <String, dynamic>{
        'listingId': 'listing-2',
        'reasonCode': 'other',
        'reasonText': null,
      });
    });
  });
}
