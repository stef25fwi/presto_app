import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/widgets/payment_info_audio_player_button.dart';

class _RecordingAudioPlayer extends AudioPlayer {
  final calls = <String>[];
  Source? receivedSource;
  Duration? receivedPosition;

  @override
  Future<void> setSource(Source source) async {
    receivedSource = source;
    calls.add('setSource');
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
  }

  @override
  Future<void> resume() async {
    calls.add('resume');
  }

  @override
  Future<void> seek(Duration position) async {
    receivedPosition = position;
    calls.add('seek');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('délègue les commandes de lecture au lecteur Audioplayers', () async {
    final player = _RecordingAudioPlayer();
    final controller = AudioplayersPaymentInfoAudioController(player: player);

    await controller.setSource('https://cdn.test/payment-info.mp3');
    await controller.stop();
    await controller.pause();
    await controller.resume();
    await controller.seek(const Duration(milliseconds: 750));

    expect(player.calls, <String>[
      'setSource',
      'stop',
      'pause',
      'resume',
      'seek',
    ]);
    expect(player.receivedSource, isA<UrlSource>());
    expect(
      (player.receivedSource! as UrlSource).url,
      'https://cdn.test/payment-info.mp3',
    );
    expect(player.receivedPosition, const Duration(milliseconds: 750));
  });
}
