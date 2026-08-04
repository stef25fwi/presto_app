import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/ad_placeholder_image_service.dart';
import 'package:presto_app/widgets/managed_ad_placeholder_ticker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ManagedAdPlaceholderTicker', () {
    testWidgets('reste invisible sans image distante ni fallback', (tester) async {
      await tester.pumpWidget(
        _host(
          ManagedAdPlaceholderTicker(
            fallbackFolderPrefix: 'assets/empty',
            borderRadius: BorderRadius.circular(12),
            enabled: true,
            watchVisible: ({required target}) => const Stream.empty(),
            loadFallbackAssets: (_) async => <String>[],
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Image), findsNothing);
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('affiche et fait tourner les fallbacks locaux', (tester) async {
      final provider = MemoryImage(_pixelPng);

      await tester.pumpWidget(
        _host(
          ManagedAdPlaceholderTicker(
            fallbackFolderPrefix: 'assets/banners',
            borderRadius: BorderRadius.circular(18),
            enabled: true,
            interval: const Duration(milliseconds: 10),
            antiRepeatWindow: 1,
            watchVisible: ({required target}) => const Stream.empty(),
            loadFallbackAssets: (_) async => <String>[
              'assets/banners/a.png',
              'assets/banners/b.webp',
              'assets/banners/c.jpg',
            ],
            assetImageProviderBuilder: (_) => provider,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const ValueKey('asset:assets/banners/a.png')), findsOneWidget);
      expect(find.byType(ClipRRect), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 11));
      expect(find.byKey(const ValueKey('asset:assets/banners/b.webp')), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 11));
      expect(find.byKey(const ValueKey('asset:assets/banners/c.jpg')), findsOneWidget);
    });

    testWidgets('les images distantes valides remplacent le fallback', (tester) async {
      final remote = StreamController<List<AdPlaceholderImage>>();
      addTearDown(remote.close);
      final provider = MemoryImage(_pixelPng);

      await tester.pumpWidget(
        _host(
          ManagedAdPlaceholderTicker(
            fallbackFolderPrefix: 'assets/fallback',
            borderRadius: BorderRadius.zero,
            enabled: false,
            watchVisible: ({required target}) => remote.stream,
            loadFallbackAssets: (_) async => <String>['assets/fallback/a.png'],
            assetImageProviderBuilder: (_) => provider,
            networkImageProviderBuilder: (_) => provider,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const ValueKey('asset:assets/fallback/a.png')), findsOneWidget);

      remote.add(<AdPlaceholderImage>[
        _image('blank', '   '),
        _image('first', ' https://cdn.example/first.png '),
        _image('second', 'https://cdn.example/second.png'),
      ]);
      await tester.pump();

      final switcher = tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher));
      expect(
        switcher.child?.key,
        const ValueKey('network:https://cdn.example/first.png'),
      );
      expect(
        find.byKey(const ValueKey('network:https://cdn.example/first.png')),
        findsOneWidget,
      );
    });

    testWidgets('désactivation et changement intervalle pilotent la rotation',
        (tester) async {
      final provider = MemoryImage(_pixelPng);
      var enabled = false;
      var interval = const Duration(milliseconds: 10);
      late StateSetter rebuild;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return _host(
              ManagedAdPlaceholderTicker(
                fallbackFolderPrefix: 'assets/rotation',
                borderRadius: BorderRadius.zero,
                enabled: enabled,
                interval: interval,
                watchVisible: ({required target}) => const Stream.empty(),
                loadFallbackAssets: (_) async => <String>[
                  'assets/rotation/a.png',
                  'assets/rotation/b.png',
                ],
                assetImageProviderBuilder: (_) => provider,
              ),
            );
          },
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 20));
      expect(find.byKey(const ValueKey('asset:assets/rotation/a.png')), findsOneWidget);

      rebuild(() {
        enabled = true;
        interval = const Duration(milliseconds: 5);
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 6));

      expect(find.byKey(const ValueKey('asset:assets/rotation/b.png')), findsOneWidget);
    });

    testWidgets('recharge la cible distante et le dossier fallback', (tester) async {
      final provider = MemoryImage(_pixelPng);
      final watchedTargets = <String>[];
      final loadedPrefixes = <String>[];
      var target = 'offers';
      var prefix = 'assets/one';
      late StateSetter rebuild;

      Stream<List<AdPlaceholderImage>> watcher({required String target}) {
        watchedTargets.add(target);
        return const Stream.empty();
      }

      Future<List<String>> loader(String value) async {
        loadedPrefixes.add(value);
        return <String>['$value/banner.png'];
      }

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return _host(
              ManagedAdPlaceholderTicker(
                fallbackFolderPrefix: prefix,
                borderRadius: BorderRadius.circular(4),
                enabled: false,
                target: target,
                watchVisible: watcher,
                loadFallbackAssets: loader,
                assetImageProviderBuilder: (_) => provider,
              ),
            );
          },
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(watchedTargets, <String>['offers']);
      expect(loadedPrefixes, <String>['assets/one']);

      rebuild(() {
        target = 'services';
        prefix = 'assets/two/';
      });
      await tester.pump();
      await tester.pump();

      expect(watchedTargets, <String>['offers', 'services']);
      expect(loadedPrefixes, <String>['assets/one', 'assets/two/']);
      expect(
        find.byKey(const ValueKey('asset:assets/two//banner.png')),
        findsOneWidget,
      );
    });

    testWidgets('utilise la largeur média quand les contraintes sont infinies',
        (tester) async {
      final provider = MemoryImage(_pixelPng);
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: UnconstrainedBox(
            child: ManagedAdPlaceholderTicker(
              fallbackFolderPrefix: 'assets/media',
              borderRadius: BorderRadius.zero,
              enabled: false,
              watchVisible: ({required target}) => const Stream.empty(),
              loadFallbackAssets: (_) async => <String>['assets/media/a.png'],
              assetImageProviderBuilder: (_) => provider,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(Image), findsOneWidget);
      expect(tester.getSize(find.byType(Image)), const Size(800, 800));
      expect(tester.takeException(), isNull);
    });
  });
}

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(width: 320, child: child),
    ),
  );
}

AdPlaceholderImage _image(String id, String url) {
  return AdPlaceholderImage(
    id: id,
    imageUrl: url,
    storagePath: 'path/$id',
    isVisible: true,
    target: 'offers',
    sortOrder: 0,
  );
}

final Uint8List _pixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);
