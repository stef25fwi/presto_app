import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Avatar utilisé lorsqu'aucune photo personnelle n'a été choisie.
const String kDefaultProfileAvatarAsset = 'assets/images/default_avatar.webp';

/// Les photos automatiquement fournies par Google ne sont pas utilisées.
///
/// Une photo réellement téléversée par l'utilisateur, hébergée ailleurs,
/// reste autorisée.
bool isAutomaticGoogleProfilePhoto(String? value) {
  final url = value?.trim().toLowerCase() ?? '';

  if (url.isEmpty) return false;

  return url.contains('googleusercontent.com') ||
      url.contains('ggpht.com') ||
      url.contains('googleapis.com/profile');
}

/// URL pouvant être conservée comme véritable photo personnalisée.
///
/// Retourne null pour une URL vide ou une photo automatique Google.
String? customProfilePhotoUrl(String? value) {
  final url = value?.trim() ?? '';

  if (url.isEmpty || isAutomaticGoogleProfilePhoto(url)) {
    return null;
  }

  return url;
}

/// Résout l'image de profil.
///
/// - photo Google automatique : logo iliprestō ;
/// - aucune photo : logo iliprestō ;
/// - photo téléversée manuellement : image réseau.
ImageProvider<Object> profileAvatarImageProvider(String? value) {
  final customUrl = customProfilePhotoUrl(value);

  if (customUrl == null) {
    return const AssetImage(kDefaultProfileAvatarAsset);
  }

  // Mobile : cache disque persistant entre les sessions.
  // Web : le cache HTTP du navigateur suffit.
  if (kIsWeb) {
    return NetworkImage(customUrl);
  }
  return CachedNetworkImageProvider(customUrl);
}
