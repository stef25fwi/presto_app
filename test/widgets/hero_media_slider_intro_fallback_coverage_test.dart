import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/models/hero_slide.dart';
import 'package:presto_app/widgets/hero_media_slider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    try {
      await Firebase.initializeApp();
    } on FirebaseException catch (error) {
      if (error.code != 'duplicate-app') rethrow;
    }
  });

  Future<void> pumpSlider(
    WidgetTester tester, {
    required double width,
    List<HeroSlide> slides = const <HeroSlide>[],
    Key? sliderKey,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            child: HeroMediaSlider(
              key: sliderKey,
              slides: slides,
              fallback: const ColoredBox(
                key: ValueKey<String>('hero-fallback'),
                color: Colors.blue,
                child: Center(child: Text('Fallback Hero')),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('affiche l intro SEO puis le fallback après neuf secondes',
      (tester) async {
    await pumpSlider(tester, width: 390);

    expect(
      find.text('La solution à tout moment pour tous vos besoins du quotidien'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Publiez une annonce assistée par IA'),
      findsOneWidget,
    );
    expect(find.textContaining('0 % de commission'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('hero-fallback')), findsNothing);

    final initialSize = tester.getSize(find.byType(HeroMediaSlider));
    expect(initialSize.width, 390);
    expect(initialSize.height, closeTo(210.6, 0.1));

    await tester.pump(const Duration(seconds: 8, milliseconds: 999));
    expect(find.text('Fallback Hero'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(
      find.text('La solution à tout moment pour tous vos besoins du quotidien'),
      findsNothing,
    );
    expect(find.text('Fallback Hero'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('couvre les hauteurs responsive mobile étroit et desktop',
      (tester) async {
    await pumpSlider(tester, width: 320);
    var size = tester.getSize(find.byType(HeroMediaSlider));
    expect(size.width, 320);
    expect(size.height, closeTo(198.4, 0.1));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    await pumpSlider(tester, width: 900);
    size = tester.getSize(find.byType(HeroMediaSlider));
    expect(size.width, 900);
    expect(size.height, closeTo(342, 0.1));

    await tester.pump(const Duration(seconds: 9));
    await tester.pump();
    expect(find.text('Fallback Hero'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('réagit à une mise à jour des slides sans média exploitable',
      (tester) async {
    const sliderKey = ValueKey<String>('stable-slider');
    await pumpSlider(tester, width: 600, sliderKey: sliderKey);

    await tester.pump(const Duration(seconds: 9));
    await tester.pump();
    expect(find.text('Fallback Hero'), findsOneWidget);

    const emptyMediaSlide = HeroSlide(
      id: 'empty-media-slide',
      title: 'Slide sans média',
      mediaUrl: '',
      storagePath: '',
      mediaType: 'image',
      durationSeconds: 5,
      order: 0,
      isActive: true,
      isFirst: true,
      createdAt: null,
      updatedAt: null,
      createdBy: null,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 600,
            child: HeroMediaSlider(
              key: sliderKey,
              slides: <HeroSlide>[emptyMediaSlide],
              fallback: ColoredBox(
                key: ValueKey<String>('hero-fallback'),
                color: Colors.blue,
                child: Center(child: Text('Fallback Hero')),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Fallback Hero'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
