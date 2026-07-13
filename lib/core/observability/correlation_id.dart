import 'dart:math';

final RegExp _correlationIdPattern = RegExp(r'^[A-Za-z0-9._:-]{8,80}$');

String? normalizeCorrelationId(Object? value) {
  final normalized = (value ?? '').toString().trim();
  if (!_correlationIdPattern.hasMatch(normalized)) return null;
  return normalized;
}

String createCorrelationId({
  DateTime Function()? clock,
  int Function(int max)? nextInt,
}) {
  final now = (clock ?? DateTime.now)().toUtc();
  final random = nextInt ?? Random.secure().nextInt;
  final timePart = now.microsecondsSinceEpoch.toRadixString(36);
  final randomPart = List<String>.generate(
    3,
    (_) => random(1 << 32).toRadixString(36).padLeft(7, '0'),
    growable: false,
  ).join();
  return 'client-$timePart-$randomPart';
}

String resolveCorrelationId(
  Object? value, {
  DateTime Function()? clock,
  int Function(int max)? nextInt,
}) {
  return normalizeCorrelationId(value) ??
      createCorrelationId(clock: clock, nextInt: nextInt);
}
