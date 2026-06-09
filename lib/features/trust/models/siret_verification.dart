class SiretVerification {
  const SiretVerification({
    required this.id,
    required this.userId,
    required this.siret,
    required this.status,
    this.businessName,
    this.activityLabel,
    this.region,
    this.department,
    this.city,
    this.source,
    this.adminNote,
  });

  final String id;
  final String userId;
  final String siret;
  final String status;
  final String? businessName;
  final String? activityLabel;
  final String? region;
  final String? department;
  final String? city;
  final String? source;
  final String? adminNote;

  bool get isValid => status == 'valide';
  bool get isPending => status == 'en_attente';
  bool get isRejected => status == 'invalide';
  bool get needsReview => status == 'a_revoir';

  factory SiretVerification.fromMap(String id, Map<String, dynamic> data) {
    return SiretVerification(
      id: id,
      userId: data['userId']?.toString() ?? '',
      siret: data['siret']?.toString() ?? '',
      status: data['status']?.toString() ?? 'non_renseigne',
      businessName: data['businessName']?.toString(),
      activityLabel: data['activityLabel']?.toString(),
      region: data['region']?.toString(),
      department: data['department']?.toString(),
      city: data['city']?.toString(),
      source: data['source']?.toString(),
      adminNote: data['adminNote']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'siret': siret,
      'status': status,
      'businessName': businessName,
      'activityLabel': activityLabel,
      'region': region,
      'department': department,
      'city': city,
      'source': source,
      'adminNote': adminNote,
    };
  }
}
