import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/ad_placeholder_image_service.dart';

void main() {
  test('fromDoc maps complete payload including timestamps', () async {
    final firestore = FakeFirebaseFirestore();
    final createdAt = DateTime.utc(2026, 7, 29, 3);
    final updatedAt = DateTime.utc(2026, 7, 29, 4);
    await firestore.collection('ad_placeholder_images').doc('hero-1').set({
      'imageUrl': 'https://cdn.example.test/hero.webp',
      'storagePath': 'ad_placeholders/home/hero.webp',
      'isVisible': true,
      'target': 'home',
      'sortOrder': 12,
      'title': 'Titre',
      'description': 'Description',
      'linkUrl': 'https://example.test',
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    });

    final doc = await firestore
        .collection('ad_placeholder_images')
        .doc('hero-1')
        .get();
    final image = AdPlaceholderImage.fromDoc(doc);

    expect(image.id, 'hero-1');
    expect(image.imageUrl, 'https://cdn.example.test/hero.webp');
    expect(image.storagePath, 'ad_placeholders/home/hero.webp');
    expect(image.isVisible, isTrue);
    expect(image.target, 'home');
    expect(image.sortOrder, 12);
    expect(image.title, 'Titre');
    expect(image.description, 'Description');
    expect(image.linkUrl, 'https://example.test');
    expect(image.createdAt?.toDate(), createdAt);
    expect(image.updatedAt?.toDate(), updatedAt);
  });

  test('fromDoc applies safe defaults to empty and malformed payload', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('ad_placeholder_images').doc('empty').set({
      'sortOrder': 'invalid',
      'title': '',
      'description': '',
      'linkUrl': '',
      'createdAt': 'invalid',
      'updatedAt': 42,
    });

    final doc = await firestore
        .collection('ad_placeholder_images')
        .doc('empty')
        .get();
    final image = AdPlaceholderImage.fromDoc(doc);

    expect(image.imageUrl, isEmpty);
    expect(image.storagePath, isEmpty);
    expect(image.isVisible, isFalse);
    expect(image.target, 'consult_offers');
    expect(image.sortOrder, 0);
    expect(image.title, isNull);
    expect(image.description, isNull);
    expect(image.linkUrl, isNull);
    expect(image.createdAt, isNull);
    expect(image.updatedAt, isNull);
  });

  test('public recommendations remain production-safe', () {
    expect(AdPlaceholderImageService.recommendedWidthPx, 1920);
    expect(AdPlaceholderImageService.recommendedMinWidthPx, 1600);
    expect(AdPlaceholderImageService.recommendedHeight16x9Px, 1080);
    expect(AdPlaceholderImageService.recommendedMaxWeightKb, 450);
  });
}
