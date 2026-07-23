import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

enum AppOperatingMode { freeBeta, commercial }

AppOperatingMode appOperatingModeFromValue(Object? value) {
  switch ((value ?? '').toString().trim().toLowerCase()) {
    case 'commercial':
    case 'paid':
    case 'payant':
      return AppOperatingMode.commercial;
    default:
      return AppOperatingMode.freeBeta;
  }
}

extension AppOperatingModeX on AppOperatingMode {
  String get firestoreValue =>
      this == AppOperatingMode.commercial ? 'commercial' : 'free_beta';

  String get label =>
      this == AppOperatingMode.commercial ? 'Version payante' : 'Bêta gratuite';

  bool get isCommercial => this == AppOperatingMode.commercial;
}

class LegalPublisherProfile {
  final String publisherName;
  final String postalAddress;
  final String phone;
  final String email;
  final String publicationDirector;
  final String companyName;
  final String legalForm;
  final String siren;
  final String rcs;
  final String shareCapital;
  final String vatNumber;
  final String hostingProvider;
  final String hostingAddress;

  const LegalPublisherProfile({
    required this.publisherName,
    required this.postalAddress,
    required this.phone,
    required this.email,
    required this.publicationDirector,
    required this.companyName,
    required this.legalForm,
    required this.siren,
    required this.rcs,
    required this.shareCapital,
    required this.vatNumber,
    required this.hostingProvider,
    required this.hostingAddress,
  });

  const LegalPublisherProfile.defaults()
      : publisherName = const String.fromEnvironment('LEGAL_PUBLISHER_NAME'),
        postalAddress =
            const String.fromEnvironment('LEGAL_PUBLISHER_ADDRESS'),
        phone = const String.fromEnvironment('LEGAL_PUBLISHER_PHONE'),
        email = const String.fromEnvironment(
          'LEGAL_CONTACT_EMAIL',
          defaultValue: 'contact@ilipresto.fr',
        ),
        publicationDirector =
            const String.fromEnvironment('LEGAL_PUBLICATION_DIRECTOR'),
        companyName = const String.fromEnvironment('LEGAL_COMPANY_NAME'),
        legalForm = const String.fromEnvironment('LEGAL_COMPANY_FORM'),
        siren = const String.fromEnvironment('LEGAL_COMPANY_SIREN'),
        rcs = const String.fromEnvironment('LEGAL_COMPANY_RCS'),
        shareCapital =
            const String.fromEnvironment('LEGAL_COMPANY_CAPITAL'),
        vatNumber = const String.fromEnvironment('LEGAL_COMPANY_VAT'),
        hostingProvider = 'Google Ireland Limited (Firebase Hosting)',
        hostingAddress = 'Gordon House, Barrow Street, Dublin 4, Irlande';

