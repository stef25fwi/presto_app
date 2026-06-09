class BusinessProjectTemplate {
  const BusinessProjectTemplate({
    required this.id,
    required this.projectType,
    required this.title,
    required this.category,
    this.defaultSteps = const [],
    this.requiredDocuments = const [],
    this.enabled = true,
  });

  final String id;
  final String projectType;
  final String title;
  final String category;
  final List<String> defaultSteps;
  final List<String> requiredDocuments;
  final bool enabled;

  factory BusinessProjectTemplate.fromMap(
      String id, Map<String, dynamic> data) {
    return BusinessProjectTemplate(
      id: id,
      projectType: data['projectType']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      category: data['category']?.toString() ?? '',
      defaultSteps: List<String>.from(data['defaultSteps'] ?? const []),
      requiredDocuments:
          List<String>.from(data['requiredDocuments'] ?? const []),
      enabled: data['enabled'] != false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'projectType': projectType,
      'title': title,
      'category': category,
      'defaultSteps': defaultSteps,
      'requiredDocuments': requiredDocuments,
      'enabled': enabled,
    };
  }
}
