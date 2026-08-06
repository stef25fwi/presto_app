import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/widgets/managed_ad_placeholder_ticker_support.dart';

void main() {
  group('loadManagedAdFallbackAssets', () {
    test('normalise le préfixe, filtre les images et trie les assets', () async {
      var calls = 0;

      final assets = await loadManagedAdFallbackAssets(
        'assets/carousel_home',
        manifestEntriesLoader: () async {
          calls++;
          return <String>[
            'assets/carousel_home/z.webp',
            'assets/carousel_home/readme.txt',
            'assets/other/ignored.png',
            'assets/carousel_home/a.JPG',
            'assets/carousel_home/m.jpeg',
            'assets/carousel_home/b.PNG',
          ];
        },
      );

      expect(calls, 1);
      expect(assets, <String>[
        'assets/carousel_home/a.JPG',
        'assets/carousel_home/b.PNG',
        'assets/carousel_home/m.jpeg',
        'assets/carousel_home/z.webp',
      ]);
    });

    test('conserve un préfixe déjà terminé par une barre oblique', () async {
      final assets = await loadManagedAdFallbackAssets(
        'assets/banner/',
        manifestEntriesLoader: () async => <String>[
          'assets/banner/image.jpg',
          'assets/banner_extra/image.jpg',
        ],
      );

      expect(assets, <String>['assets/banner/image.jpg']);
    });
  });

  group('ManagedAdBannerImageSource', () {
    test('crée une source asset avec une clé stable et AssetImage', () {
      final source = ManagedAdBannerImageSource.asset(
        'assets/images/banner.webp',
      );

      expect(source.key, 'asset:assets/images/banner.webp');
      expect(source.provider, isA<AssetImage>());
      expect(
        (source.provider as AssetImage).assetName,
        'assets/images/banner.webp',
      );
    });

    test('crée une source réseau avec une clé stable et NetworkImage', () {
      const url = 'https://ilipresto.fr/media/banner.jpg';
      final source = ManagedAdBannerImageSource.network(url);

      expect(source.key, 'network:$url');
      expect(source.provider, isA<NetworkImage>());
      expect((source.provider as NetworkImage).url, url);
    });

    test('utilise le builder injecté pour une source asset', () {
      final expected = MemoryImage(Uint8List.fromList(<int>[0, 1, 2]));
      String? receivedPath;

      final source = ManagedAdBannerImageSource.asset(
        'assets/custom.png',
        providerBuilder: (path) {
          receivedPath = path;
          return expected;
        },
      );

      expect(receivedPath, 'assets/custom.png');
      expect(source.key, 'asset:assets/custom.png');
      expect(identical(source.provider, expected), isTrue);
    });

    test('utilise le builder injecté pour une source réseau', () {
      final expected = MemoryImage(Uint8List.fromList(<int>[3, 4, 5]));
      String? receivedUrl;

      final source = ManagedAdBannerImageSource.network(
        'https://cdn.ilipresto.fr/ad.webp',
        providerBuilder: (url) {
          receivedUrl = url;
          return expected;
        },
      );

      expect(receivedUrl, 'https://cdn.ilipresto.fr/ad.webp');
      expect(source.key, 'network:https://cdn.ilipresto.fr/ad.webp');
      expect(identical(source.provider, expected), isTrue);
    });
  });
}