  factory LegalPublisherProfile.fromMap(Map<String, dynamic>? data) {
    const defaults = LegalPublisherProfile.defaults();
    final map = data ?? const <String, dynamic>{};
    String read(String key, String fallback) {
      final value = (map[key] ?? '').toString().trim();
      return value.isEmpty ? fallback : value;
    }

    return LegalPublisherProfile(
      publisherName: read('publisherName', defaults.publisherName),
      postalAddress: read('postalAddress', defaults.postalAddress),
      phone: read('phone', defaults.phone),
      email: read('email', defaults.email),
      publicationDirector:
          read('publicationDirector', defaults.publicationDirector),
      companyName: read('companyName', defaults.companyName),
      legalForm: read('legalForm', defaults.legalForm),
      siren: read('siren', defaults.siren),
      rcs: read('rcs', defaults.rcs),
      shareCapital: read('shareCapital', defaults.shareCapital),
      vatNumber: read('vatNumber', defaults.vatNumber),
      hostingProvider: read('hostingProvider', defaults.hostingProvider),
      hostingAddress: read('hostingAddress', defaults.hostingAddress),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'publisherName': publisherName.trim(),
        'postalAddress': postalAddress.trim(),
        'phone': phone.trim(),
        'email': email.trim(),
        'publicationDirector': publicationDirector.trim(),
        'companyName': companyName.trim(),
        'legalForm': legalForm.trim(),
        'siren': siren.trim(),
        'rcs': rcs.trim(),
        'shareCapital': shareCapital.trim(),
        'vatNumber': vatNumber.trim(),
        'hostingProvider': hostingProvider.trim(),
        'hostingAddress': hostingAddress.trim(),
      };

  bool get isFreeBetaReady =>
      publisherName.trim().isNotEmpty &&
      postalAddress.trim().isNotEmpty &&
      phone.trim().isNotEmpty &&
      email.trim().isNotEmpty &&
      publicationDirector.trim().isNotEmpty;

  bool get isCommercialReady =>
      isFreeBetaReady &&
      companyName.trim().isNotEmpty &&
      legalForm.trim().isNotEmpty &&
      siren.trim().isNotEmpty;

  bool isReadyFor(AppOperatingMode mode) =>
      mode.isCommercial ? isCommercialReady : isFreeBetaReady;
}

class AppOperatingModeState {
  final AppOperatingMode mode;
  final LegalPublisherProfile publisher;
  final String legalVersion;
  final String cguVersion;
  final String privacyVersion;
  final DateTime effectiveDate;
  final bool requiresReacceptance;
  final DateTime? updatedAt;
  final String? updatedBy;

  const AppOperatingModeState({
    required this.mode,
    required this.publisher,
    required this.legalVersion,
    required this.cguVersion,
    required this.privacyVersion,
    required this.effectiveDate,
    required this.requiresReacceptance,
    this.updatedAt,
    this.updatedBy,
  });

  factory AppOperatingModeState.defaults() {
    return AppOperatingModeState(
      mode: AppOperatingMode.freeBeta,
      publisher: const LegalPublisherProfile.defaults(),
      legalVersion: 'beta-free-v1',
      cguVersion: 'cgu-beta-free-v1',
      privacyVersion: 'privacy-beta-free-v1',
      effectiveDate: DateTime.utc(2026, 7, 23),
      requiresReacceptance: false,
    );
  }

  factory AppOperatingModeState.fromMap(Map<String, dynamic>? data) {
    final defaults = AppOperatingModeState.defaults();
    final map = data ?? const <String, dynamic>{};
    final mode = appOperatingModeFromValue(map['operatingMode']);
    final effective = map['effectiveDate'];
    final updated = map['updatedAt'];
    String version(String key, String beta, String commercial) {
      final value = (map[key] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
      return mode.isCommercial ? commercial : beta;
    }

    return AppOperatingModeState(
      mode: mode,
      publisher: LegalPublisherProfile.fromMap(
        map['publisher'] is Map<String, dynamic>
            ? map['publisher'] as Map<String, dynamic>
            : null,
      ),
      legalVersion: version(
        'legalVersion',
        'beta-free-v1',
        'commercial-v1',
      ),
      cguVersion: version(
        'cguVersion',
        'cgu-beta-free-v1',
        'cgu-commercial-v1',
      ),
      privacyVersion: version(
        'privacyVersion',
        'privacy-beta-free-v1',
        'privacy-commercial-v1',
      ),
      effectiveDate: effective is Timestamp
          ? effective.toDate()
          : defaults.effectiveDate,
      requiresReacceptance: map['requiresReacceptance'] == true,
      updatedAt: updated is Timestamp ? updated.toDate() : null,
      updatedBy: (map['updatedBy'] as String?)?.trim(),
    );
  }

  bool get isPublicReady => publisher.isReadyFor(mode);
}

class AppOperatingModeService {
  AppOperatingModeService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _legalRef =>
      _firestore.collection('app_config').doc('legal');

  DocumentReference<Map<String, dynamic>> get _subscriptionsRef =>
      _firestore.collection('app_config').doc('subscriptions');

  DocumentReference<Map<String, dynamic>> get _publicLegalRef =>
      _firestore.collection('public_config').doc('legal');

