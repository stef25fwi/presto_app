// lib/features/micro_ia/web_audio_recorder.dart
// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:typed_data';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

class WebAudioRecorder {
  web.MediaRecorder? _rec;
  web.MediaStream? _stream;
  final _chunks = <web.Blob>[];

  web.EventListener? _onData;
  web.EventListener? _onStop;

  Future<void> start() async {
    _chunks.clear();

    final mediaDevices = web.window.navigator.mediaDevices;

    final constraints = web.MediaStreamConstraints(audio: true.toJS);
    _stream = await mediaDevices.getUserMedia(constraints).toDart;

    // Browser will likely pick audio/webm;codecs=opus
    _rec = web.MediaRecorder(_stream!);

    _onData = ((web.Event e) {
      final event = e as web.BlobEvent;
      final data = event.data;
      if (data.size > 0) _chunks.add(data);
    }).toJS;

    _rec!.addEventListener('dataavailable', _onData!);
    _rec!.start();
  }

  Future<web.Blob> stopToBlob() async {
    final rec = _rec;
    if (rec == null) throw StateError('Recorder not started');

    final completer = Completer<web.Blob>();

    _onStop = ((web.Event _) {
      if (_onData != null) rec.removeEventListener('dataavailable', _onData!);
      if (_onStop != null) rec.removeEventListener('stop', _onStop!);

      final blob = web.Blob(_chunks.toJS);
      completer.complete(blob);
    }).toJS;

    rec.addEventListener('stop', _onStop!);
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

/// Convert recorded blob -> bytes (Uint8List)
Future<Uint8List> webBlobToBytes(web.Blob blob) async {
  final jsArrayBuffer = await blob.arrayBuffer().toDart;
  final byteBuffer = jsArrayBuffer.toDart;
  return byteBuffer.asUint8List();
}

/// Convert any recorded blob (webm/opus) -> WAV PCM16 16k mono (Uint8List)
Future<Uint8List> webBlobToWav16kMono(web.Blob blob) async {
  // Blob -> ArrayBuffer
  final jsArrayBuffer = await blob.arrayBuffer().toDart;

  // Decode via WebAudio
  final audioCtx = web.AudioContext();
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
