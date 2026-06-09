import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/business_project_sheet.dart';
import '../models/business_project_template.dart';
import '../models/business_region.dart';
import '../models/local_organization.dart';
import '../models/public_aid.dart';

class BusinessGuidanceService {
  BusinessGuidanceService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _regions =>
      _firestore.collection('business_regions');

  CollectionReference<Map<String, dynamic>> get _organizations =>
      _firestore.collection('local_organizations');

  CollectionReference<Map<String, dynamic>> get _publicAids =>
      _firestore.collection('public_aids');

  CollectionReference<Map<String, dynamic>> get _projectTemplates =>
      _firestore.collection('business_project_templates');

  CollectionReference<Map<String, dynamic>> get _projectSheets =>
      _firestore.collection('business_project_sheets');

  Stream<List<BusinessRegion>> watchRegions() {
    return _regions.where('enabled', isEqualTo: true).snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => BusinessRegion.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<BusinessRegion?> getRegion(String regionCode) async {
    final snapshot = await _regions.doc(regionCode).get();
    final data = snapshot.data();
    if (data == null) return null;
    return BusinessRegion.fromMap(snapshot.id, data);
  }

  Stream<List<LocalOrganization>> watchOrganizationsForRegion(
    String regionCode,
  ) {
    return _organizations
        .where('regionCode', isEqualTo: regionCode)
        .where('enabled', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => LocalOrganization.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<List<LocalOrganization>> getOrganizationsForRegion(
    String regionCode,
  ) async {
    final snapshot = await _organizations
        .where('regionCode', isEqualTo: regionCode)
        .where('enabled', isEqualTo: true)
        .get();

    return snapshot.docs
        .map((doc) => LocalOrganization.fromMap(doc.id, doc.data()))
        .toList();
  }

  Stream<List<PublicAid>> watchPublicAidsForRegion(String regionCode) {
    return _publicAids
        .where('regionCode', isEqualTo: regionCode)
        .where('enabled', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PublicAid.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<List<PublicAid>> getPublicAidsForRegion(String regionCode) async {
    final snapshot = await _publicAids
        .where('regionCode', isEqualTo: regionCode)
        .where('enabled', isEqualTo: true)
        .get();

    return snapshot.docs
        .map((doc) => PublicAid.fromMap(doc.id, doc.data()))
        .toList();
  }

  Stream<List<BusinessProjectTemplate>> watchProjectTemplates() {
    return _projectTemplates.where('enabled', isEqualTo: true).snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => BusinessProjectTemplate.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<BusinessProjectTemplate?> getProjectTemplate(String templateId) async {
    final snapshot = await _projectTemplates.doc(templateId).get();
    final data = snapshot.data();
    if (data == null) return null;
    return BusinessProjectTemplate.fromMap(snapshot.id, data);
  }

  Stream<List<BusinessProjectSheet>> watchUserProjectSheets(String userId) {
    return _projectSheets
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => BusinessProjectSheet.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<BusinessProjectSheet?> getProjectSheet(String sheetId) async {
    final snapshot = await _projectSheets.doc(sheetId).get();
    final data = snapshot.data();
    if (data == null) return null;
    return BusinessProjectSheet.fromMap(snapshot.id, data);
  }

  Future<String> createProjectSheet({
    required String userId,
    required String regionCode,
    required String department,
    required String city,
    required String projectType,
    required String title,
    required String summary,
  }) async {
    final organizations = await getOrganizationsForRegion(regionCode);
    final publicAids = await getPublicAidsForRegion(regionCode);

    final doc = _projectSheets.doc();

    await doc.set({
      'userId': userId,
      'regionCode': regionCode,
      'department': department,
      'city': city,
      'projectType': projectType,
      'title': title,
      'status': 'draft',
      'summary': summary,
      'steps': <String>[
        'Définir précisément le projet',
        'Choisir le statut juridique adapté',
        'Vérifier les autorisations nécessaires',
        'Contacter les organismes locaux',
        'Identifier les aides publiques possibles',
        'Préparer le budget prévisionnel',
        'Créer les documents administratifs',
      ],
      'organizationIds': organizations.map((org) => org.id).toList(),
      'publicAidIds': publicAids.map((aid) => aid.id).toList(),
      'checklist': <String>[
        'Pièce d’identité',
        'Justificatif de domicile',
        'Description du projet',
        'Budget estimatif',
        'Liste du matériel nécessaire',
        'Assurance professionnelle à vérifier',
      ],
      'estimatedBudgetMin': 0,
      'estimatedBudgetMax': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }

  Future<void> updateProjectSheet(BusinessProjectSheet sheet) async {
    await _projectSheets.doc(sheet.id).set(
      {
        ...sheet.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> deleteProjectSheet(String sheetId) async {
    await _projectSheets.doc(sheetId).delete();
  }
}
