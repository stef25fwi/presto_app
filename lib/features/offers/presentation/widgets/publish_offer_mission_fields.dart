import 'package:flutter/material.dart';

/// Délai et budget d'une offre.
class PublishOfferMissionFields extends StatelessWidget {
  const PublishOfferMissionFields({
    super.key,
    required this.delayLabel,
    required this.delayOptions,
    required this.selectedDelay,
    required this.onDelayChanged,
    required this.budgetTypes,
    required this.selectedBudgetType,
    required this.budgetController,
    required this.budgetLabel,
    required this.onBudgetTypeChanged,
    required this.budgetValidator,
    this.delayDecorator,
    this.budgetDecorator,
  });

  final Widget delayLabel;
  final List<String> delayOptions;
  final String? selectedDelay;
  final ValueChanged<String?> onDelayChanged;
  final List<String> budgetTypes;
  final String selectedBudgetType;
  final TextEditingController budgetController;
  final Widget budgetLabel;
  final ValueChanged<String> onBudgetTypeChanged;
  final FormFieldValidator<String> budgetValidator;
  final Widget Function(Widget child)? delayDecorator;
  final Widget Function(Widget child)? budgetDecorator;

  @override
  Widget build(BuildContext context) {
    final delayField = DropdownButtonFormField<String>(
      initialValue: selectedDelay,
      dropdownColor: Colors.white,
      borderRadius: BorderRadius.circular(14),
      decoration: InputDecoration(
        label: delayLabel,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
      ),
      items: delayOptions
          .map(
            (delay) => DropdownMenuItem<String>(
              value: delay,
              child: Text(delay),
            ),
          )
          .toList(growable: false),
      onChanged: onDelayChanged,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Merci de choisir un délai';
        }
        return null;
      },
    );

    final budgetFields = Row(
      children: [
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<String>(
            initialValue: selectedBudgetType,
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(14),
            decoration: InputDecoration(
              labelText: 'Type de budget',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
            ),
            items: budgetTypes
                .map(
                  (type) => DropdownMenuItem<String>(
                    value: type,
                    child: Text(type),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value != null) onBudgetTypeChanged(value);
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: TextFormField(
            controller: budgetController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              label: budgetLabel,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
            ),
            enabled: selectedBudgetType == 'Fixe',
            validator: budgetValidator,
          ),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        delayDecorator?.call(delayField) ?? delayField,
        const SizedBox(height: 16),
        budgetDecorator?.call(budgetFields) ?? budgetFields,
        const SizedBox(height: 24),
      ],
    );
  }
}
