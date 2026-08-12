import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants.dart';
import '../services/pro_siret_service.dart';
import '../services/user_profile_bootstrap_service.dart';
import '../utils/friendly_snackbar.dart';
import '../widgets/phone_input_field.dart';
import '../widgets/pro_declared_leader_dialog.dart';
import '../widgets/verification_status_tooltip.dart';

const kPrestoOrange = Color(0xFFFF6600);
const kPrestoBeige = Color(0xFFFCEEE2);
const kPrestoBlue = Color(0xFF1A73E8);

class ProProfilePage extends StatefulWidget {
  const ProProfilePage({
    super.key,
    this.initialSiret,
    this.initialCompanyName,
  });

  final String? initialSiret;
  final String? initialCompanyName;

  @override
  State<ProProfilePage> createState() => _ProProfilePageState();
}

class _ProProfilePageState extends State<ProProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final ProSiretService _siretService = ProSiretService();

  final _companyCtrl = TextEditingController();
  final _siretCtrl = TextEditingController();
  final _sirenCtrl = TextEditingController();
  final _nafCtrl = TextEditingController();
  final _contactNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _cpCtrl = TextEditingController();
  final _activityCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _interventionZoneCtrl = TextEditingController();
  final _serviceCategoriesCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();

  bool _acceptTerms = false;
  bool _isSaving = false;
  bool _isLoadingProfile = true;
  bool _isVerifyingSiret = false;
  bool _siretVerified = false;
  bool _leaderDeclaredMatch = false;

  @override
  void initState() {
    super.initState();

    final initialSiret = widget.initialSiret?.trim() ?? '';
    final initialCompanyName = widget.initialCompanyName?.trim() ?? '';

    if (initialSiret.isNotEmpty) {
      _siretCtrl.text = initialSiret;
    }

    if (initialCompanyName.isNotEmpty) {
      _companyCtrl.text = initialCompanyName;
    }

    _loadExistingProfile();
  }

  @override
  void dispose() {
    _companyCtrl.dispose();
    _siretCtrl.dispose();
    _sirenCtrl.dispose();
    _nafCtrl.dispose();
    _contactNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _cpCtrl.dispose();
    _activityCtrl.dispose();
    _descriptionCtrl.dispose();
    _interventionZoneCtrl.dispose();
    _serviceCategoriesCtrl.dispose();
    _websiteCtrl.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      prefixIcon: icon == null ? null : Icon(icon),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kPrestoOrange, width: 1.4),
      ),
    );
  }

  String _s(dynamic value) => value?.toString().trim() ?? '';

  Future<void> _loadExistingProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) setState(() => _isLoadingProfile = false);
      return;
    }

    if (_emailCtrl.text.trim().isEmpty &&
        (user.email ?? '').trim().isNotEmpty) {
      _emailCtrl.text = user.email!.trim();
    }

    try {
      await UserProfileBootstrapService.prepareProfileFirestoreAccess(
        user: user,
        forceRefreshToken: true,
        forceRefreshAppCheckToken: true,
      );

      final db = FirebaseFirestore.instance;

      // Collection officielle du compte professionnel :
      // remplie par verifySiret côté Cloud Function.
      final proProfilesSnap =
          await db.collection('pro_profiles').doc(user.uid).get();

      Map<String, dynamic>? data = proProfilesSnap.data();

      // Ancienne collection legacy pour récupérer les profils déjà saisis.
      if (data == null || data.isEmpty) {
        final legacySnap = await db.collection('pros').doc(user.uid).get();
        data = legacySnap.data();
      }

      if (data == null || data.isEmpty) return;

      _companyCtrl.text = _s(data['companyName']).isNotEmpty
          ? _s(data['companyName'])
          : _companyCtrl.text;
      _siretCtrl.text =
          _s(data['siret']).isNotEmpty ? _s(data['siret']) : _siretCtrl.text;
      _sirenCtrl.text =
          _s(data['siren']).isNotEmpty ? _s(data['siren']) : _sirenCtrl.text;
      _nafCtrl.text = _s(data['nafCode']).isNotEmpty
          ? _s(data['nafCode'])
          : _s(data['activityCode']).isNotEmpty
              ? _s(data['activityCode'])
              : _nafCtrl.text;

      _activityCtrl.text = _s(data['activity']).isNotEmpty
          ? _s(data['activity'])
          : _activityCtrl.text;
      _descriptionCtrl.text = _s(data['description']).isNotEmpty
          ? _s(data['description'])
          : _descriptionCtrl.text;
      _interventionZoneCtrl.text = _s(data['interventionZone']).isNotEmpty
          ? _s(data['interventionZone'])
          : _interventionZoneCtrl.text;
      _serviceCategoriesCtrl.text = _s(data['serviceCategories']).isNotEmpty
          ? _s(data['serviceCategories'])
          : _serviceCategoriesCtrl.text;

      _contactNameCtrl.text = _s(data['contactName']).isNotEmpty
          ? _s(data['contactName'])
          : _contactNameCtrl.text;
      _emailCtrl.text = _s(data['contactEmail']).isNotEmpty
          ? _s(data['contactEmail'])
          : _emailCtrl.text;
      _phoneCtrl.text = _s(data['contactPhone']).isNotEmpty
          ? _s(data['contactPhone'])
          : _phoneCtrl.text;
      _websiteCtrl.text = _s(data['website']).isNotEmpty
          ? _s(data['website'])
          : _websiteCtrl.text;

      _addressCtrl.text = _s(data['address']).isNotEmpty
          ? _s(data['address'])
          : _addressCtrl.text;
      _cityCtrl.text =
          _s(data['city']).isNotEmpty ? _s(data['city']) : _cityCtrl.text;
      _cpCtrl.text = _s(data['postalCode']).isNotEmpty
          ? _s(data['postalCode'])
          : _cpCtrl.text;

      final accepted = data['termsAccepted'];
      final verified = data['siretVerified'];
      final leaderMatch = data['leaderDeclaredMatch'];

      if (mounted) {
        setState(() {
          _acceptTerms = accepted is bool ? accepted : _acceptTerms;
          _siretVerified =
              verified == true || _s(data?['verifiedAt']).isNotEmpty;
          _leaderDeclaredMatch = leaderMatch == true;
        });
      }
    } catch (_) {
      // Chargement best-effort : ne bloque pas l'utilisateur.
    } finally {
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _verifySiret() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      showErrorSnackBar(context, 'Connectez-vous avant de vérifier le SIRET.');
      return;
    }

    final rawSiret = _siretCtrl.text.trim();

    if (rawSiret.isEmpty) {
      showErrorSnackBar(context, 'Saisissez votre numéro SIRET.');
      return;
    }

    final leader = await showProDeclaredLeaderDialog(context);
    if (leader == null || !mounted) return;

    setState(() => _isVerifyingSiret = true);

    try {
      await UserProfileBootstrapService.prepareProfileFirestoreAccess(
        user: user,
        forceRefreshToken: true,
        forceRefreshAppCheckToken: true,
      );

      // Vérification officielle :
      // écrit côté backend dans pro_profiles/{uid} + users/{uid}.
      // La concordance du dirigeant est calculée côté serveur.
      final result = await _siretService.verifySiret(
        rawSiret,
        leaderFirstName: leader.firstName,
        leaderLastName: leader.lastName,
      );

      if (!mounted) return;

      setState(() {
        _siretVerified = true;
        _leaderDeclaredMatch = result.leaderDeclaredMatch;
        _siretCtrl.text = result.siret;
        _sirenCtrl.text = result.siren;
        _companyCtrl.text = result.companyName;
        _addressCtrl.text = result.address;
        _cityCtrl.text = result.city;
        _cpCtrl.text = result.postalCode;
        _nafCtrl.text = result.nafCode;
      });

      showSuccessSnackBar(
        context,
        result.companyName.isNotEmpty
            ? 'SIRET + dirigeant concordants : ${result.companyName}'
            : 'SIRET + dirigeant concordants',
      );
    } catch (error) {
      if (!mounted) return;
      showErrorSnackBar(
        context,
        error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isVerifyingSiret = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_siretVerified || !_leaderDeclaredMatch) {
      showErrorSnackBar(
        context,
        'Vérifiez le SIRET et le dirigeant déclaré avant d’enregistrer le profil professionnel.',
      );
      return;
    }

    if (!_acceptTerms) {
      showErrorSnackBar(context, "Veuillez accepter les conditions.");
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      showErrorSnackBar(context, "Veuillez vous connecter avant.");
      return;
    }

    setState(() => _isSaving = true);

    try {
      await UserProfileBootstrapService.prepareProfileFirestoreAccess(
        user: user,
        forceRefreshToken: true,
        forceRefreshAppCheckToken: true,
      );

      final db = FirebaseFirestore.instance;
      final proRef = db.collection('pro_profiles').doc(user.uid);
      final now = FieldValue.serverTimestamp();

      // IMPORTANT :
      // Les champs de vérification sont écrits uniquement par verifySiret
      // via Cloud Function Admin SDK : SIRET/SIREN, données établissement,
      // siretVerified, leaderDeclaredMatch, identité déclarée du dirigeant,
      // niveau/source/statut et horodatage de vérification.
      // Ici on écrit seulement les champs éditables par l'utilisateur.
      final editableProfileData = <String, dynamic>{
        'uid': user.uid,
        'activity': _activityCtrl.text.trim(),
        'description': _descriptionCtrl.text.trim(),
        'interventionZone': _interventionZoneCtrl.text.trim(),
        'serviceCategories': _serviceCategoriesCtrl.text.trim(),
        'contactName': _contactNameCtrl.text.trim(),
        'contactEmail': _emailCtrl.text.trim(),
        'contactPhone': _phoneCtrl.text.trim(),
        'website': _websiteCtrl.text.trim(),
        'termsAccepted': _acceptTerms,
        'termsAcceptedAt': now,
        'profileCompletedAt': now,
        'updatedAt': now,
      };

      editableProfileData.removeWhere(
        (_, value) => value == null || value.toString().trim().isEmpty,
      );

      await proRef.set(editableProfileData, SetOptions(merge: true));

      if (!mounted) return;

      showSuccessSnackBar(context, 'Profil Pro enregistré ✅');
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      showErrorSnackBar(
        context,
        "Impossible d'enregistrer le Profil Pro. Réessayez.",
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w900,
          color: Color(0xFF111827),
        ),
      ),
    );
  }

  Widget _verifiedBadge() {
    final fullyMatched = _siretVerified && _leaderDeclaredMatch;
    final color = fullyMatched ? const Color(0xFF16A34A) : Colors.orange;
    final text = fullyMatched
        ? 'SIRET + dirigeant déclaré concordants.'
        : _siretVerified
            ? 'SIRET validé — dirigeant déclaré à confirmer.'
            : 'Vérifiez le SIRET + dirigeant pour valider le profil professionnel.';

    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(
            fullyMatched ? Icons.verified_rounded : Icons.warning_amber_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          if (fullyMatched) ...[
            const SizedBox(width: 6),
            Icon(Icons.info_outline_rounded, color: color, size: 18),
          ],
        ],
      ),
    );

    if (!fullyMatched) return content;
    return VerificationStatusTooltip(
      message: kSiretLeaderMatchDisclaimer,
      child: content,
    );
  }

  @override
  Widget build(BuildContext context) {
    final officialFieldsReadOnly = _siretVerified || _isVerifyingSiret;

    return Scaffold(
      backgroundColor: kPrestoBeige,
      appBar: AppBar(
        backgroundColor: kPrestoOrange,
        foregroundColor: Colors.white,
        title: const Text(
          "Profil Pro",
          style: kPrestoAppBarTitleStyle,
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoadingProfile
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  children: [
                    _verifiedBadge(),
                    const SizedBox(height: 18),
                    _sectionTitle("Vérification entreprise"),
                    TextFormField(
                      controller: _siretCtrl,
                      readOnly: officialFieldsReadOnly,
                      decoration: _dec(
                        "SIRET *",
                        icon: Icons.business_center_outlined,
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(14),
                      ],
                      validator: (value) {
                        final clean =
                            (value ?? '').replaceAll(RegExp(r'\D'), '');
                        if (clean.length != 14) {
                          return 'SIRET obligatoire : 14 chiffres';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed:
                            _isVerifyingSiret ? null : () => _verifySiret(),
                        icon: _isVerifyingSiret
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.verified_outlined),
                        label: Text(
                          _isVerifyingSiret
                              ? 'Vérification SIRET + dirigeant...'
                              : _leaderDeclaredMatch
                                  ? 'SIRET + dirigeant concordants'
                                  : 'Vérifier SIRET + dirigeant',
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _companyCtrl,
                      readOnly: true,
                      decoration: _dec(
                        "Nom officiel de l'entreprise",
                        icon: Icons.apartment_rounded,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _sirenCtrl,
                            readOnly: true,
                            decoration: _dec("SIREN"),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _nafCtrl,
                            readOnly: true,
                            decoration: _dec("Code NAF"),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _sectionTitle("Activité"),
                    TextFormField(
                      controller: _activityCtrl,
                      decoration: _dec(
                        "Activité / secteur *",
                        icon: Icons.handyman_outlined,
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                              ? "Obligatoire"
                              : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _serviceCategoriesCtrl,
                      decoration: _dec(
                        "Catégories de services",
                        icon: Icons.category_outlined,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _interventionZoneCtrl,
                      decoration: _dec(
                        "Zone d'intervention",
                        icon: Icons.location_on_outlined,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _descriptionCtrl,
                      decoration: _dec(
                        "Description de l'activité",
                        icon: Icons.description_outlined,
                      ),
                      minLines: 3,
                      maxLines: 5,
                    ),
                    const SizedBox(height: 18),
                    _sectionTitle("Contact"),
                    TextFormField(
                      controller: _contactNameCtrl,
                      decoration: _dec(
                        "Nom du contact *",
                        icon: Icons.person_outline_rounded,
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                              ? "Obligatoire"
                              : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _emailCtrl,
                      decoration: _dec(
                        "Email *",
                        icon: Icons.mail_outline_rounded,
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) =>
                          (value == null || !value.contains("@"))
                              ? "Email invalide"
                              : null,
                    ),
                    const SizedBox(height: 10),
                    PhoneInputFieldCompact(
                      controller: _phoneCtrl,
                      labelText: 'Téléphone',
                      hintText: '612345678',
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _websiteCtrl,
                      decoration: _dec(
                        "Site web / réseau social",
                        icon: Icons.language_outlined,
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 18),
                    _sectionTitle("Adresse officielle"),
                    TextFormField(
                      controller: _addressCtrl,
                      readOnly: true,
                      decoration: _dec(
                        "Adresse officielle",
                        icon: Icons.home_work_outlined,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _cityCtrl,
                            readOnly: true,
                            decoration: _dec("Ville"),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 120,
                          child: TextFormField(
                            controller: _cpCtrl,
                            readOnly: true,
                            decoration: _dec("C/P"),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    CheckboxListTile(
                      value: _acceptTerms,
                      onChanged: _isSaving
                          ? null
                          : (value) =>
                              setState(() => _acceptTerms = value ?? false),
                      title: const Text(
                        "J'accepte les conditions d'utilisation professionnelles",
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 54,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrestoOrange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        onPressed: _isSaving ? null : _submit,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_rounded),
                        label: Text(
                          _isSaving
                              ? "Enregistrement..."
                              : "Enregistrer mon Profil Pro",
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
