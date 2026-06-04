import 'dart:typed_data';

import 'package:flutter/material.dart';

class HeroLocalVideoPreview extends StatelessWidget {
  const HeroLocalVideoPreview({
    super.key,
    required this.bytes,
    required this.contentType,
    this.onPreviewError,
    this.onPreviewReady,
  });

  final Uint8List bytes;
  final String contentType;
  final ValueChanged<String>? onPreviewError;
  final VoidCallback? onPreviewReady;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF111827),
      alignment: Alignment.center,
      child: const Icon(
        Icons.play_circle_fill_rounded,
        color: Colors.white,
        size: 34,
      ),
    );
  }
}
