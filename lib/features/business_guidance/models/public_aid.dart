class PublicAid {
  const PublicAid({
    required this.id,
    required this.regionCode,
    required this.title,
    required this.provider,
    required this.description,
    this.eligibility = const [],
    this.link,
    this.contactOrganizationId,
    this.enabled = true,
  });

  final String id;
  final String regionCode;
  final String title;
  final String provider;
  final String description;
  final List<String> eligibility;
  final String? link;
  final String? contactOrganizationId;
  final bool enabled;

  bool get hasLink => link != null && link!.trim().isNotEmpty;
  bool get hasContact =>
      contactOrganizationId != null && contactOrganizationId!.trim().isNotEmpty;

  factory PublicAid.fromMap(String id, Map<String, dynamic> data) {
    return PublicAid(
      id: id,
      regionCode: data['regionCode']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      provider: data['provider']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      eligibility: List<String>.from(data['eligibility'] ?? const []),
      link: data['link']?.toString(),
      contactOrganizationId: data['contactOrganizationId']?.toString(),
      enabled: data['enabled'] != false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'regionCode': regionCode,
      'title': title,
      'provider': provider,
      'description': description,
      'eligibility': eligibility,
      'link': link,
      'contactOrganizationId': contactOrganizationId,
      'enabled': enabled,
    };
  }
}
