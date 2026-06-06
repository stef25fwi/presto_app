import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/friendly_snackbar.dart';
import '../widgets/phone_input_field.dart';
import '../constants.dart';
import '../services/user_profile_bootstrap_service.dart';

const kPrestoOrange = Color(0xFFFF6600);
const kPrestoBeige = Color(0xFFFCEEE2);

class ProProfilePage extends StatefulWidget {
  const ProProfilePage({super.key});

  @override
  State<ProProfilePage> createState() => _ProProfilePageState();
}

class _ProProfilePageState extends State<ProProfilePage> {
  final _formKey = GlobalKey<FormState>();

  final _companyCtrl = TextEditingController();
  final _siretCtrl = TextEditingController();
  final _contactNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _cpCtrl = TextEditingController();
  final _activityCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();

  bool _acceptTerms = false;

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
  }

  Future<void> _loadExistingProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

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
      final snap = await FirebaseFirestore.instance
          .collection('pros')
          .doc(user.uid)
          .get();
      if (!snap.exists) return;
      final data = snap.data();
      if (data == null) return;

      String? s(dynamic v) => v?.toString();

      _companyCtrl.text = s(data['companyName']) ?? _companyCtrl.text;
      _siretCtrl.text = s(data['siret']) ?? _siretCtrl.text;
      _activityCtrl.text = s(data['activity']) ?? _activityCtrl.text;
      _contactNameCtrl.text = s(data['contactName']) ?? _contactNameCtrl.text;
      _emailCtrl.text = s(data['contactEmail']) ?? _emailCtrl.text;
      _phoneCtrl.text = s(data['contactPhone']) ?? _phoneCtrl.text;
      _websiteCtrl.text = s(data['website']) ?? _websiteCtrl.text;
      _addressCtrl.text = s(data['address']) ?? _addressCtrl.text;
      _cityCtrl.text = s(data['city']) ?? _cityCtrl.text;
      _cpCtrl.text = s(data['postalCode']) ?? _cpCtrl.text;

      final accepted = data['termsAccepted'];
      if (accepted is bool && mounted) {
        setState(() => _acceptTerms = accepted);
      }
    } catch (_) {
      // best-effort: pas de blocage UX
    }
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      );

  @override
  void dispose() {
    _companyCtrl.dispose();
    _siretCtrl.dispose();
    _contactNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _cpCtrl.dispose();
    _activityCtrl.dispose();
    _websiteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptTerms) {
      showErrorSnackBar(context, "Veuillez accepter les conditions.");
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      showErrorSnackBar(context, "Veuillez vous connecter avant.");
      return;
    }

    try {
      await UserProfileBootstrapService.prepareProfileFirestoreAccess(
        user: user,
        forceRefreshToken: true,
        forceRefreshAppCheckToken: true,
      );
      final db = FirebaseFirestore.instance;

      final usersRef = db.collection('users').doc(user.uid);
      final proRef = db.collection('pros').doc(user.uid);

      final now = FieldValue.serverTimestamp();

      final existingPro = await proRef.get();
      final isCreate = !existingPro.exists;

      final profileData = <String, dynamic>{
        'uid': user.uid,
        'companyName': _companyCtrl.text.trim(),
        'siret': _siretCtrl.text.trim().isEmpty ? null : _siretCtrl.text.trim(),
        'activity': _activityCtrl.text.trim().isEmpty
            ? null
            : _activityCtrl.text.trim(),
        'contactName': _contactNameCtrl.text.trim(),
        'contactEmail': _emailCtrl.text.trim(),
        'contactPhone':
            _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'website':
            _websiteCtrl.text.trim().isEmpty ? null : _websiteCtrl.text.trim(),
        'address':
            _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        'city': _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
        'postalCode': _cpCtrl.text.trim().isEmpty ? null : _cpCtrl.text.trim(),
      };

      profileData.removeWhere((_, v) => v == null);

      final batch = db.batch();

      batch.set(
        usersRef,
        {
          'accountType': 'Pro',
          'proEnabledAt': now,
        },
        SetOptions(merge: true),
      );

      batch.set(
        proRef,
        {
          ...profileData,
          'termsAccepted': _acceptTerms,
          'termsAcceptedAt': now,
          'updatedAt': now,
          if (isCreate) ...{
            'status': 'pending',
            'plan': 'free_pro_trial',
            'createdAt': now,
          },
        },
        SetOptions(merge: true),
      );

      await batch.commit();
    } catch (_) {
      if (!mounted) return;
      showErrorSnackBar(
          context, "Impossible d'enregistrer le Profil Pro. Réessayez.");
      return;
    }

    if (!mounted) return;
    showSuccessSnackBar(
        context, "Profil Pro enregistré ✅ (options avancées bientôt)");
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
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
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 16),
            children: [
              const Text(
                "Informations entreprise",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _companyCtrl,
                decoration: _dec("Nom de l'entreprise *"),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? "Obligatoire" : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _siretCtrl,
                decoration: _dec("SIRET (optionnel pour l'instant)"),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _activityCtrl,
                decoration:
                    _dec("Activité / secteur (ex: plomberie, traiteur)"),
              ),
              const SizedBox(height: 10),
              const Divider(height: 26),
              const Text(
                "Contact",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _contactNameCtrl,
                decoration: _dec("Nom du contact *"),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? "Obligatoire" : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _emailCtrl,
                decoration: _dec("Email *"),
                keyboardType: TextInputType.emailAddress,
                validator: (v) =>
                    (v == null || !v.contains("@")) ? "Email invalide" : null,
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
                decoration: _dec("Site web (optionnel)"),
                keyboardType: TextInputType.url,
              ),
              const Divider(height: 26),
              const Text(
                "Adresse (optionnel)",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              TextFormField(
                  controller: _addressCtrl, decoration: _dec("Adresse")),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                      child: TextFormField(
                          controller: _cityCtrl, decoration: _dec("Ville"))),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 110,
                    child: TextFormField(
                      controller: _cpCtrl,
                      decoration: _dec("C/P"),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              CheckboxListTile(
                value: _acceptTerms,
                onChanged: (v) => setState(() => _acceptTerms = v ?? false),
                title: const Text("J'accepte les conditions d'utilisation"),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrestoOrange,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28)),
                  ),
                  onPressed: _submit,
                  child: const Text(
                    "Enregistrer mon Profil Pro",
                    style: TextStyle(fontWeight: FontWeight.w800),
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
