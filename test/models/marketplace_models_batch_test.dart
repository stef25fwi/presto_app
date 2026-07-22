import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/models/marketplace_enums.dart';
import 'package:presto_app/models/marketplace_listing_draft.dart';
import 'package:presto_app/models/marketplace_report.dart';

void main() {
  group('marketplace enums', () {
    test('sérialise et parse tous les statuts d annonce', () {
      const expected = <ListingStatus, String>{
        ListingStatus.draft: 'draft',
        ListingStatus.pending: 'pending',
        ListingStatus.active: 'active',
        ListingStatus.rejected: 'rejected',
        ListingStatus.archived: 'archived',
        ListingStatus.sold: 'sold',
        ListingStatus.deleted: 'deleted',
      };

      for (final entry in expected.entries) {
        expect(entry.key.value, entry.value);
        expect(ListingStatusParsing.fromString(' ${entry.value} '), entry.key);
      }
      expect(ListingStatusParsing.fromString('unknown'), ListingStatus.draft);
    });

    test('sérialise et parse tous les statuts de modération', () {
      const expected = <ModerationStatus, String>{
        ModerationStatus.pending: 'pending',
        ModerationStatus.autoFlagged: 'auto_flagged',
        ModerationStatus.approved: 'approved',
        ModerationStatus.rejected: 'rejected',
        ModerationStatus.manualReview: 'manual_review',
        ModerationStatus.blocked: 'blocked',
      };

      for (final entry in expected.entries) {
        expect(entry.key.value, entry.value);
        expect(ModerationStatusParsing.fromString(entry.value), entry.key);
      }
      expect(
        ModerationStatusParsing.fromString('unsupported'),
        ModerationStatus.pending,
      );
    });

    test('sérialise et parse toutes les visibilités', () {
      const expected = <ListingVisibility, String>{
        ListingVisibility.private: 'private',
        ListingVisibility.public: 'public',
        ListingVisibility.hidden: 'hidden',
      };

      for (final entry in expected.entries) {
        expect(entry.key.value, entry.value);
        expect(ListingVisibilityParsing.fromString(entry.value), entry.key);
      }
      expect(
        ListingVisibilityParsing.fromString('unsupported'),
        ListingVisibility.private,
      );
    });

    test('sérialise toutes les raisons de signalement', () {
      const expected = <ListingReportReasonCode, String>{
        ListingReportReasonCode.spam: 'spam',
        ListingReportReasonCode.fraud: 'fraud',
        ListingReportReasonCode.inappropriate: 'inappropriate',
        ListingReportReasonCode.duplicate: 'duplicate',
        ListingReportReasonCode.wrongCategory: 'wrong_category',
        ListingReportReasonCode.fakeListing: 'fake_listing',
        ListingReportReasonCode.harassment: 'harassment',
        ListingReportReasonCode.other: 'other',
      };

      for (final entry in expected.entries) {
        expect(entry.key.value, entry.value);
      }
    });
  });

  group('listing media and draft', () {
    test('sérialise tous les attributs média optionnels', () {
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

    test('omet les attributs média absents ou vides', () {
      const media = ListingMediaInput(
        storagePath: 'offers/o1/photo.jpg',
        downloadUrl: 'https://cdn.example.com/photo.jpg',
        thumbnailUrl: 'https://cdn.example.com/thumb.jpg',
        mimeType: '   ',
      );

      expect(media.toMap().keys, <String>[
        'storagePath',
        'downloadUrl',
        'thumbnailUrl',
      ]);
    });

    test('sérialise et normalise tous les champs optionnels du brouillon', () {
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

    test('omet les champs optionnels vides du brouillon', () {
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
      expect(map, containsPair('status', 'draft'));
      expect(map, containsPair('isUrgent', false));
      expect(map, isNot(contains('phone')));
      expect(map, isNot(contains('budgetType')));
      expect(map, isNot(contains('location')));
      expect(map, isNot(contains('hidePhone')));
    });
  });

  group('listing report draft', () {
    test('sérialise la raison et le texte', () {
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

    test('conserve un texte de raison null', () {
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
