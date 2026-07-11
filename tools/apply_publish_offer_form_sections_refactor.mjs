import fs from 'node:fs';

const path = 'lib/pages/publish_offer_page.dart';
let text = fs.readFileSync(path, 'utf8');

const importAnchor =
  "import '../features/offers/presentation/widgets/publish_offer_photos_section.dart';\n";
const imports = [
  "import '../features/offers/presentation/widgets/publish_offer_category_fields.dart';\n",
  "import '../features/offers/presentation/widgets/publish_offer_contact_fields.dart';\n",
  "import '../features/offers/presentation/widgets/publish_offer_mission_fields.dart';\n",
];

if (!text.includes(importAnchor)) {
  throw new Error('publish offer photos import anchor not found');
}

let importBlock = importAnchor;
for (const entry of imports) {
  if (!text.includes(entry)) importBlock += entry;
}
text = text.replace(importAnchor, importBlock);

function replaceBetween(startMarker, endMarker, replacement) {
  const start = text.indexOf(startMarker);
  const end = text.indexOf(endMarker, start + startMarker.length);
  if (start < 0 || end < 0 || start >= end) {
    throw new Error(`section anchors not found: ${startMarker.trim()}`);
  }
  text = text.slice(0, start) + replacement + text.slice(end);
}

if (!text.includes('PublishOfferCategoryFields(')) {
  replaceBetween(
    '                          // CATÉGORIE\n',
    '                          // PHOTOS\n',
    `                          PublishOfferCategoryFields(
                            categoryLabel: _requiredLabel('Catégorie'),
                            categories: _categories,
                            subcategories: _category == null
                                ? const <String>[]
                                : (kCategorySubcategories[_category] ??
                                    const <String>[]),
                            selectedCategory: _category,
                            selectedSubcategory: _selectedSubCategory,
                            categoryDecorator: (child) =>
                                _withPublishFieldHighlight(
                              fieldId: 'category',
                              child: _withAiPendingOverlay(
                                showPending: _showAiPendingForCategory,
                                child: child,
                              ),
                            ),
                            onCategoryChanged: (value) {
                              setState(() {
                                _categoryEditedByUser = true;
                                _category = value;
                                _selectedSubCategory = null;
                              });
                              _recompute();
                            },
                            onSubcategoryChanged: (value) {
                              setState(() {
                                _selectedSubCategory = value;
                              });
                              _recompute();
                            },
                          ),

`,
  );
}

if (!text.includes('PublishOfferLocationFields(')) {
  replaceBetween(
    '                          // VILLE + CP + AUTOCOMPLÉTION\n',
    '                          // DÉLAI POUR EFFECTUER LA MISSION\n',
    `                          PublishOfferLocationFields(
                            cityController: _locationController,
                            postalCodeController: _postalCodeController,
                            cityLabel: _requiredLabel('Ville'),
                            cityDecorator: (child) =>
                                _withPublishFieldHighlight(
                              fieldId: 'city',
                              child: _withAiPendingOverlay(
                                showPending: _showAiPendingForController(
                                  _locationController,
                                ),
                                child: child,
                              ),
                            ),
                            postalDecorator: (child) => _withAiPendingOverlay(
                              showPending: _showAiPendingForController(
                                _postalCodeController,
                              ),
                              child: child,
                            ),
                            onCitySelected: (city) {
                              setState(() {
                                _selectedDeptCode = city.dept;
                                _selectedRegionCode = null;
                                _selectedPhoneCountryCode =
                                    _countryCodeForDept(city.dept);
                                _locationEditedByUser = true;
                                _postalCodeEditedByUser = true;
                              });
                            },
                            onPostalTap:
                                _clearAiPrefilledLocationPostalOnUserTap,
                            onPostalEditingComplete:
                                _canonicalizeLocationInputs,
                            postalValidator: _validatePostalCode,
                          ),
                          PublishOfferPhoneFields(
                            controller: _phoneController,
                            label: _requiredLabel(
                              'Téléphone (pour être rappelé)',
                            ),
                            hintText: phoneHintForCountryCode(
                              _selectedPhoneCountryCode,
                            ),
                            initialCountryCode: _selectedPhoneCountryCode,
                            phoneDecorator: (child) =>
                                _withPublishFieldHighlight(
                              fieldId: 'phone',
                              child: child,
                            ),
                            onCountryCodeChanged: (code) {
                              setState(() {
                                _selectedPhoneCountryCode = code;
                              });
                            },
                            onPhoneChanged: (_) => _recompute(),
                            validator: (value) {
                              return _isValidPhoneFR(value ?? '')
                                  ? null
                                  : 'Téléphone invalide';
                            },
                            hidePhone: _hidePhone,
                            onHidePhoneChanged: (value) {
                              setState(() => _hidePhone = value);
                            },
                          ),

`,
  );
}

if (!text.includes('PublishOfferMissionFields(')) {
  replaceBetween(
    '                          // DÉLAI POUR EFFECTUER LA MISSION\n',
    "                          const Text(\n                            '* Champs obligatoires',\n",
    `                          PublishOfferMissionFields(
                            delayLabel: _requiredLabel(
                              'Délai pour effectuer la mission',
                            ),
                            delayOptions: _missionDelayOptions,
                            selectedDelay: _missionDelay,
                            delayDecorator: (child) =>
                                _withPublishFieldHighlight(
                              fieldId: 'delay',
                              child: child,
                            ),
                            onDelayChanged: (value) {
                              setState(() {
                                _delayEditedByUser = true;
                                _missionDelay = value;
                                _isUrgent = value == 'Urgent';
                              });
                              _recompute();
                            },
                            budgetTypes: _budgetTypes,
                            selectedBudgetType: _budgetType,
                            budgetController: _budgetController,
                            budgetLabel: _budgetType == 'À négocier'
                                ? const Text('Budget')
                                : _requiredLabel('Budget (€)'),
                            budgetDecorator: (child) =>
                                _withPublishFieldHighlight(
                              fieldId: 'budget',
                              child: child,
                            ),
                            onBudgetTypeChanged: (value) {
                              setState(() {
                                _budgetEditedByUser = true;
                                _budgetType = value;
                              });
                              _recompute();
                            },
                            budgetValidator: (value) {
                              if (_budgetType == 'À négocier') return null;
                              final budget = _parseBudget(value ?? '');
                              if (budget == null) return 'Montant invalide';
                              if (budget <= 0) {
                                return 'Le montant doit être > 0';
                              }
                              return null;
                            },
                          ),

`,
  );
}

const cityImport = "import '../widgets/city_postal_autocomplete_field.dart';\n";
const withoutCityImport = text.replace(cityImport, '');
if (!withoutCityImport.includes('CityPostalAutocompleteField') &&
    !withoutCityImport.includes('CityEntry')) {
  text = withoutCityImport;
}

fs.writeFileSync(path, text, 'utf8');
console.log('Publish offer form sections extracted successfully.');
