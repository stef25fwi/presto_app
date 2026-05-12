import 'package:flutter/material.dart';

import '../services/city_search.dart';
import 'phone_input_field.dart';

const double _kAccountSectionTileHorizontalPadding = 10;

class AccountProfileFormSection extends StatefulWidget {
  final TextEditingController pseudoController;
  final TextEditingController cityController;
  final TextEditingController phoneController;
  final String phoneCountryCode;
  final bool isEditing;
  final bool isSaving;
  final VoidCallback onStartEditing;
  final Future<void> Function() onSave;
  final ValueChanged<String> onPhoneCountryCodeChanged;

  const AccountProfileFormSection({
    super.key,
    required this.pseudoController,
    required this.cityController,
    required this.phoneController,
    required this.phoneCountryCode,
    required this.isEditing,
    required this.isSaving,
    required this.onStartEditing,
    required this.onSave,
    required this.onPhoneCountryCodeChanged,
  });

  @override
  State<AccountProfileFormSection> createState() =>
      _AccountProfileFormSectionState();
}

class _AccountProfileFormSectionState extends State<AccountProfileFormSection> {
  String _countryCodeForDept(String dept) {
    if (dept.startsWith('971')) return '+590';
    if (dept.startsWith('972')) return '+596';
    if (dept.startsWith('973')) return '+594';
    if (dept.startsWith('974')) return '+262';
    if (dept.startsWith('976')) return '+262';
    if (dept.startsWith('987')) return '+689';
    return '+33';
  }

  String? _extractPostalCodeFromCityValue(String value) {
    final match = RegExp(r'\b(97\d{3}|98\d{3}|\d{5})\b').firstMatch(value);
    return match?.group(1);
  }

