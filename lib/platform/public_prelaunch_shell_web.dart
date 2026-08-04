// ignore_for_file: avoid_web_libraries_in_flutter

import 'package:web/web.dart' as web;

void revealApplicationAfterPublicPrelaunch() {
  final callback = web.window['iliprestoOpenApplication'];
  if (callback is web.JSFunction) {
    callback.callAsFunction();
  }
}
