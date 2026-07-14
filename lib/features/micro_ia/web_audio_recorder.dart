// lib/features/micro_ia/web_audio_recorder.dart
// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:typed_data';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

class WebMicroIaAudioUpload {
  const WebMicroIaAudioUpload({
    required this.bytes,
    required this.contentType,
    required this.extension,
    required this.usedClientSideWavConversion,
  });

  final Uint8List bytes;
  final String contentType;
  final String extension;
  final bool usedClientSideWavConversion;
}

class WebAudioRecorder {
  web.MediaRecorder? _rec;
  web.MediaStream? _stream;
  final _chunks = <web.Blob>[];
  Completer<web.Blob>? _pendingStop;
  String? _recordedMimeType;

  web.EventListener? _onData;
  web.EventListener? _onStop;
  web.EventListener? _onError;

  Future<void> start() async {
    final pendingStop = _pendingStop;
    if (pendingStop != null) {
      await pendingStop.future;
    }

    if (_rec != null) {
      return;
    }

    _chunks.clear();
    _recordedMimeType = null;

    final mediaDevices = web.window.navigator.mediaDevices;
    final constraints = web.MediaStreamConstraints(audio: true.toJS);
    _stream = await mediaDevices.getUserMedia(constraints).toDart;

    try {
      final preferredMimeType = _pickSupportedMimeType();
      _rec = preferredMimeType == null
          ? web.MediaRecorder(_stream!)
          : web.MediaRecorder(
              _stream!,
              web.MediaRecorderOptions(mimeType: preferredMimeType),
            );
    } catch (_) {
      _stopTracks();
      rethrow;
    }

    _recordedMimeType = _normalizeMicroIaContentType(_rec!.mimeType);

    _onData = ((web.Event e) {
      final event = e as web.BlobEvent;
      final data = event.data;
      if (data.size > 0) {
        _recordedMimeType ??= _normalizeMicroIaContentType(data.type);
        _chunks.add(data);
      }
    }).toJS;

    _onError = ((web.Event _) {
      final pending = _pendingStop;
      if (pending != null && !pending.isCompleted) {
        pending.completeError(
          StateError('Erreur MediaRecorder pendant l’enregistrement audio.'),
        );
      }
      _resetRecorderState();
    }).toJS;

    _rec!.addEventListener('dataavailable', _onData!);
    _rec!.addEventListener('error', _onError!);

    // Un timeslice court force la production régulière de chunks sur Safari/iOS.
    _rec!.start(250);
  }

  Future<web.Blob> stopToBlob() async {
    final pendingStop = _pendingStop;
    if (pendingStop != null) {
      return pendingStop.future;
    }

    final rec = _rec;
    if (rec == null) {
      throw StateError('Aucun enregistrement audio actif.');
    }

    final completer = Completer<web.Blob>();
    _pendingStop = completer;

    _onStop = ((web.Event _) {
      try {
        final normalizedType = _recordedMimeType ??
            _normalizeMicroIaContentType(rec.mimeType) ??
            (_chunks.isNotEmpty
                ? _normalizeMicroIaContentType(_chunks.first.type)
                : null);
        final blob = normalizedType == null
            ? web.Blob(_chunks.toJS)
            : web.Blob(
                _chunks.toJS,
                web.BlobPropertyBag(type: normalizedType),
              );

        if (blob.size <= 0) {
          throw StateError(
            'Enregistrement audio vide. Maintenez le micro au moins une seconde.',
          );
        }

        if (!completer.isCompleted) {
          completer.complete(blob);
        }
      } catch (error, stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      } finally {
        _resetRecorderState();
      }
    }).toJS;

    rec.addEventListener('stop', _onStop!);

    try {
      // requestData peut lever une exception sur Safari lorsque l’arrêt arrive vite.
      try {
        rec.requestData();
      } catch (_) {
        // Les chunks périodiques obtenus grâce au timeslice restent exploitables.
      }
      rec.stop();
    } catch (error, stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
      _resetRecorderState();
    } finally {
      _stopTracks();
    }

    return completer.future;
  }

  void _stopTracks() {
    final tracks = _stream?.getTracks();
    if (tracks != null) {
      for (int i = 0; i < tracks.length; i++) {
        tracks[i].stop();
      }
    }
    _stream = null;
  }

