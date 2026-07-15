import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';

class PaymentInfoAudioConfig {
  const PaymentInfoAudioConfig({
    required this.enabled,
    required this.audioUrl,
    required this.storagePath,
    required this.contentType,
    required this.version,
    required this.generatedAt,
    required this.generatedBy,
    this.voice,
    this.textHash,
  });

  final bool enabled;
  final String? audioUrl;
  final String? storagePath;
  final String? contentType;
  final int? version;
  final Timestamp? generatedAt;
  final String? generatedBy;
  final String? voice;
  final String? textHash;

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
      voice: map['voice'] as String?,
      textHash: map['textHash'] as String?,
    );
  }
}

class PaymentInfoAudioAdminSettings {
  const PaymentInfoAudioAdminSettings({
    required this.text,
    required this.draftAudioUrl,
    required this.draftStoragePath,
    required this.draftContentType,
    required this.draftVersion,
    required this.draftGeneratedAt,
    required this.draftGeneratedBy,
    required this.draftVoice,
    required this.draftTextHash,
    required this.lastGeneratedAt,
    required this.lastPublishedAt,
  });

  final String text;
  final String? draftAudioUrl;
  final String? draftStoragePath;
  final String? draftContentType;
  final int? draftVersion;
  final Timestamp? draftGeneratedAt;
  final String? draftGeneratedBy;
  final String? draftVoice;
  final String? draftTextHash;
  final Timestamp? lastGeneratedAt;
  final Timestamp? lastPublishedAt;

  bool get canPreviewDraft =>
      draftAudioUrl != null && draftAudioUrl!.trim().isNotEmpty;

  DateTime? get draftGeneratedDate => draftGeneratedAt?.toDate();
  DateTime? get lastPublishedDate => lastPublishedAt?.toDate();

  factory PaymentInfoAudioAdminSettings.fromMap(Map<String, dynamic>? data) {
    final map = data ?? <String, dynamic>{};

    return PaymentInfoAudioAdminSettings(
      text: (map['text'] ?? map['paymentText'] ?? map['audioText'] ?? '')
          .toString(),
      draftAudioUrl: map['draftAudioUrl'] as String?,
      draftStoragePath: map['draftStoragePath'] as String?,
      draftContentType: map['draftContentType'] as String?,
      draftVersion:
          map['draftVersion'] is int ? map['draftVersion'] as int : null,
      draftGeneratedAt: map['draftGeneratedAt'] is Timestamp
          ? map['draftGeneratedAt'] as Timestamp
          : null,
      draftGeneratedBy: map['draftGeneratedBy'] as String?,
      draftVoice: map['draftVoice'] as String?,
      draftTextHash: map['draftTextHash'] as String?,
      lastGeneratedAt: map['lastGeneratedAt'] is Timestamp
          ? map['lastGeneratedAt'] as Timestamp
          : null,
      lastPublishedAt: map['lastPublishedAt'] is Timestamp
          ? map['lastPublishedAt'] as Timestamp
          : null,
    );
  }
}

class PaymentInfoAudioService {
  PaymentInfoAudioService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions? _functions;

  FirebaseFunctions get _firebaseFunctions =>
      _functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  DocumentReference<Map<String, dynamic>> get _configRef =>
      _firestore.collection('public_config').doc('payment_info_audio');

  DocumentReference<Map<String, dynamic>> get _settingsRef =>
      _firestore.collection('admin_settings').doc('payment_info_audio');

  Stream<PaymentInfoAudioConfig?> watchConfig() {
    return _configRef.snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return PaymentInfoAudioConfig.fromMap(snapshot.data());
    });
  }

  Stream<PaymentInfoAudioAdminSettings> watchAdminSettings() {
    return _settingsRef.snapshots().map((snapshot) {
      return PaymentInfoAudioAdminSettings.fromMap(snapshot.data());
    });
  }

  Future<PaymentInfoAudioConfig?> getConfig() async {
    final snapshot = await _configRef.get();
    if (!snapshot.exists) return null;
    return PaymentInfoAudioConfig.fromMap(snapshot.data());
  }

  Future<PaymentInfoAudioAdminSettings> getAdminSettings() async {
    final snapshot = await _settingsRef.get();
    return PaymentInfoAudioAdminSettings.fromMap(snapshot.data());
  }

  Future<void> saveAdminText(String text) async {
    await _settingsRef.set({
      'text': text.trim(),
      'paymentText': text.trim(),
      'audioText': text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Ancienne API conservée : génère et publie directement.
  Future<PaymentInfoAudioConfig?> generatePaymentInfoAudio({
    String? text,
    String voice = 'alloy',
    String locale = 'fr-FR',
  }) async {
    final callable =
        _firebaseFunctions.httpsCallable('generatePaymentInfoAudio');

    await callable.call(<String, dynamic>{
      if (text != null && text.trim().isNotEmpty) 'text': text.trim(),
      'voice': voice,
      'locale': locale,
      'format': 'mp3',
    });

    return getConfig();
  }

  /// Nouveau workflow : génère un MP3 brouillon sans le publier dans le popup.
  Future<PaymentInfoAudioAdminSettings> generatePaymentInfoAudioDraft({
    required String text,
    String voice = 'alloy',
    String locale = 'fr-FR',
  }) async {
    final cleanText = text.trim();

    if (cleanText.isEmpty) {
      throw ArgumentError('Le texte audio ne peut pas être vide.');
    }

    final callable =
        _firebaseFunctions.httpsCallable('generatePaymentInfoAudioDraft');

    await callable.call(<String, dynamic>{
      'text': cleanText,
      'voice': voice,
      'locale': locale,
      'format': 'mp3',
    });

    return getAdminSettings();
  }

  /// Publie le dernier brouillon validé dans public_config/payment_info_audio.
  Future<PaymentInfoAudioConfig?> publishPaymentInfoAudioDraft() async {
    final callable =
        _firebaseFunctions.httpsCallable('publishPaymentInfoAudioDraft');
    await callable.call(<String, dynamic>{});
    return getConfig();
  }
}

extension PaymentInfoAudioServiceLegacyCompat on PaymentInfoAudioService {
  /// Ancienne API conservée pour les anciens widgets/popups.
  Stream<String?> watchAudioUrl() {
    return watchConfig().map((config) => config?.audioUrl);
  }

  /// Upload un fichier MP3 brut vers Firebase Storage puis publie l'URL dans Firestore.
  Future<void> uploadAudio(Uint8List bytes, String filename) async {
    final path =
        'payment_info_audio/${DateTime.now().millisecondsSinceEpoch}_$filename';
    final ref = FirebaseStorage.instance.ref(path);
    await ref.putData(bytes, SettableMetadata(contentType: 'audio/mpeg'));
    final downloadUrl = await ref.getDownloadURL();

    await _configRef.set({
      'enabled': true,
      'audioUrl': downloadUrl,
      'storagePath': path,
      'contentType': 'audio/mpeg',
      'version': DateTime.now().millisecondsSinceEpoch,
      'generatedAt': FieldValue.serverTimestamp(),
      'provider': 'manual_upload',
    }, SetOptions(merge: true));
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
