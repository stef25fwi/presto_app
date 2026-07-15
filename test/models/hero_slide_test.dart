import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/models/hero_slide.dart';

void main() {
  final createdAt = DateTime.utc(2026, 7, 1, 10, 30);
  final updatedAt = DateTime.utc(2026, 7, 2, 11, 45);

  HeroSlide buildSlide({
    String id = 'slide-b',
    int order = 2,
    bool isFirst = false,
  }) {
    return HeroSlide(
      id: id,
      title: 'Titre',
      mediaUrl: 'https://example.com/media.jpg',
      storagePath: 'hero/media.jpg',
      mediaType: 'image',
      durationSeconds: 7,
      order: order,
      isActive: true,
      isFirst: isFirst,
      createdAt: createdAt,
      updatedAt: updatedAt,
      createdBy: 'admin-1',
      scope: 'regional',
      targetRegions: const ['GP', 'MQ'],
    );
  }

  test('fromMap normalise les valeurs et les régions', () {
    final slide = HeroSlide.fromMap('slide-1', <String, dynamic>{
      'title': '  Bienvenue  ',
      'mediaUrl': ' https://example.com/hero.mp4 ',
      'storagePath': ' hero/hero.mp4 ',
      'mediaType': ' VIDEO ',
      'durationSeconds': 8.9,
      'order': '12',
      'isActive': 'false',
      'isFirst': true,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt.toIso8601String(),
      'createdBy': ' admin-2 ',
      'scope': 'regional',
      'targetRegions': <dynamic>[' GP ', '', 'MQ', 971],
    });

    expect(slide.id, 'slide-1');
    expect(slide.title, 'Bienvenue');
    expect(slide.mediaUrl, 'https://example.com/hero.mp4');
    expect(slide.storagePath, 'hero/hero.mp4');
    expect(slide.mediaType, 'video');
    expect(slide.isVideo, isTrue);
    expect(slide.isImage, isFalse);
    expect(slide.durationSeconds, 8);
    expect(slide.order, 12);
    expect(slide.isActive, isFalse);
    expect(slide.isFirst, isTrue);
    expect(slide.createdAt?.millisecondsSinceEpoch, createdAt.millisecondsSinceEpoch);
    expect(slide.updatedAt?.millisecondsSinceEpoch, updatedAt.millisecondsSinceEpoch);
    expect(slide.createdBy, 'admin-2');
    expect(slide.isRegional, isTrue);
    expect(slide.isGlobal, isFalse);
    expect(slide.targetRegions, <String>['GP', 'MQ', '971']);
  });

  test('fromMap applique tous les fallbacks sûrs', () {
    final slide = HeroSlide.fromMap('fallback', <String, dynamic>{
      'mediaType': 'unknown',
      'durationSeconds': 'incorrect',
      'order': null,
      'isActive': 'incorrect',
      'isFirst': 'false',
      'createdAt': 'date-invalide',
      'createdBy': '   ',
      'scope': 'local',
    });

    expect(slide.title, isEmpty);
    expect(slide.mediaType, 'image');
    expect(slide.isImage, isTrue);
    expect(slide.durationSeconds, 5);
    expect(slide.order, 0);
    expect(slide.isActive, isTrue);
    expect(slide.isFirst, isFalse);
    expect(slide.createdAt, isNull);
    expect(slide.updatedAt, isNull);
    expect(slide.createdBy, isNull);
    expect(slide.scope, 'global');
    expect(slide.isGlobal, isTrue);
    expect(slide.targetRegions, isEmpty);
  });

  test('toMap et toJson sérialisent dates et champs', () {
    final slide = buildSlide();

    final map = slide.toMap();
    expect(map['id'], 'slide-b');
    expect(map['createdAt'], isA<Timestamp>());
    expect(
      (map['createdAt'] as Timestamp).toDate().millisecondsSinceEpoch,
      createdAt.millisecondsSinceEpoch,
    );
    expect(
      (map['updatedAt'] as Timestamp).toDate().millisecondsSinceEpoch,
      updatedAt.millisecondsSinceEpoch,
    );
    expect(map['targetRegions'], <String>['GP', 'MQ']);

    final json = slide.toJson();
    expect(json['createdAt'], createdAt.toIso8601String());
    expect(json['updatedAt'], updatedAt.toIso8601String());
    expect(json['scope'], 'regional');

    final withoutDates = HeroSlide(
      id: 'empty',
      title: '',
      mediaUrl: '',
      storagePath: '',
      mediaType: 'image',
      durationSeconds: 5,
      order: 0,
      isActive: false,
      isFirst: false,
      createdAt: null,
      updatedAt: null,
      createdBy: null,
    );
    expect(withoutDates.toMap()['createdAt'], isNull);
    expect(withoutDates.toJson()['updatedAt'], isNull);
  });

  test('copyWith remplace les valeurs demandées et conserve les autres', () {
    final original = buildSlide();
    final replacementDate = DateTime.utc(2026, 8, 1);

    final copied = original.copyWith(
      id: 'slide-c',
      title: 'Nouveau',
      mediaUrl: 'https://example.com/new.png',
      storagePath: 'hero/new.png',
      mediaType: 'video',
      durationSeconds: 10,
      order: 4,
      isActive: false,
      isFirst: true,
      createdAt: replacementDate,
      updatedAt: replacementDate,
      createdBy: 'admin-3',
      scope: 'global',
      targetRegions: const ['GF'],
    );

    expect(copied.id, 'slide-c');
    expect(copied.title, 'Nouveau');
    expect(copied.mediaUrl, 'https://example.com/new.png');
    expect(copied.storagePath, 'hero/new.png');
    expect(copied.mediaType, 'video');
    expect(copied.durationSeconds, 10);
    expect(copied.order, 4);
    expect(copied.isActive, isFalse);
    expect(copied.isFirst, isTrue);
    expect(copied.createdAt, replacementDate);
    expect(copied.updatedAt, replacementDate);
    expect(copied.createdBy, 'admin-3');
    expect(copied.scope, 'global');
    expect(copied.targetRegions, <String>['GF']);

    final unchanged = original.copyWith();
    expect(unchanged.toJson(), original.toJson());
  });

  test('compareDisplayOrder privilégie first puis order puis id', () {
    final slides = <HeroSlide>[
      buildSlide(id: 'b', order: 1),
      buildSlide(id: 'a', order: 1),
      buildSlide(id: 'z', order: 99, isFirst: true),
      buildSlide(id: 'c', order: 0),
    ]..sort(HeroSlide.compareDisplayOrder);

    expect(slides.map((slide) => slide.id), <String>['z', 'c', 'a', 'b']);
  });
}
