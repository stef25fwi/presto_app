import 'dart:io';

import 'package:firebase_core/firebase_core.dart';

import 'package:presto_app/dev/seed_offers.dart';
import 'package:presto_app/firebase_options.dart';

/// Seed 4 offers for messaging tests.
Future<void> main(List<String> args) async {
  final userId = _parseUserId(args);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  stdout.writeln('Seeding messaging offers for userId=$userId ...');
  await seedMessagingOffers(userId: userId);
  stdout.writeln('Done.');
}

String _parseUserId(List<String> args) {
  if (args.isEmpty) {
    _usage();
    exitCode = 1;
    throw Exception('Missing --userId');
  }
  for (final arg in args) {
    if (arg.startsWith('--userId=')) {
      final value = arg.substring('--userId='.length).trim();
      if (value.isEmpty) break;
      return value;
    }
  }
  _usage();
  exitCode = 1;
  throw Exception('Missing --userId');
}

void _usage() {
  stderr.writeln('Usage: dart run bin/seed_messaging_offers.dart --userId=<UID>');
}