  Map<String, dynamic> _publicPayload({
    required AppOperatingMode mode,
    required LegalPublisherProfile publisher,
    required String legalVersion,
    required String cguVersion,
    required String privacyVersion,
    required Object effectiveDate,
    required bool requiresReacceptance,
    required Object updatedAt,
  }) {
    return <String, dynamic>{
      'operatingMode': mode.firestoreValue,
      'legalVersion': legalVersion,
      'cguVersion': cguVersion,
      'privacyVersion': privacyVersion,
      'effectiveDate': effectiveDate,
      'requiresReacceptance': requiresReacceptance,
      'publisher': publisher.toMap(),
      'updatedAt': updatedAt,
    };
  }

  Stream<AppOperatingModeState> watchState({bool ensureExists = false}) {
    if (ensureExists) unawaited(ensureDefaults());
    return _legalRef.snapshots().map(
          (snapshot) => AppOperatingModeState.fromMap(snapshot.data()),
        );
  }

  Stream<AppOperatingModeState> watchPublicState() {
    return _publicLegalRef.snapshots().map(
          (snapshot) => AppOperatingModeState.fromMap(snapshot.data()),
        );
  }

  Future<AppOperatingModeState> getState() async {
    final snapshot = await _legalRef.get();
    return AppOperatingModeState.fromMap(snapshot.data());
  }

  Future<AppOperatingModeState> getPublicState() async {
    final snapshot = await _publicLegalRef.get();
    return AppOperatingModeState.fromMap(snapshot.data());
  }

  Future<void> ensureDefaults({String? updatedBy}) async {
    final results = await Future.wait([
      _legalRef.get(),
      _subscriptionsRef.get(),
      _publicLegalRef.get(),
    ]);
    final legal = results[0];
    final subscriptions = results[1];
    final publicLegal = results[2];
    final defaults = AppOperatingModeState.defaults();
    final state = legal.exists
        ? AppOperatingModeState.fromMap(legal.data())
        : defaults;
    final now = FieldValue.serverTimestamp();
    final batch = _firestore.batch();
    var hasWrites = false;

    if (!legal.exists) {
      batch.set(_legalRef, <String, dynamic>{
        'operatingMode': defaults.mode.firestoreValue,
        'legalVersion': defaults.legalVersion,
        'cguVersion': defaults.cguVersion,
        'privacyVersion': defaults.privacyVersion,
        'effectiveDate': Timestamp.fromDate(defaults.effectiveDate),
        'requiresReacceptance': false,
        'publisher': defaults.publisher.toMap(),
        'updatedAt': now,
        if ((updatedBy ?? '').trim().isNotEmpty)
          'updatedBy': updatedBy!.trim(),
      }, SetOptions(merge: true));
      hasWrites = true;
    }

    if (!subscriptions.exists) {
      batch.set(_subscriptionsRef, <String, dynamic>{
        'operatingMode': state.mode.firestoreValue,
        'subscriptionSectionEnabled': state.mode.isCommercial,
        'subscriptionsPrepared': true,
        'stripeEnabled': state.mode.isCommercial,
        'freeAccessMode': !state.mode.isCommercial,
        'legalDocumentVersion': state.legalVersion,
        'updatedAt': now,
        if ((updatedBy ?? '').trim().isNotEmpty)
          'updatedBy': updatedBy!.trim(),
      }, SetOptions(merge: true));
      hasWrites = true;
    }

    if (!publicLegal.exists) {
      batch.set(
        _publicLegalRef,
        _publicPayload(
          mode: state.mode,
          publisher: state.publisher,
          legalVersion: state.legalVersion,
          cguVersion: state.cguVersion,
          privacyVersion: state.privacyVersion,
          effectiveDate: Timestamp.fromDate(state.effectiveDate),
          requiresReacceptance: state.requiresReacceptance,
          updatedAt: now,
        ),
        SetOptions(merge: true),
      );
      hasWrites = true;
    }

    if (hasWrites) await batch.commit();
  }

