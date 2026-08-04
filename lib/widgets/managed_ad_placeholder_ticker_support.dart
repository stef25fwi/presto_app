import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:presto_app/services/ad_placeholder_image_service.dart';

typedef AdPlaceholderImagesWatcher = Stream<List<AdPlaceholderImage>> Function({
  required String target,
});
typedef FallbackAssetLoader = Future<List<String>> Function(String prefix);
typedef BannerImageProviderBuilder = ImageProvider Function(String source);

Future<List<String>> loadManagedAdFallbackAssets(String prefix) async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  final normalizedPrefix = prefix.endsWith('/') ? prefix : '$prefix/';
  return manifest
      .listAssets()
      .where(
        (asset) =>
            asset.startsWith(normalizedPrefix) &&
            RegExp(r'\.(png|jpg|jpeg|webp)$', caseSensitive: false)
                .hasMatch(asset),
      )
      .toList()
    ..sort();
}

class ManagedAdBannerImageSource {
  const ManagedAdBannerImageSource._({
    required this.key,
    required this.provider,
  });

  factory ManagedAdBannerImageSource.asset(
    String assetPath, {
    BannerImageProviderBuilder? providerBuilder,
  }) {
    return ManagedAdBannerImageSource._(
      key: 'asset:$assetPath',
      provider: providerBuilder?.call(assetPath) ?? AssetImage(assetPath),
    );
  }

  factory ManagedAdBannerImageSource.network(
    String url, {
    BannerImageProviderBuilder? providerBuilder,
  }) {
    return ManagedAdBannerImageSource._(
      key: 'network:$url',
      provider: providerBuilder?.call(url) ?? NetworkImage(url),
    );
  }

  final String key;
  final ImageProvider provider;
}
