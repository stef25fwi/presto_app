import 'package:flutter/material.dart';

import 'app_operating_mode.dart';

class LegalPublisherAdminForm extends StatefulWidget {
  final LegalPublisherProfile initial;
  final AppOperatingMode mode;
  final Future<void> Function(LegalPublisherProfile profile) onSave;

  const LegalPublisherAdminForm({
    super.key,
    required this.initial,
    required this.mode,
    required this.onSave,
  });

  @override
  State<LegalPublisherAdminForm> createState() =>
      _LegalPublisherAdminFormState();
}

class _LegalPublisherAdminFormState extends State<LegalPublisherAdminForm> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;
  bool _saving = false;
  bool _companyExpanded = false;
  bool _hostingExpanded = false;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _controllers = <String, TextEditingController>{
      'publisherName': TextEditingController(text: p.publisherName),
      'postalAddress': TextEditingController(text: p.postalAddress),
      'phone': TextEditingController(text: p.phone),
      'email': TextEditingController(text: p.email),
      'publicationDirector':
          TextEditingController(text: p.publicationDirector),
      'companyName': TextEditingController(text: p.companyName),
      'legalForm': TextEditingController(text: p.legalForm),
      'siren': TextEditingController(text: p.siren),
      'rcs': TextEditingController(text: p.rcs),
      'shareCapital': TextEditingController(text: p.shareCapital),
      'vatNumber': TextEditingController(text: p.vatNumber),
      'hostingProvider': TextEditingController(text: p.hostingProvider),
      'hostingAddress': TextEditingController(text: p.hostingAddress),
    };
  }

  @override
  void didUpdateWidget(covariant LegalPublisherAdminForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_saving) return;

    final previous = oldWidget.initial.toMap();
    final incoming = widget.initial.toMap();
    if (previous.length == incoming.length &&
        previous.entries.every((entry) => incoming[entry.key] == entry.value)) {
      return;
    }

    for (final entry in incoming.entries) {
      final controller = _controllers[entry.key];
      if (controller == null) continue;

      final previousValue = (previous[entry.key] ?? '').toString().trim();
      final currentValue = controller.text.trim();
      final incomingValue = (entry.value ?? '').toString().trim();

      // Ne remplace qu'un champ que l'administrateur n'a pas modifié depuis
      // la dernière valeur distante. Ainsi le premier snapshot Firestore peut
      // réhydrater le formulaire sans écraser une saisie locale en cours.
      if (currentValue == previousValue && currentValue != incomingValue) {
        controller.value = controller.value.copyWith(
          text: incomingValue,
          selection: TextSelection.collapsed(offset: incomingValue.length),
          composing: TextRange.empty,
        );
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _value(String key) => _controllers[key]!.text.trim();

  LegalPublisherProfile _profile() => LegalPublisherProfile(
        publisherName: _value('publisherName'),
        postalAddress: _value('postalAddress'),
        phone: _value('phone'),
        email: _value('email'),
        publicationDirector: _value('publicationDirector'),
        companyName: _value('companyName'),
        legalForm: _value('legalForm'),
        siren: _value('siren'),
        rcs: _value('rcs'),
        shareCapital: _value('shareCapital'),
        vatNumber: _value('vatNumber'),
        hostingProvider: _value('hostingProvider'),
        hostingAddress: _value('hostingAddress'),
      );

  String? _required(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Champ obligatoire';
    return null;
  }

  String? _addressValidator(String? value) {
    final requiredError = _required(value);
    if (requiredError != null) return requiredError;
    if (value!.trim().length < 8) return 'Adresse trop courte';
    return null;
  }

  String? _phoneValidator(String? value) {
    final requiredError = _required(value);
    if (requiredError != null) return requiredError;
    final normalized = value!.replaceAll(RegExp(r'[^0-9+]'), '');
    if (normalized.length < 8 || normalized.length > 16) {
      return 'Numéro de téléphone invalide';
    }
    return null;
  }

  String? _emailValidator(String? value) {
    final requiredError = _required(value);
    if (requiredError != null) return requiredError;
    final email = value!.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Adresse e-mail invalide';
    }
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false) || _saving) return;

    final profile = _profile();
    if (widget.mode.isCommercial && !profile.isCommercialReady) {
      setState(() => _companyExpanded = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La dénomination sociale, la forme juridique et le SIREN sont obligatoires en version payante.',
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.onSave(profile);
    } catch (_) {
      // Le parent affiche le message d’erreur adapté. Le formulaire reste ouvert.
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(
    String key,
    String label, {
    String? hint,
    TextInputType? keyboardType,
    TextCapitalization capitalization = TextCapitalization.sentences,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        key: ValueKey<String>('legal_$key'),
        controller: _controllers[key],
        keyboardType: keyboardType,
        textCapitalization: capitalization,
        validator: validator,
        maxLines: maxLines,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: const Color(0xFFF9FAFB),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 12.5,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _expandableSection({
    required String title,
    required String subtitle,
    required bool expanded,
    required ValueChanged<bool> onExpansionChanged,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ExpansionTile(
        initiallyExpanded: expanded,
        onExpansionChanged: onExpansionChanged,
        tilePadding: const EdgeInsets.symmetric(horizontal: 14),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(subtitle),
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ready = _profile().isReadyFor(widget.mode);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 28),
          _sectionTitle(
            'Identité de l’éditeur',
            'Ces informations alimentent automatiquement les mentions légales publiques, y compris pour les visiteurs non connectés.',
          ),
          _field(
            'publisherName',
            'Nom réel de l’éditeur *',
            validator: _required,
          ),
          _field(
            'postalAddress',
            'Adresse juridiquement utilisable *',
            hint: 'Numéro, voie, code postal et commune',
            validator: _addressValidator,
            maxLines: 2,
          ),
          _field(
            'phone',
            'Téléphone *',
            keyboardType: TextInputType.phone,
            capitalization: TextCapitalization.none,
            validator: _phoneValidator,
          ),
          _field(
            'email',
            'Adresse de contact *',
            keyboardType: TextInputType.emailAddress,
            capitalization: TextCapitalization.none,
            validator: _emailValidator,
          ),
          _field(
            'publicationDirector',
            'Directeur de publication *',
            validator: _required,
          ),
          _expandableSection(
            title: 'Informations de société',
            subtitle: widget.mode.isCommercial
                ? 'Obligatoires pour maintenir la version payante active.'
                : 'À compléter plus tard avant l’activation payante.',
            expanded: _companyExpanded,
            onExpansionChanged: (value) =>
                setState(() => _companyExpanded = value),
            children: [
              _field('companyName', 'Dénomination sociale'),
              _field('legalForm', 'Forme juridique'),
              _field(
                'siren',
                'SIREN',
                keyboardType: TextInputType.number,
                capitalization: TextCapitalization.none,
              ),
              _field('rcs', 'RCS'),
              _field('shareCapital', 'Capital social'),
              _field('vatNumber', 'TVA intracommunautaire'),
            ],
          ),
          _expandableSection(
            title: 'Hébergement',
            subtitle: 'Valeurs préremplies pour Firebase Hosting.',
            expanded: _hostingExpanded,
            onExpansionChanged: (value) =>
                setState(() => _hostingExpanded = value),
            children: [
              _field('hostingProvider', 'Hébergeur'),
              _field(
                'hostingAddress',
                'Adresse de l’hébergeur',
                maxLines: 2,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ready
                  ? const Color(0xFFEAF7EF)
                  : const Color(0xFFFFF3E8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  ready
                      ? Icons.verified_outlined
                      : Icons.info_outline_rounded,
                  color: ready
                      ? const Color(0xFF138A46)
                      : const Color(0xFFFF6600),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ready
                        ? 'Les informations obligatoires sont complètes.'
                        : 'Complétez les champs obligatoires avant la mise en ligne.',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey<String>('save_legal_publisher'),
            onPressed: _saving ? null : _submit,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(
              _saving
                  ? 'Enregistrement…'
                  : 'Enregistrer les informations juridiques',
            ),
          ),
        ],
      ),
    );
  }
}
