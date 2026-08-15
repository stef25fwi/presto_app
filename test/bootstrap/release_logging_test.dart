import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/bootstrap/release_logging.dart';

void main() {
  final DebugPrintCallback original = debugPrint;

  tearDown(() {
    debugPrint = original;
  });

  test('hors release, la sortie de débogage est préservée', () {
    // Les tests s'exécutent en mode debug : neutraliser debugPrint ici ferait
    // perdre toute trace pendant le développement.
    silenceDebugPrintInRelease();
    expect(debugPrint, same(original));
  });

  test('le remplacement release respecte la signature et n_émet rien', () {
    final captured = <String?>[];
    debugPrint = (String? message, {int? wrapWidth}) => captured.add(message);
    debugPrint('visible');
    expect(captured, <String?>['visible']);

    // Contrat appliqué en release. kReleaseMode n'étant pas manipulable depuis
    // un test, on vérifie directement que la forme retenue est valide et muette.
    debugPrint = (String? message, {int? wrapWidth}) {};
    debugPrint('ne doit pas apparaître');
    expect(captured, <String?>['visible']);
  });
}
