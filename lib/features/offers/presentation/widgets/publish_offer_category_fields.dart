import 'package:flutter/material.dart';

typedef PublishFieldDecorator = Widget Function(Widget child);

/// Champs catégorie et sous-catégorie de la publication.
///
/// Le composant ne possède aucune logique Firebase et ne modifie pas l'état :
/// il transmet uniquement les choix à la page orchestratrice.
class PublishOfferCategoryFields extends StatelessWidget {
  const PublishOfferCategoryFields({
    super.key,
    required this.categoryLabel,
    required this.categories,
    required this.subcategories,
    required this.selectedCategory,
    required this.selectedSubcategory,
    required this.onCategoryChanged,
    required this.onSubcategoryChanged,
    this.categoryDecorator,
  });

  final Widget categoryLabel;
  final List<String> categories;
  final List<String> subcategories;
  final String? selectedCategory;
  final String? selectedSubcategory;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onSubcategoryChanged;
  final PublishFieldDecorator? categoryDecorator;

  @override
  Widget build(BuildContext context) {
    final categoryField = DropdownButtonFormField<String>(
      initialValue: selectedCategory,
      dropdownColor: Colors.white,
      borderRadius: BorderRadius.circular(14),
      decoration: InputDecoration(
        label: categoryLabel,
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
      items: categories
          .map(
            (category) => DropdownMenuItem<String>(
              value: category,
              child: Text(category),
            ),
          )
          .toList(growable: false),
      onChanged: onCategoryChanged,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Merci de choisir une catégorie';
        }
        return null;
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        categoryDecorator?.call(categoryField) ?? categoryField,
        const SizedBox(height: 16),
        if (selectedCategory != null) ...[
          DropdownButtonFormField<String>(
            initialValue: selectedSubcategory,
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(14),
            decoration: InputDecoration(
              labelText: 'Sous-catégorie',
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
            items: subcategories
                .map(
                  (subcategory) => DropdownMenuItem<String>(
                    value: subcategory,
                    child: Text(subcategory),
                  ),
                )
                .toList(growable: false),
            onChanged: onSubcategoryChanged,
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}
