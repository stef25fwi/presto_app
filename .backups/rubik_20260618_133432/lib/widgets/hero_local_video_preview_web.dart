// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../utils/runtime_action_logger.dart';

class HeroLocalVideoPreview extends StatefulWidget {
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
  State<HeroLocalVideoPreview> createState() => _HeroLocalVideoPreviewState();
}

class _HeroLocalVideoPreviewState extends State<HeroLocalVideoPreview> {
  static int _nextId = 0;

  String? _objectUrl;
  late String _viewType;
  bool _didReportReady = false;
  bool _didReportError = false;

  @override
  void initState() {
    super.initState();
    _registerPreview();
  }

  @override
  void didUpdateWidget(covariant HeroLocalVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameBytes(oldWidget.bytes, widget.bytes) ||
        oldWidget.contentType != widget.contentType) {
      _disposePreviewUrl();
      _registerPreview();
    }
  }

  @override
  void dispose() {
    _disposePreviewUrl();
    super.dispose();
  }

  void _registerPreview() {
    _didReportReady = false;
    _didReportError = false;
    final contentType = widget.contentType.trim().isEmpty
        ? 'video/mp4'
        : widget.contentType.trim();
    final blob = web.Blob(
      [widget.bytes.toJS].toJS,
      web.BlobPropertyBag(type: contentType),
    );
    _objectUrl = web.URL.createObjectURL(blob);
    _viewType = 'hero-local-video-preview-${_nextId++}';

    final src = _objectUrl!;
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
      final video = web.HTMLVideoElement()
        ..src = src
        ..muted = true
        ..autoplay = true
        ..loop = true
        ..playsInline = true
        ..preload = 'metadata'
        ..controls = false
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.display = 'block'
        ..style.objectFit = 'cover'
        ..style.backgroundColor = '#111827';

      final onLoadedMetadata = ((web.Event _) {
        if (_didReportReady) {
          return;
        }
        _didReportReady = true;
        logRuntimeAction(
          area: 'admin-hero',
          action: 'video-preview-ready',
          details: <String, Object?>{
            'contentType': contentType,
            'width': video.videoWidth,
            'height': video.videoHeight,
            'bytes': widget.bytes.lengthInBytes,
          },
        );
        widget.onPreviewReady?.call();
      }).toJS;

      final onError = ((web.Event _) {
        if (_didReportError) {
          return;
        }
        _didReportError = true;
        const message = 'Prévisualisation vidéo web indisponible.';
        logRuntimeAction(
          area: 'admin-hero',
          action: 'video-preview-error',
          details: <String, Object?>{
            'contentType': contentType,
            'bytes': widget.bytes.lengthInBytes,
            'networkState': video.networkState,
            'readyState': video.readyState,
            'errorCode': video.error?.code,
          },
        );
        widget.onPreviewError?.call(message);
      }).toJS;

      video.addEventListener('loadedmetadata', onLoadedMetadata);
      video.addEventListener('error', onError);

      final container = web.HTMLDivElement()
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.overflow = 'hidden'
        ..style.backgroundColor = '#111827';
      container.append(video);
      return container;
    });
  }

  void _disposePreviewUrl() {
    final objectUrl = _objectUrl;
    if (objectUrl == null || objectUrl.isEmpty) {
      return;
    }
    web.URL.revokeObjectURL(objectUrl);
    _objectUrl = null;
  }

  bool _sameBytes(Uint8List left, Uint8List right) {
    if (identical(left, right)) {
      return true;
    }
    if (left.lengthInBytes != right.lengthInBytes) {
      return false;
    }
    for (var index = 0; index < left.lengthInBytes; index += 1) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
