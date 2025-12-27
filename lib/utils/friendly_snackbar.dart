import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

bool isTimeoutError(Object e) {
  if (e is TimeoutException) return true;
  if (e is FirebaseFunctionsException && e.code == 'deadline-exceeded') {
    return true;
  }
  return false;
}

void showTimeoutSnackBar(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Connexion lente, réessaie.'),
      duration: Duration(seconds: 3),
    ),
  );
}
