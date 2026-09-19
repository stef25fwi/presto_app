import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/models/hero_slide.dart';
import 'package:presto_app/widgets/public_prelaunch_hero_slider.dart';

void main() {
  Future<void> pumpHero(
    WidgetTester tester,
    Stream<List<HeroSlide>> stream, {
    double width = 390,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
            child: PublicPrelaunchHeroSlider(slidesStream: stream),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('reste invisible lorsqu aucun slide actif n est publié',
      (tester) async {
    await pumpHero(tester, Stream.value(const <HeroSlide>[]));

    expect(find.byType(PageView), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ignore un slide désactivé ou sans média', (tester) async {
    const disabled = HeroSlide(
      id: 'disabled',
      title: 'Désactivé',
      mediaUrl: 'https://example.com/disabled.jpg',
      storagePath: 'hero_slides/disabled.jpg',
      mediaType: 'image',
      durationSeconds: 5,
      order: 0,
      isActive: false,
      isFirst: true,
      createdAt: null,
      updatedAt: null,
      createdBy: null,
    );
    const empty = HeroSlide(
      id: 'empty',
      title: 'Sans média',
      mediaUrl: '',
      storagePath: '',
      mediaType: 'image',
      durationSeconds: 5,
      order: 1,
      isActive: true,
      isFirst: false,
      createdAt: null,
      updatedAt: null,
      createdBy: null,
    );

    await pumpHero(tester, Stream.value(const <HeroSlide>[disabled, empty]));

    expect(find.byType(PageView), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('affiche et ordonne les médias actifs selon la configuration Hero',
      (tester) async {
    const second = HeroSlide(
      id: 'second',
      title: 'Second',
      mediaUrl: 'https://example.com/second.jpg',
      storagePath: 'hero_slides/second.jpg',
      mediaType: 'image',
      durationSeconds: 7,
      order: 2,
      isActive: true,
      isFirst: false,
      createdAt: null,
      updatedAt: null,
      createdBy: null,
      focalX: 0.25,
      focalY: 0.75,
    );
    const first = HeroSlide(
      id: 'first',
      title: 'Premier',
      mediaUrl: 'https://example.com/first.jpg',
      storagePath: 'hero_slides/first.jpg',
      mediaType: 'image',
      durationSeconds: 5,
      order: 9,
      isActive: true,
      isFirst: true,
      createdAt: null,
      updatedAt: null,
      createdBy: null,
    );

    await pumpHero(tester, Stream.value(const <HeroSlide>[second, first]));

    expect(find.byType(PageView), findsOneWidget);
    expect(find.byType(AnimatedContainer), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('adapte la hauteur du Hero sur mobile', (tester) async {
    const slide = HeroSlide(
      id: 'mobile',
      title: 'Mobile',
      mediaUrl: 'https://example.com/mobile.jpg',
      storagePath: 'hero_slides/mobile.jpg',
      mediaType: 'image',
      durationSeconds: 5,
      order: 0,
      isActive: true,
      isFirst: true,
      createdAt: null,
      updatedAt: null,
      createdBy: null,
    );

    await pumpHero(tester, Stream.value(const <HeroSlide>[slide]), width: 320);

    final pageView = find.byType(PageView);
    expect(pageView, findsOneWidget);
    expect(tester.getSize(pageView).height, closeTo(192, 0.1));
    expect(tester.takeException(), isNull);
  });
}
