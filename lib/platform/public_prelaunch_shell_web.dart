// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:js_interop';

@JS('iliprestoOpenApplication')
external void _iliprestoOpenApplication();

void revealApplicationAfterPublicPrelaunch() {
  _iliprestoOpenApplication();
}
