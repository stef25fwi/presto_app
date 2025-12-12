import 'package:presto_app/constants.dart';

void main() {
  final nameToCodes = <String, List<String>>{};
  for (final entry in kDepartments.entries) {
    nameToCodes.putIfAbsent(entry.value, () => []).add(entry.key);
  }

  final duplicateNames = nameToCodes.entries
      .where((e) => e.value.length > 1)
      .toList()
    ..sort((a, b) => a.key.compareTo(b.key));

  final deptToRegions = <String, List<String>>{};
  for (final entry in kRegionDepartments.entries) {
    final regionCode = entry.key;
    for (final deptCode in entry.value) {
      deptToRegions.putIfAbsent(deptCode, () => []).add(regionCode);
    }
  }

  final duplicatedDeptAssignments = deptToRegions.entries
      .where((e) => e.value.length > 1)
      .toList()
    ..sort((a, b) => a.key.compareTo(b.key));

  final missingInDepartments = deptToRegions.keys
      .where((dept) => !kDepartments.containsKey(dept))
      .toList()
    ..sort();

  final notInAnyRegion = kDepartments.keys
      .where((dept) => !deptToRegions.containsKey(dept))
      .toList()
    ..sort();

  print('=== kDepartments: doublons de libellés ===');
  if (duplicateNames.isEmpty) {
    print('OK: aucun libellé de département dupliqué.');
  } else {
    for (final e in duplicateNames) {
      print('- "${e.key}": ${e.value.join(", ")}');
    }
  }

  print('\n=== kRegionDepartments: départements dans plusieurs régions ===');
  if (duplicatedDeptAssignments.isEmpty) {
    print('OK: aucun département présent dans plusieurs régions.');
  } else {
    for (final e in duplicatedDeptAssignments) {
      print('- ${e.key}: régions ${e.value.join(", ")}');
    }
  }

  print('\n=== Cohérence: dept présents en régions mais absents de kDepartments ===');
  if (missingInDepartments.isEmpty) {
    print('OK: tous les départements référencés ont un libellé.');
  } else {
    print('ATTENTION: ${missingInDepartments.join(", ")}');
  }

  print('\n=== Cohérence: dept dans kDepartments mais absent de kRegionDepartments ===');
  if (notInAnyRegion.isEmpty) {
    print('OK: tous les départements ont une région.');
  } else {
    print('ATTENTION: ${notInAnyRegion.join(", ")}');
  }
}
