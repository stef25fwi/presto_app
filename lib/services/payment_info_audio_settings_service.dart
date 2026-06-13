import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentInfoAudioSettings {
  const PaymentInfoAudioSettings({
    required this.mp3Url,
    required this.enabled,
  });

  final String mp3Url;
  final bool enabled;

  bool get hasAudio => enabled && mp3Url.trim().isNotEmpty;

  factory PaymentInfoAudioSettings.fromMap(Map<String, dynamic>? data) {
    final map = data ?? const <String, dynamic>{};

    return PaymentInfoAudioSettings(
      mp3Url: (map['mp3Url'] ?? '').toString().trim(),
      enabled: map['enabled'] != false,
    );
  }
}

class PaymentInfoAudioSettingsService {
  PaymentInfoAudioSettingsService._();

  static final _doc = FirebaseFirestore.instance
      .collection('app_settings')
      .doc('payment_info_audio');

  static Stream<PaymentInfoAudioSettings> watch() {
    return _doc.snapshots().map(
          (snapshot) => PaymentInfoAudioSettings.fromMap(snapshot.data()),
        );
  }

  static Future<PaymentInfoAudioSettings> get() async {
    final snapshot = await _doc.get();
    return PaymentInfoAudioSettings.fromMap(snapshot.data());
  }

  static Future<void> save({
    required String mp3Url,
    required bool enabled,
  }) async {
    await _doc.set(
      <String, dynamic>{
        'mp3Url': mp3Url.trim(),
        'enabled': enabled,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
