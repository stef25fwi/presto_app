class LocalOrganization {
  const LocalOrganization({
    required this.id,
    required this.regionCode,
    required this.type,
    required this.name,
    required this.description,
    this.phone,
    this.email,
    this.website,
    this.address,
    this.services = const [],
    this.enabled = true,
  });

  final String id;
  final String regionCode;
  final String type;
  final String name;
  final String description;
  final String? phone;
  final String? email;
  final String? website;
  final String? address;
  final List<String> services;
  final bool enabled;

  bool get isCci => type == 'cci';
  bool get isCma => type == 'cma';
  bool get isRegion => type == 'region';
  bool get isFranceTravail => type == 'france_travail';
  bool get isFranceServices => type == 'france_services';

  factory LocalOrganization.fromMap(String id, Map<String, dynamic> data) {
    return LocalOrganization(
      id: id,
      regionCode: data['regionCode']?.toString() ?? '',
      type: data['type']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      phone: data['phone']?.toString(),
      email: data['email']?.toString(),
      website: data['website']?.toString(),
      address: data['address']?.toString(),
      services: List<String>.from(data['services'] ?? const []),
      enabled: data['enabled'] != false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'regionCode': regionCode,
      'type': type,
      'name': name,
      'description': description,
      'phone': phone,
      'email': email,
      'website': website,
      'address': address,
      'services': services,
      'enabled': enabled,
    };
  }
}
