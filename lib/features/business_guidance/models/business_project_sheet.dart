class BusinessProjectSheet {
  const BusinessProjectSheet({
    required this.id,
    required this.userId,
    required this.regionCode,
    required this.department,
    required this.city,
    required this.projectType,
    required this.title,
    required this.status,
    required this.summary,
    this.steps = const [],
    this.organizationIds = const [],
    this.publicAidIds = const [],
    this.checklist = const [],
    this.estimatedBudgetMin = 0,
    this.estimatedBudgetMax = 0,
  });

  final String id;
  final String userId;
  final String regionCode;
  final String department;
  final String city;
  final String projectType;
  final String title;
  final String status;
  final String summary;
  final List<String> steps;
  final List<String> organizationIds;
  final List<String> publicAidIds;
  final List<String> checklist;
  final int estimatedBudgetMin;
  final int estimatedBudgetMax;

  bool get isDraft => status == 'draft';
  bool get isPublished => status == 'published';
  bool get hasBudget => estimatedBudgetMin > 0 || estimatedBudgetMax > 0;
  bool get hasOrganizations => organizationIds.isNotEmpty;
  bool get hasPublicAids => publicAidIds.isNotEmpty;

  factory BusinessProjectSheet.fromMap(String id, Map<String, dynamic> data) {
    return BusinessProjectSheet(
      id: id,
      userId: data['userId']?.toString() ?? '',
      regionCode: data['regionCode']?.toString() ?? '',
      department: data['department']?.toString() ?? '',
      city: data['city']?.toString() ?? '',
      projectType: data['projectType']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      status: data['status']?.toString() ?? 'draft',
      summary: data['summary']?.toString() ?? '',
      steps: List<String>.from(data['steps'] ?? const []),
      organizationIds: List<String>.from(data['organizationIds'] ?? const []),
      publicAidIds: List<String>.from(data['publicAidIds'] ?? const []),
      checklist: List<String>.from(data['checklist'] ?? const []),
      estimatedBudgetMin:
          int.tryParse('${data['estimatedBudgetMin'] ?? 0}') ?? 0,
      estimatedBudgetMax:
          int.tryParse('${data['estimatedBudgetMax'] ?? 0}') ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'regionCode': regionCode,
      'department': department,
      'city': city,
      'projectType': projectType,
      'title': title,
      'status': status,
      'summary': summary,
      'steps': steps,
      'organizationIds': organizationIds,
      'publicAidIds': publicAidIds,
      'checklist': checklist,
      'estimatedBudgetMin': estimatedBudgetMin,
      'estimatedBudgetMax': estimatedBudgetMax,
    };
  }
}
