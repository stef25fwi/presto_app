import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/utils/profile_avatar_resolver.dart';

void main() {
  group('isAutomaticGoogleProfilePhoto', () {
    test('refuse les valeurs absentes ou vides', () {
      expect(isAutomaticGoogleProfilePhoto(null), isFalse);
      expect(isAutomaticGoogleProfilePhoto('   '), isFalse);
    });

    test('détecte chaque domaine de photo Google automatique', () {
      expect(
        isAutomaticGoogleProfilePhoto(
          ' HTTPS://LH3.GOOGLEUSERCONTENT.COM/avatar ',
        ),
        isTrue,
      );
      expect(isAutomaticGoogleProfilePhoto('https://example.ggpht.com/a'), isTrue);
      expect(
        isAutomaticGoogleProfilePhoto(
          'https://www.googleapis.com/profile/photo',
        ),
        isTrue,
      );
      expect(
        isAutomaticGoogleProfilePhoto('https://cdn.example.com/avatar.webp'),
        isFalse,
      );
    });
  });

  group('customProfilePhotoUrl', () {
    test('retourne null pour une valeur vide ou Google', () {
      expect(customProfilePhotoUrl(null), isNull);
      expect(customProfilePhotoUrl('  '), isNull);
      expect(
        customProfilePhotoUrl('https://lh3.googleusercontent.com/photo'),
        isNull,
      );
    });

    test('conserve et normalise une photo personnalisée', () {
      expect(
        customProfilePhotoUrl('  https://cdn.example.com/me.jpg  '),
        'https://cdn.example.com/me.jpg',
      );
    });
  });

  group('profileAvatarImageProvider', () {
    test('utilise l asset par défaut sans photo personnalisée', () {
      final emptyProvider = profileAvatarImageProvider(null);
      final googleProvider = profileAvatarImageProvider(
        'https://lh3.googleusercontent.com/photo',
      );

      expect(emptyProvider, isA<AssetImage>());
      expect((emptyProvider as AssetImage).assetName, kDefaultProfileAvatarAsset);
      expect(googleProvider, isA<AssetImage>());
    });

    test('utilise le cache réseau pour une photo personnalisée sur VM', () {
      final provider = profileAvatarImageProvider(
        'https://cdn.example.com/avatar.webp',
      );

      expect(provider, isA<CachedNetworkImageProvider>());
    });
  });
}
