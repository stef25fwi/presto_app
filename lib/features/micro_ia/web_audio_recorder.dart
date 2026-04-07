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

    final preferredMimeType = _pickSupportedMimeType();
    _rec = preferredMimeType == null
        ? web.MediaRecorder(_stream!)
        : web.MediaRecorder(
            _stream!,
            web.MediaRecorderOptions(mimeType: preferredMimeType),
          );
    _recordedMimeType = _normalizeMicroIaContentType(_rec!.mimeType);

    _onData = ((web.Event e) {
      final event = e as web.BlobEvent;
      final data = event.data;
      if (data.size > 0) {
        _recordedMimeType ??= _normalizeMicroIaContentType(data.type);
        _chunks.add(data);
      }
    }).toJS;

    _rec!.addEventListener('dataavailable', _onData!);
    _rec!.start();
  }

  Future<web.Blob> stopToBlob() async {
    final pendingStop = _pendingStop;
    if (pendingStop != null) {
      return pendingStop.future;
    }

    final rec = _rec;
    if (rec == null) {
      return web.Blob([Uint8List(0).toJS].toJS);
    }

    final completer = Completer<web.Blob>();
    _pendingStop = completer;

    _onStop = ((web.Event _) {
      if (_onData != null) rec.removeEventListener('dataavailable', _onData!);
      if (_onStop != null) rec.removeEventListener('stop', _onStop!);

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
      if (!completer.isCompleted) {
        completer.complete(blob);
      }
      _pendingStop = null;
      _recordedMimeType = null;
    }).toJS;

    rec.addEventListener('stop', _onStop!);
    rec.requestData();
    rec.stop();

    // stop tracks
    final tracks = _stream?.getTracks();
    if (tracks != null) {
      for (int i = 0; i < tracks.length; i++) {
        tracks[i].stop();
      }
    }
    _stream = null;
    _rec = null;

    return completer.future;
  }
}

String? _pickSupportedMimeType() {
  const candidates = <String>[
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

/// Convert recorded blob -> bytes (Uint8List)
Future<Uint8List> webBlobToBytes(web.Blob blob) async {
  final jsArrayBuffer = await blob.arrayBuffer().toDart;
  final byteBuffer = jsArrayBuffer.toDart;
  return byteBuffer.asUint8List();
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
      throw StateError('Unknown content type');
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
    // > 44 : header WAV seul (44 bytes) = audio vide, on ignore
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
    throw StateError('Unable to decode audio data');
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

/// Convert any recorded blob (webm/opus) -> WAV PCM16 16k mono (Uint8List)
Future<Uint8List> webBlobToWav16kMono(web.Blob blob) async {
  // Blob -> ArrayBuffer
  final jsArrayBuffer = await blob.arrayBuffer().toDart;

  // Decode via WebAudio
  final audioCtx = web.AudioContext();
  try {
    final decoded = await audioCtx.decodeAudioData(jsArrayBuffer).toDart;

    // Mixdown to mono
    final numCh = decoded.numberOfChannels;
    final length = decoded.length;
    final mono = Float32List(length);
    for (int ch = 0; ch < numCh; ch++) {
      final data = decoded.getChannelData(ch).toDart;
      for (int i = 0; i < length; i++) {
        mono[i] += data[i] / numCh;
      }
    }

    // Resample to 16k
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

    // Encode WAV PCM16
    return _encodeWavPcm16(resampled, sampleRate: 16000, numChannels: 1);
  } finally {
    // Best-effort: libère les ressources WebAudio
    try {
      await audioCtx.close().toDart;
    } catch (_) {
      // ignore
    }
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

Uint8List _encodeWavPcm16(Float32List samples,
    {required int sampleRate, required int numChannels}) {
  // PCM16 little-endian
  final bytesPerSample = 2;
  final blockAlign = numChannels * bytesPerSample;
  final byteRate = sampleRate * blockAlign;
  final dataSize = samples.length * bytesPerSample;

  final headerSize = 44;
  final out = ByteData(headerSize + dataSize);

  void writeString(int offset, String s) {
    for (int i = 0; i < s.length; i++) {
      out.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  writeString(0, 'RIFF');
  out.setUint32(4, 36 + dataSize, Endian.little);
  writeString(8, 'WAVE');

  writeString(12, 'fmt ');
  out.setUint32(16, 16, Endian.little); // PCM
  out.setUint16(20, 1, Endian.little); // format=1 PCM
  out.setUint16(22, numChannels, Endian.little);
  out.setUint32(24, sampleRate, Endian.little);
  out.setUint32(28, byteRate, Endian.little);
  out.setUint16(32, blockAlign, Endian.little);
  out.setUint16(34, 16, Endian.little); // bits

  writeString(36, 'data');
  out.setUint32(40, dataSize, Endian.little);

  int o = 44;
  for (int i = 0; i < samples.length; i++) {
    final v = (samples[i].clamp(-1.0, 1.0) * 32767.0).round();
    out.setInt16(o, v, Endian.little);
    o += 2;
  }
  return out.buffer.asUint8List();
}
