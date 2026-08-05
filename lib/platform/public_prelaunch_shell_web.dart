// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:js_interop';

@JS('iliprestoOpenApplication')
external void _iliprestoOpenApplication();

@JS('iliprestoHasPrelaunchAccess')
external JSBoolean _iliprestoHasPrelaunchAccess();

bool hasPublicPrelaunchAccess() {
  try {
    return _iliprestoHasPrelaunchAccess().toDart;
  } catch (_) {
    return false;
  }
}

void revealApplicationAfterPublicPrelaunch() {
  _iliprestoOpenApplication();
}