  Future<void> updatePublisherProfile(
    LegalPublisherProfile profile, {
    String? updatedBy,
  }) async {
    final current = await getState();
    final now = FieldValue.serverTimestamp();
    final batch = _firestore.batch();
    batch.set(_legalRef, <String, dynamic>{
      'publisher': profile.toMap(),
      'updatedAt': now,
      if ((updatedBy ?? '').trim().isNotEmpty)
        'updatedBy': updatedBy!.trim(),
    }, SetOptions(merge: true));
    batch.set(
      _publicLegalRef,
      _publicPayload(
        mode: current.mode,
        publisher: profile,
        legalVersion: current.legalVersion,
        cguVersion: current.cguVersion,
        privacyVersion: current.privacyVersion,
        effectiveDate: Timestamp.fromDate(current.effectiveDate),
        requiresReacceptance: current.requiresReacceptance,
        updatedAt: now,
      ),
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Future<void> setMode(
    AppOperatingMode mode, {
    String? updatedBy,
  }) async {
    final current = await getState();
    if (!current.publisher.isReadyFor(mode)) {
      throw StateError(
        mode.isCommercial
            ? 'Complétez les informations de société avant d’activer la version payante.'
            : 'Complétez l’identité, l’adresse, le téléphone et le directeur de publication avant la mise en ligne.',
      );
    }

    final legalVersion =
        mode.isCommercial ? 'commercial-v1' : 'beta-free-v1';
    final cguVersion = mode.isCommercial
        ? 'cgu-commercial-v1'
        : 'cgu-beta-free-v1';
    final privacyVersion = mode.isCommercial
        ? 'privacy-commercial-v1'
        : 'privacy-beta-free-v1';
    final now = FieldValue.serverTimestamp();
    final batch = _firestore.batch();

    batch.set(_legalRef, <String, dynamic>{
      'operatingMode': mode.firestoreValue,
      'legalVersion': legalVersion,
      'cguVersion': cguVersion,
      'privacyVersion': privacyVersion,
      'effectiveDate': now,
      'requiresReacceptance': current.mode != mode,
      'updatedAt': now,
      if ((updatedBy ?? '').trim().isNotEmpty)
        'updatedBy': updatedBy!.trim(),
    }, SetOptions(merge: true));

    batch.set(_subscriptionsRef, <String, dynamic>{
      'operatingMode': mode.firestoreValue,
      'subscriptionSectionEnabled': mode.isCommercial,
      'subscriptionsPrepared': true,
      'stripeEnabled': mode.isCommercial,
      'freeAccessMode': !mode.isCommercial,
      'legalDocumentVersion': legalVersion,
      'updatedAt': now,
      if ((updatedBy ?? '').trim().isNotEmpty)
        'updatedBy': updatedBy!.trim(),
    }, SetOptions(merge: true));

    batch.set(
      _publicLegalRef,
      _publicPayload(
        mode: mode,
        publisher: current.publisher,
        legalVersion: legalVersion,
        cguVersion: cguVersion,
        privacyVersion: privacyVersion,
        effectiveDate: now,
        requiresReacceptance: current.mode != mode,
        updatedAt: now,
      ),
      SetOptions(merge: true),
    );

    final historyRef = _firestore.collection('legal_mode_history').doc();
    batch.set(historyRef, <String, dynamic>{
      'from': current.mode.firestoreValue,
      'to': mode.firestoreValue,
      'legalVersion': legalVersion,
      'changedAt': now,
      if ((updatedBy ?? '').trim().isNotEmpty)
        'changedBy': updatedBy!.trim(),
    });
    await batch.commit();
  }

  Future<void> recordAcceptance({
    required String userId,
    required AppOperatingModeState state,
    String source = 'registration',
  }) async {
    if (userId.trim().isEmpty) return;
    await _firestore.collection('users').doc(userId).set(<String, dynamic>{
      'legalAcceptance': <String, dynamic>{
        'operatingMode': state.mode.firestoreValue,
        'legalVersion': state.legalVersion,
        'cguVersion': state.cguVersion,
        'privacyVersion': state.privacyVersion,
        'acceptedAt': FieldValue.serverTimestamp(),
        'source': source,
      },
    }, SetOptions(merge: true));
  }
}