  void _resetRecorderState() {
    final rec = _rec;
    if (rec != null) {
      if (_onData != null) {
        rec.removeEventListener('dataavailable', _onData!);
      }
      if (_onStop != null) {
        rec.removeEventListener('stop', _onStop!);
      }
      if (_onError != null) {
        rec.removeEventListener('error', _onError!);
      }
    }
    _stopTracks();
    _rec = null;
    _pendingStop = null;
    _recordedMimeType = null;
    _onData = null;
    _onStop = null;
    _onError = null;
  }
}

String? _pickSupportedMimeType() {
  final userAgent = web.window.navigator.userAgent.toLowerCase();
  final isAppleWebKit = userAgent.contains('iphone') ||
      userAgent.contains('ipad') ||
      userAgent.contains('ipod') ||
      (userAgent.contains('macintosh') && userAgent.contains('safari'));

  final candidates = isAppleWebKit
      ? const <String>[
          'audio/mp4',
          'audio/webm;codecs=opus',
          'audio/webm',
        ]
      : const <String>[
          'audio/webm;codecs=opus',
          'audio/webm',
          'audio/mp4',
        ];

  for (final candidate in candidates) {
    if (web.MediaRecorder.isTypeSupported(candidate)) {
      return candidate;
    }
  }

  return null;
}

Future<Uint8List> webBlobToBytes(web.Blob blob) async {
  if (blob.size <= 0) {
    throw StateError('Enregistrement audio vide.');
  }
  final jsArrayBuffer = await blob.arrayBuffer().toDart;
  final byteBuffer = jsArrayBuffer.toDart;
  final bytes = byteBuffer.asUint8List();
  if (bytes.isEmpty) {
    throw StateError('Enregistrement audio vide.');
  }
  return bytes;
}

Future<WebMicroIaAudioUpload> webBlobToMicroIaUpload(
  web.Blob blob, {
  bool preferRawBytes = false,
}) async {
  final fallbackContentType = _normalizeMicroIaContentType(blob.type);

  if (preferRawBytes) {
    final rawBytes = await webBlobToBytes(blob);
    final rawContentType =
        fallbackContentType ?? _inferMicroIaContentTypeFromBytes(rawBytes);
    if (rawContentType == null) {
      throw StateError('Format audio non pris en charge par ce navigateur.');
    }

    return WebMicroIaAudioUpload(
      bytes: rawBytes,
      contentType: rawContentType,
      extension: _extensionForMicroIaContentType(rawContentType),
      usedClientSideWavConversion: false,
    );
  }

  try {
    final wavBytes = await webBlobToWav16kMono(blob);
    if (wavBytes.length > 44) {
      return WebMicroIaAudioUpload(
        bytes: wavBytes,
        contentType: 'audio/wav',
        extension: 'wav',
        usedClientSideWavConversion: true,
      );
    }
  } catch (_) {
    if (fallbackContentType == null) {
      final rawBytes = await webBlobToBytes(blob);
      final inferredContentType = _inferMicroIaContentTypeFromBytes(rawBytes);
      if (inferredContentType == null) {
        rethrow;
      }

      return WebMicroIaAudioUpload(
        bytes: rawBytes,
        contentType: inferredContentType,
        extension: _extensionForMicroIaContentType(inferredContentType),
        usedClientSideWavConversion: false,
      );
    }
  }

  if (fallbackContentType == null) {
    throw StateError('Format audio non pris en charge par ce navigateur.');
  }

  final rawBytes = await webBlobToBytes(blob);
  return WebMicroIaAudioUpload(
    bytes: rawBytes,
    contentType: fallbackContentType,
    extension: _extensionForMicroIaContentType(fallbackContentType),
    usedClientSideWavConversion: false,
  );
}

String? _inferMicroIaContentTypeFromBytes(Uint8List bytes) {
  if (bytes.length < 4) return null;

  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x41 &&
      bytes[10] == 0x56 &&
      bytes[11] == 0x45) {
    return 'audio/wav';
  }

  if (bytes.length >= 4 &&
      bytes[0] == 0x1A &&
      bytes[1] == 0x45 &&
      bytes[2] == 0xDF &&
      bytes[3] == 0xA3) {
    return 'audio/webm';
  }

  if (bytes.length >= 8 &&
      bytes[4] == 0x66 &&
      bytes[5] == 0x74 &&
      bytes[6] == 0x79 &&
      bytes[7] == 0x70) {
    return 'audio/mp4';
  }

  if (bytes[0] == 0xFF && (bytes[1] & 0xF0) == 0xF0) {
    return 'audio/aac';
  }

  return null;
}

