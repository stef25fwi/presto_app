import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

typedef PartialHandler = void Function(String text);
typedef FinalHandler = void Function(
  String transcript,
  Map<String, dynamic>? draft,
  Map<String, dynamic>? quality,
  String? modeUsed,
);

class MicroIaStreamClient {
  MicroIaStreamClient._(this._socket);

  final WebSocket _socket;
  StreamSubscription? _sub;

  static Future<MicroIaStreamClient> connect({
    required Uri url,
    required String token,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final socket = await WebSocket.connect(
      url.toString(),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(timeout);
    return MicroIaStreamClient._(socket);
  }

  Future<void> listen({
    PartialHandler? onPartial,
    FinalHandler? onFinal,
    void Function(Object error)? onError,
    void Function()? onDone,
  }) async {
    _sub = _socket.listen((data) {
      if (data is! String) return;
      Map<String, dynamic> m;
      try {
        m = jsonDecode(data) as Map<String, dynamic>;
      } catch (_) {
        return;
      }
      switch (m['event']) {
        case 'partial':
          onPartial?.call((m['text'] ?? '').toString());
          break;
        case 'final':
          onFinal?.call(
            (m['transcript'] ?? '').toString(),
            m['draft'] is Map ? Map<String, dynamic>.from(m['draft']) : null,
            m['quality'] is Map ? Map<String, dynamic>.from(m['quality']) : null,
            m['modeUsed']?.toString(),
          );
          break;
        case 'error':
          onError?.call(Exception(m['message'] ?? 'streaming error'));
          break;
      }
    }, onError: onError, onDone: onDone, cancelOnError: true);
  }

  void sendStart({
    required String languageCode,
    String? cityHint,
    String? categoryHint,
  }) {
    _socket.add(jsonEncode({
      'event': 'start',
      'languageCode': languageCode,
      if (cityHint?.isNotEmpty ?? false) 'cityHint': cityHint,
      if (categoryHint?.isNotEmpty ?? false) 'categoryHint': categoryHint,
    }));
  }

  void sendAudioChunk(Uint8List chunk) {
    _socket.add(jsonEncode({
      'event': 'audio',
      'pcm16': base64Encode(chunk),
    }));
  }

  Future<void> sendStop() async {
    _socket.add(jsonEncode({'event': 'stop'}));
    await _socket.flush();
  }

  Future<void> close() async {
    await _sub?.cancel();
    await _socket.close();
  }
}
