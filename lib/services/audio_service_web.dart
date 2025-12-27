// Stub pour le web - l'enregistrement audio n'est pas supporté
import 'dart:async';

class AudioRecorder {
  Future<bool> hasPermission() async => false;
  
  Future<void> start(RecordConfig config, {String? path}) async {
    throw UnsupportedError('Audio recording not supported on web');
  }
  
  Future<String?> stop() async => null;
  
  void dispose() {}
}

class RecordConfig {
  final AudioEncoder encoder;
  final int sampleRate;
  final int numChannels;
  
  const RecordConfig({
    required this.encoder,
    required this.sampleRate,
    required this.numChannels,
  });
}

// Inclure `wav` pour compatibilité compilation avec le code partagé.
// L'enregistrement web reste non supporté et lève UnsupportedError dans start().
enum AudioEncoder { aacLc, wav }