Future<Uint8List> webBlobToWav16kMono(web.Blob blob) async {
  final jsArrayBuffer = await blob.arrayBuffer().toDart;
  final audioCtx = web.AudioContext();
  try {
    final decoded = await audioCtx.decodeAudioData(jsArrayBuffer).toDart;

    final numCh = decoded.numberOfChannels;
    final length = decoded.length;
    final mono = Float32List(length);
    for (int ch = 0; ch < numCh; ch++) {
      final data = decoded.getChannelData(ch).toDart;
      for (int i = 0; i < length; i++) {
        mono[i] += data[i] / numCh;
      }
    }

    final srcRate = decoded.sampleRate.toDouble();
    const dstRate = 16000.0;
    final ratio = srcRate / dstRate;
    final dstLen = (mono.length / ratio).floor();
    final resampled = Float32List(dstLen);
    for (int i = 0; i < dstLen; i++) {
      final srcIndex = i * ratio;
      final i0 = srcIndex.floor();
      final i1 = (i0 + 1 < mono.length) ? i0 + 1 : i0;
      final frac = srcIndex - i0;
      resampled[i] = mono[i0] * (1 - frac) + mono[i1] * frac;
    }

    return _encodeWavPcm16(resampled, sampleRate: 16000, numChannels: 1);
  } finally {
    try {
      await audioCtx.close().toDart;
    } catch (_) {}
  }
}

String? _normalizeMicroIaContentType(String rawType) {
  final type = rawType.trim().toLowerCase();
  if (type.isEmpty) return null;

  final baseType = type.split(';').first.trim();
  switch (baseType) {
    case 'audio/wav':
    case 'audio/x-wav':
    case 'audio/wave':
    case 'audio/vnd.wave':
      return 'audio/wav';
    case 'audio/webm':
    case 'video/webm':
      return 'audio/webm';
    case 'audio/mp4':
    case 'video/mp4':
      return 'audio/mp4';
    case 'audio/x-m4a':
      return 'audio/x-m4a';
    case 'audio/aac':
      return 'audio/aac';
    default:
      return null;
  }
}

String _extensionForMicroIaContentType(String contentType) {
  switch (contentType) {
    case 'audio/webm':
      return 'webm';
    case 'audio/mp4':
      return 'mp4';
    case 'audio/x-m4a':
      return 'm4a';
    case 'audio/aac':
      return 'aac';
    case 'audio/wav':
    default:
      return 'wav';
  }
}

Uint8List _encodeWavPcm16(
  Float32List samples, {
  required int sampleRate,
  required int numChannels,
}) {
  final bytesPerSample = 2;
  final blockAlign = numChannels * bytesPerSample;
  final byteRate = sampleRate * blockAlign;
  final dataSize = samples.length * bytesPerSample;

  const headerSize = 44;
  final out = ByteData(headerSize + dataSize);

  void writeString(int offset, String value) {
    for (int i = 0; i < value.length; i++) {
      out.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  writeString(0, 'RIFF');
  out.setUint32(4, 36 + dataSize, Endian.little);
  writeString(8, 'WAVE');

  writeString(12, 'fmt ');
  out.setUint32(16, 16, Endian.little);
  out.setUint16(20, 1, Endian.little);
  out.setUint16(22, numChannels, Endian.little);
  out.setUint32(24, sampleRate, Endian.little);
  out.setUint32(28, byteRate, Endian.little);
  out.setUint16(32, blockAlign, Endian.little);
  out.setUint16(34, 16, Endian.little);

  writeString(36, 'data');
  out.setUint32(40, dataSize, Endian.little);

  int offset = 44;
  for (int i = 0; i < samples.length; i++) {
    final value = (samples[i].clamp(-1.0, 1.0) * 32767.0).round();
    out.setInt16(offset, value, Endian.little);
    offset += 2;
  }
  return out.buffer.asUint8List();
}