  void _syncPhoneCountryCodeFromCityValue(String value) {
    final trimmed = value.trim();
    String? dept;

    final postalCode = _extractPostalCodeFromCityValue(trimmed);
    if (postalCode != null && postalCode.isNotEmpty) {
      dept = (postalCode.startsWith('97') || postalCode.startsWith('98'))
          ? postalCode.substring(0, 3)
          : postalCode.substring(0, 2);
    } else if (trimmed.length >= 2) {
      final sanitizedCity = trimmed.replaceAll(RegExp(r'\(.*?\)'), '').trim();
      if (sanitizedCity.length >= 2) {
        final matches = CitySearch.instance.search(sanitizedCity, limit: 1);
        if (matches.isNotEmpty) {
          dept = matches.first.dept;
        }
      }
    }

    final nextCode = _countryCodeForDept(dept ?? '');
    if (nextCode != widget.phoneCountryCode) {
      widget.onPhoneCountryCodeChanged(nextCode);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Mon profil',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: _kAccountSectionTileHorizontalPadding,
            vertical: 14,
          ),
          child: Column(
            children: [
              TextField(
                controller: widget.pseudoController,
                enabled: widget.isEditing,
                decoration: InputDecoration(
                  labelText: 'Pseudo',
                  hintText: 'Ex : DJ Heat, Stef971...',
                  filled: !widget.isEditing,
                  fillColor: !widget.isEditing ? Colors.grey.shade100 : null,
                ),
              ),
              const SizedBox(height: 10),
              AbsorbPointer(
                absorbing: !widget.isEditing,
                child: Opacity(
                  opacity: widget.isEditing ? 1.0 : 0.6,
                  child: Autocomplete<CityRecord>(
                    displayStringForOption: (city) =>
                        '${city.name} (${city.cp})',
                    optionsBuilder: (TextEditingValue value) {
                      final query = value.text.trim();
                      if (query.length < 2) {
                        return const Iterable<CityRecord>.empty();
                      }
                      return CitySearch.instance.search(query, limit: 10);
                    },
                    onSelected: (CityRecord city) {
                      final nextValue = '${city.name} (${city.cp})';
                      widget.cityController.text = nextValue;
                      _syncPhoneCountryCodeFromCityValue(nextValue);
                    },
                    fieldViewBuilder: (
                      context,
                      textController,
                      focusNode,
                      onFieldSubmitted,
                    ) {
                      if (widget.cityController.text.isNotEmpty &&
                          textController.text != widget.cityController.text) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          if (textController.text !=
                              widget.cityController.text) {
                            textController.text = widget.cityController.text;
                          }
                        });
                      }

                      return TextField(
                        controller: textController,
                        focusNode: focusNode,
                        enabled: widget.isEditing,
                        decoration: InputDecoration(
                          labelText: 'Ville',
                          hintText: 'Ex : Baie-Mahault',
                          filled: !widget.isEditing,
                          fillColor:
                              !widget.isEditing ? Colors.grey.shade100 : null,
                        ),
                        onChanged: (value) {
                          widget.cityController.text = value;
                          _syncPhoneCountryCodeFromCityValue(value);
                        },
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4.0,
                          child: Container(
                            constraints: const BoxConstraints(maxHeight: 200),
                            width: MediaQuery.of(context).size.width - 80,
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (context, index) {
                                final city = options.elementAt(index);
                                return ListTile(
                                  dense: true,
                                  title: Text('${city.name} (${city.cp})'),
                                  subtitle: Text('Dept ${city.dept}'),
                                  onTap: () => onSelected(city),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),
              AbsorbPointer(
                absorbing: !widget.isEditing,
                child: Opacity(
                  opacity: widget.isEditing ? 1.0 : 0.6,
                  child: PhoneInputFieldCompact(
                    controller: widget.phoneController,
                    labelText: 'Téléphone',
                    hintText: phoneHintForCountryCode(widget.phoneCountryCode),
                    initialCountryCode: widget.phoneCountryCode,
                    onCountryCodeChanged: widget.onPhoneCountryCodeChanged,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.isEditing
                        ? const Color(0xFFFF6600)
                        : const Color(0xFF1A73E8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: widget.isSaving
                      ? null
                      : () async {
                          if (widget.isEditing) {
                            await widget.onSave();
                          } else {
                            widget.onStartEditing();
                          }
                        },
                  icon: widget.isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Icon(
                          widget.isEditing
                              ? Icons.save_outlined
                              : Icons.edit_outlined,
                        ),
                  label: Text(
                    widget.isSaving
                        ? 'Enregistrement...'
                        : widget.isEditing
                            ? 'Enregistrer mon profil'
                            : 'Modifier mon profil',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class AccountFavoriteCategoriesSection extends StatelessWidget {
  final int categoriesCount;
  final int subcategoriesCount;
  final List<String> selectedCategories;
  final List<String> selectedSubcategories;
  final bool isSaving;
  final bool showTitle;
  final VoidCallback onOpenCategoryPicker;
  final VoidCallback onOpenSubcategoryPicker;
  final VoidCallback onApply;

  const AccountFavoriteCategoriesSection({
    super.key,
    required this.categoriesCount,
    required this.subcategoriesCount,
    required this.selectedCategories,
    required this.selectedSubcategories,
    required this.isSaving,
    this.showTitle = true,
    required this.onOpenCategoryPicker,
    required this.onOpenSubcategoryPicker,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final hasSelections =
        selectedCategories.isNotEmpty || selectedSubcategories.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTitle)
          const Text(
            'Mes alertes "Nouvelle annonce"',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        if (showTitle) const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: _kAccountSectionTileHorizontalPadding,
            vertical: 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sélectionne les catégories pour lesquelles tu veux être notifié quand une nouvelle annonce est publiée.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 10),
              if (hasSelections) ...[
                const Text(
                  'Alertes paramétrées',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...selectedCategories.map(
                      (category) => Chip(
                        label: Text(category),
                        backgroundColor: const Color(0xFFFFF3E8),
                        side: const BorderSide(color: Color(0xFFFFD3B0)),
                        labelStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFB85C00),
                        ),
                      ),
                    ),
                    ...selectedSubcategories.map(
                      (subcategory) => Chip(
                        label: Text(subcategory),
                        backgroundColor: const Color(0xFFEFF5FF),
                        side: const BorderSide(color: Color(0xFFCFE0FF)),
                        labelStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A4EA1),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              InkWell(
                onTap: onOpenCategoryPicker,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Catégories',
                    filled: true,
                    fillColor: const Color(0xFFF9F9F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          categoriesCount == 0
                              ? 'Choisir des catégories'
                              : '$categoriesCount catégorie(s) sélectionnée(s)',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.black54,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: onOpenSubcategoryPicker,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Sous-catégories',
                    filled: true,
                    fillColor: const Color(0xFFF9F9F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          subcategoriesCount == 0
                              ? 'Choisir des sous-catégories'
                              : '$subcategoriesCount sous-catégorie(s) sélectionnée(s)',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.black54,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A73E8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: isSaving ? null : onApply,
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Valider mes alertes',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class AccountMessagesSection extends StatelessWidget {
  final VoidCallback onOpenMessages;
  final bool showTitle;

  const AccountMessagesSection({
    super.key,
    required this.onOpenMessages,
    this.showTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTitle)
          const Text(
            'Mes messages',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        if (showTitle) const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: _kAccountSectionTileHorizontalPadding,
            vertical: 14,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Retrouve toutes les conversations liées à tes offres ou aux offres auxquelles tu as répondu.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onOpenMessages,
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text(
                    'Ouvrir mes messages',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class AccountProUpgradeSection extends StatelessWidget {
  final VoidCallback onOpenProProfile;

  const AccountProUpgradeSection({
    super.key,
    required this.onOpenProProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: _kAccountSectionTileHorizontalPadding,
        vertical: 18,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF6600).withOpacity(0.15),
            const Color(0xFF1A73E8).withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFF6600).withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6600).withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6600),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.business_center,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Vous êtes une entreprise ?',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Créez un profil Pro pour publier plus facilement. Les options d\'abonnement avancées arrivent bientôt.',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6600),
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onOpenProProfile,
              icon: const Icon(Icons.business_center_outlined, size: 20),
              label: const Text(
                'Créer mon profil Pro',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
