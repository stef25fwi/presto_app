abstract final class PublishOfferFormPolicy {
  static PublishOfferFormReadiness evaluate(PublishOfferFormInput input) {
    final issues = <PublishOfferValidationIssue>[];

    void requireText(
      PublishOfferFieldId fieldId,
      String value,
      String message,
    ) {
      if (value.trim().isEmpty) {
        issues.add(PublishOfferValidationIssue(fieldId, message));
      }
    }

    requireText(
      PublishOfferFieldId.title,
      input.title,
      'Le titre est obligatoire.',
    );
    requireText(
      PublishOfferFieldId.description,
      input.description,
      'La description est obligatoire.',
    );
    requireText(
      PublishOfferFieldId.category,
      input.category ?? '',
      'La catégorie est obligatoire.',
    );
    requireText(
      PublishOfferFieldId.location,
      input.location,
      'La ville est obligatoire.',
    );
    requireText(
      PublishOfferFieldId.phone,
      input.phone,
      'Le téléphone est obligatoire.',
    );
    requireText(
      PublishOfferFieldId.missionDelay,
      input.missionDelay ?? '',
      'Le délai est obligatoire.',
    );

    final budgetType = normalizeBudgetType(input.budgetType);
    final budgetAmount = parseBudgetAmount(input.budget);
    final isNegotiated = budgetType == PublishOfferBudgetType.negotiated;

    if (!isNegotiated && input.budget.trim().isEmpty) {
      issues.add(
        const PublishOfferValidationIssue(
          PublishOfferFieldId.budget,
          'Le budget est obligatoire.',
        ),
      );
    } else if (input.budget.trim().isNotEmpty && budgetAmount == null) {
      issues.add(
        const PublishOfferValidationIssue(
          PublishOfferFieldId.budget,
          'Le budget doit être un montant positif.',
        ),
      );
    }

    return PublishOfferFormReadiness(
      isValid: issues.isEmpty,
      issues: List.unmodifiable(issues),
      firstInvalidFieldId: issues.isEmpty ? null : issues.first.fieldId,
      budgetType: budgetType,
      parsedBudgetAmount: budgetAmount,
      normalizedBudgetValue: normalizeBudgetValue(input.budget),
    );
  }

  static bool canPublish(PublishOfferFormInput input) => evaluate(input).isValid;

  static PublishOfferBudgetType normalizeBudgetType(String budgetType) {
    final normalized = budgetType.trim().toLowerCase();
    if (normalized == 'à négocier' ||
        normalized == 'a negocier' ||
        normalized == 'negotiated' ||
        normalized == 'negocie') {
      return PublishOfferBudgetType.negotiated;
    }
    return PublishOfferBudgetType.fixed;
  }

  static double? parseBudgetAmount(String raw) {
    final normalized = normalizeBudgetValue(raw);
    if (normalized.isEmpty) return null;
    final amount = double.tryParse(normalized);
    if (amount == null || amount <= 0) return null;
    return amount;
  }

  static String normalizeBudgetValue(String raw) {
    return raw
        .trim()
        .replaceAll('€', '')
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(',', '.');
  }
}

class PublishOfferFormInput {
  const PublishOfferFormInput({
    required this.title,
    required this.description,
    required this.location,
    required this.phone,
    required this.budget,
    required this.budgetType,
    this.category,
    this.missionDelay,
  });

  final String title;
  final String description;
  final String location;
  final String phone;
  final String budget;
  final String budgetType;
  final String? category;
  final String? missionDelay;
}

class PublishOfferFormReadiness {
  const PublishOfferFormReadiness({
    required this.isValid,
    required this.issues,
    required this.budgetType,
    required this.parsedBudgetAmount,
    required this.normalizedBudgetValue,
    this.firstInvalidFieldId,
  });

  final bool isValid;
  final List<PublishOfferValidationIssue> issues;
  final PublishOfferFieldId? firstInvalidFieldId;
  final PublishOfferBudgetType budgetType;
  final double? parsedBudgetAmount;
  final String normalizedBudgetValue;
}

class PublishOfferValidationIssue {
  const PublishOfferValidationIssue(this.fieldId, this.message);

  final PublishOfferFieldId fieldId;
  final String message;
}

enum PublishOfferFieldId {
  title,
  description,
  category,
  location,
  phone,
  missionDelay,
  budget,
}

enum PublishOfferBudgetType { fixed, negotiated }
