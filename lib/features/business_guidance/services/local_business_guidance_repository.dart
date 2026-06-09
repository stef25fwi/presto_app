import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/business_project_template.dart';
import '../models/business_region.dart';
import '../models/local_organization.dart';
import '../models/public_aid.dart';
import '../utils/region_normalizer.dart';

class LocalBusinessGuidanceRepository {
  const LocalBusinessGuidanceRepository();

  static const String _localResourcesPath =
      'assets/data/business_guidance/local_resources.seed.json';

  Future<Map<String, dynamic>> _loadLocalResources() async {
    final raw = await rootBundle.loadString(_localResourcesPath);
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<List<BusinessRegion>> getRegions() async {
    final data = await _loadLocalResources();
    final items = List<Map<String, dynamic>>.from(data['regions'] ?? const []);

    return items
        .map((item) {
          final code = item['regionCode']?.toString() ?? '';
          return BusinessRegion.fromMap(code, item);
        })
        .where((region) => region.enabled)
        .toList();
  }

  Future<BusinessRegion?> getRegionByCode(String regionCode) async {
    final normalizedCode = RegionNormalizer.normalize(regionCode);
    final regions = await getRegions();

    for (final region in regions) {
      if (region.regionCode == normalizedCode) {
        return region;
      }
    }

    return null;
  }

  Future<String> resolveRegionCode({
    String? region,
    String? departmentCode,
  }) async {
    if (region != null && region.trim().isNotEmpty) {
      final normalized = RegionNormalizer.normalize(region);
      final found = await getRegionByCode(normalized);
      if (found != null) return found.regionCode;
    }

    if (departmentCode != null && departmentCode.trim().isNotEmpty) {
      return RegionNormalizer.regionCodeFromDepartment(departmentCode);
    }

    return '';
  }

  Future<List<LocalOrganization>> getOrganizationsForRegion(
    String regionCode,
  ) async {
    final normalizedCode = RegionNormalizer.normalize(regionCode);
    final data = await _loadLocalResources();
    final items =
        List<Map<String, dynamic>>.from(data['organizations'] ?? const []);

    return items
        .map((item) =>
            LocalOrganization.fromMap(item['id']?.toString() ?? '', item))
        .where((item) => item.enabled && item.regionCode == normalizedCode)
        .toList();
  }

  Future<List<PublicAid>> getPublicAidsForRegion(String regionCode) async {
    final normalizedCode = RegionNormalizer.normalize(regionCode);
    final data = await _loadLocalResources();
    final items =
        List<Map<String, dynamic>>.from(data['publicAids'] ?? const []);

    return items
        .map((item) => PublicAid.fromMap(item['id']?.toString() ?? '', item))
        .where((item) => item.enabled && item.regionCode == normalizedCode)
        .toList();
  }

  Future<List<BusinessProjectTemplate>> getProjectTemplates() async {
    final data = await _loadLocalResources();
    final items =
        List<Map<String, dynamic>>.from(data['projectTemplates'] ?? const []);

    return items
        .map(
          (item) => BusinessProjectTemplate.fromMap(
            item['id']?.toString() ?? '',
            item,
          ),
        )
        .where((item) => item.enabled)
        .toList();
  }
}
