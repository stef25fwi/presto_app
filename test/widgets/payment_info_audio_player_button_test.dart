import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/widgets/payment_info_audio_player_button.dart';

class FakePaymentInfoAudioController implements PaymentInfoAudioController {
  final stateController = StreamController<PlayerState>.broadcast(sync: true);
  final completeController = StreamController<void>.broadcast(sync: true);

  final calls = <String>[];
  bool failSetSource = false;
  bool failStop = false;
  bool failResume = false;
  bool disposed = false;

  @override
  Stream<void> get onPlayerComplete => completeController.stream;

  @override
  Stream<PlayerState> get onPlayerStateChanged => stateController.stream;

  @override
  Future<void> setSource(String url) async {
    calls.add('setSource:$url');
    if (failSetSource) throw StateError('preload failed');
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    if (failStop) throw StateError('stop failed');
    stateController.add(PlayerState.stopped);
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    stateController.add(PlayerState.paused);
  }

  @override
  Future<void> resume() async {
    calls.add('resume');
    if (failResume) throw StateError('resume failed');
    stateController.add(PlayerState.playing);
  }

  @override
  Future<void> seek(Duration position) async {
    calls.add('seek:${position.inMilliseconds}');
  }

  @override
  Future<void> play(String url) async {
    calls.add('play:$url');
    stateController.add(PlayerState.playing);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }

  Future<void> close() async {
    await stateController.close();
    await completeController.close();
  }
}

Widget buildSubject(
  FakePaymentInfoAudioController controller, {
  String audioUrl = ' https://cdn.test/payment.mp3 ',
  String label = 'Écouter',
  bool compact = false,
  VoidCallback? onPlayed,
}) {
  return MaterialApp(
    home: Scaffold(
      body: PaymentInfoAudioPlayerButton(
        audioUrl: audioUrl,
        label: label,
        compact: compact,
        onPlayed: onPlayed,
        audioController: controller,
      ),
    ),
  );
}

void main() {
  testWidgets('précharge la source et affiche le bouton normal', (tester) async {
    final controller = FakePaymentInfoAudioController();
    addTearDown(controller.close);

    await tester.pumpWidget(buildSubject(controller));
    await tester.pump();

    expect(controller.calls, ['setSource:https://cdn.test/payment.mp3']);
    expect(find.text('Écouter'), findsOneWidget);
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    expect(controller.disposed, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(controller.disposed, isFalse);
  });

  testWidgets('lit, met en pause, reprend puis réinitialise à la fin',
      (tester) async {
    final controller = FakePaymentInfoAudioController();
    addTearDown(controller.close);
    var played = 0;

    await tester.pumpWidget(
      buildSubject(controller, onPlayed: () => played++),
    );
    await tester.pump();

    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(controller.calls, containsAllInOrder(['seek:0', 'resume']));
    expect(played, 1);
    expect(find.text('Pause'), findsOneWidget);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(controller.calls, contains('pause'));
    expect(find.text('Reprendre'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(played, 2);
    expect(controller.calls.where((call) => call == 'resume'), hasLength(2));

    controller.completeController.add(null);
    await tester.pump();

    expect(find.text('Écouter'), findsOneWidget);
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
  });

  testWidgets('utilise play quand le préchargement échoue', (tester) async {
    final controller = FakePaymentInfoAudioController()..failSetSource = true;
    addTearDown(controller.close);
    var played = 0;

    await tester.pumpWidget(
      buildSubject(controller, onPlayed: () => played++),
    );
    await tester.pump();

    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(
      controller.calls,
      containsAllInOrder([
        'setSource:https://cdn.test/payment.mp3',
        'play:https://cdn.test/payment.mp3',
      ]),
    );
    expect(played, 1);
    expect(find.text('Pause'), findsOneWidget);
  });

  testWidgets('affiche une erreur et restaure le bouton si la lecture échoue',
      (tester) async {
    final controller = FakePaymentInfoAudioController()..failResume = true;
    addTearDown(controller.close);

    await tester.pumpWidget(buildSubject(controller));
    await tester.pump();

    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(find.textContaining('Lecture audio impossible'), findsOneWidget);
    expect(find.text('Écouter'), findsOneWidget);
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
  });

  testWidgets('ignore une URL vide', (tester) async {
    final controller = FakePaymentInfoAudioController();
    addTearDown(controller.close);

    await tester.pumpWidget(buildSubject(controller, audioUrl: '   '));
    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(controller.calls, isEmpty);
    expect(find.text('Écouter'), findsOneWidget);
  });

  testWidgets('arrête et réinitialise le lecteur quand URL change',
      (tester) async {
    final controller = FakePaymentInfoAudioController()..failStop = true;
    addTearDown(controller.close);

    await tester.pumpWidget(buildSubject(controller));
    await tester.pump();

    await tester.pumpWidget(
      buildSubject(controller, audioUrl: 'https://cdn.test/new.mp3'),
    );
    await tester.pump();

    expect(controller.calls, contains('stop'));
    expect(find.text('Écouter'), findsOneWidget);
  });

  testWidgets('affiche la variante compacte et ses libellés d’état',
      (tester) async {
    final controller = FakePaymentInfoAudioController();
    addTearDown(controller.close);

    await tester.pumpWidget(buildSubject(controller, compact: true));
    await tester.pump();

    expect(find.byType(IconButton), findsOneWidget);
    expect(find.byTooltip('Écouter'), findsOneWidget);

    controller.stateController.add(PlayerState.paused);
    await tester.pump();
    expect(find.byTooltip('Reprendre'), findsOneWidget);

    controller.stateController.add(PlayerState.playing);
    await tester.pump();
    expect(find.byTooltip('Pause'), findsOneWidget);
  });
}
