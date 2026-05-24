import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import 'offer_network_image.dart';

// Module-level URL cache shared across all listing thumbnail widgets.
final Map<String, Future<String?>> _urlCache = {};

Future<String?> resolveListingThumbnailUrl(String rawUrl) {
  final trimmed = rawUrl.trim();
  if (trimmed.isEmpty) return Future.value(null);

  if (trimmed.startsWith('http://') ||
      trimmed.startsWith('https://') ||
      trimmed.startsWith('data:image/')) {
    return Future.value(trimmed);
  }

  if (trimmed.startsWith('//')) {
    return Future.value('https:$trimmed');
  }

  final cached = _urlCache[trimmed];
  if (cached != null) return cached;

  final future = () async {
    try {
      if (trimmed.startsWith('gs://')) {
        return await FirebaseStorage.instance.refFromURL(trimmed).getDownloadURL();
      }
      final normalizedPath = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
      if (normalizedPath.isEmpty) {
        _urlCache.remove(trimmed);
        return null;
      }
      return await FirebaseStorage.instance.ref().child(normalizedPath).getDownloadURL();
    } catch (_) {
      _urlCache.remove(trimmed);
      return null;
    }
  }();

  _urlCache[trimmed] = future;
  return future;
}

class ListingThumbnailImage extends StatelessWidget {
  final String rawUrl;
  final double size;
  final double borderRadius;
  final Widget placeholder;

  const ListingThumbnailImage({
    super.key,
    required this.rawUrl,
    required this.size,
    required this.borderRadius,
    required this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: resolveListingThumbnailUrl(rawUrl),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return placeholder;
        }

        final resolvedUrl = (snapshot.data ?? '').trim();
        if (resolvedUrl.isEmpty) return placeholder;

        return ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: OfferNetworkImage(
            url: resolvedUrl,
            fit: BoxFit.cover,
            errorChild: placeholder,
            loadingChild: placeholder,
          ),
        );
      },
    );
  }
}
