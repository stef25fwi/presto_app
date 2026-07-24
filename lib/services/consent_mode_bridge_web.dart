@JS()
library;

import 'dart:js_interop';

@JS('iliprestoConsentUpdate')
external void _iliprestoConsentUpdate(
  JSBoolean analyticsAllowed,
  JSBoolean marketingAllowed,
);

Future<void> applyGoogleConsentMode({
  required bool analyticsAllowed,
  required bool marketingAllowed,
}) async {
  _iliprestoConsentUpdate(
    analyticsAllowed.toJS,
    marketingAllowed.toJS,
  );
}
