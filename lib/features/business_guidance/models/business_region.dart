class BusinessRegion {
  const BusinessRegion({
    required this.regionCode,
    required this.name,
    required this.departments,
    this.defaultCciId,
    this.defaultRegionOrgId,
    this.enabled = true,
  });

  final String regionCode;
  final String name;
  final List<String> departments;
  final String? defaultCciId;
  final String? defaultRegionOrgId;
  final bool enabled;

  factory BusinessRegion.fromMap(String regionCode, Map<String, dynamic> data) {
    return BusinessRegion(
      regionCode: regionCode,
      name: data['name']?.toString() ?? '',
      departments: List<String>.from(data['departments'] ?? const []),
      defaultCciId: data['defaultCciId']?.toString(),
      defaultRegionOrgId: data['defaultRegionOrgId']?.toString(),
      enabled: data['enabled'] != false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'regionCode': regionCode,
      'name': name,
      'departments': departments,
      'defaultCciId': defaultCciId,
      'defaultRegionOrgId': defaultRegionOrgId,
      'enabled': enabled,
    };
  }
}
