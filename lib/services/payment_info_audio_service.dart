import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class PaymentInfoAudioConfig {
  const PaymentInfoAudioConfig({
    required this.enabled,
    required this.audioUrl,
    required this.storagePath,
    required this.contentType,
    required this.version,
    required this.generatedAt,
    required this.generatedBy,
  });

  final bool enabled;
  final String? audioUrl;
  final String? storagePath;
  final String? contentType;
  final int? version;
  final Timestamp? generatedAt;
  final String? generatedBy;

  bool get canPlay =>
      enabled && audioUrl != null && audioUrl!.trim().isNotEmpty;

  DateTime? get generatedDate => generatedAt?.toDate();

  factory PaymentInfoAudioConfig.fromMap(Map<String, dynamic>? data) {
    final map = data ?? <String, dynamic>{};

    return PaymentInfoAudioConfig(
      enabled: map['enabled'] == true,
      audioUrl: map['audioUrl'] as String?,
      storagePath: map['storagePath'] as String?,
      contentType: map['contentType'] as String?,
      version: map['version'] is int ? map['version'] as int : null,
      generatedAt: map['generatedAt'] is Timestamp
          ? map['generatedAt'] as Timestamp
          : null,
      generatedBy: map['generatedBy'] as String?,
    );
  }
}

class PaymentInfoAudioService {
  PaymentInfoAudioService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  DocumentReference<Map<String, dynamic>> get _configRef =>
      _firestore.collection('public_config').doc('payment_info_audio');

  Stream<PaymentInfoAudioConfig?> watchConfig() {
    return _configRef.snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return PaymentInfoAudioConfig.fromMap(snapshot.data());
    });
  }

  Future<PaymentInfoAudioConfig?> getConfig() async {
    final snapshot = await _configRef.get();
    if (!snapshot.exists) return null;
    return PaymentInfoAudioConfig.fromMap(snapshot.data());
  }

  Future<PaymentInfoAudioConfig?> generatePaymentInfoAudio({
    String? text,
    String voice = 'alloy',
    String locale = 'fr-FR',
  }) async {
    final callable = _functions.httpsCallable('generatePaymentInfoAudio');

    await callable.call(<String, dynamic>{
      if (text != null && text.trim().isNotEmpty) 'text': text.trim(),
      'voice': voice,
      'locale': locale,
      'format': 'mp3',
    });

    return getConfig();
  }
}

extension PaymentInfoAudioServiceLegacyCompat on PaymentInfoAudioService {
  /// Ancienne API conservée pour les anciens widgets/popups.
  Stream<String?> watchAudioUrl() {
    return watchConfig().map((config) => config?.audioUrl);
  }

  /// Ancienne API minimale : publie une URL MP3 déjà disponible.
  Future<void> uploadAudioUrl(String audioUrl) async {
    final cleanUrl = audioUrl.trim();

    if (cleanUrl.isEmpty) {
      throw ArgumentError('audioUrl vide');
    }

    await _configRef.set({
      'enabled': true,
      'audioUrl': cleanUrl,
      'contentType': 'audio/mpeg',
      'version': DateTime.now().millisecondsSinceEpoch,
      'generatedAt': FieldValue.serverTimestamp(),
      'provider': 'manual_url',
    }, SetOptions(merge: true));
  }
}
