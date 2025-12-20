import 'package:flutter/material.dart';
import '../widgets/phone_input_field.dart';

const kPrestoOrange = Color(0xFFFF6600);
const kPrestoBeige  = Color(0xFFFCEEE2);

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

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez accepter les conditions.")),
      );
      return;
    }

    // TODO plus tard: enregistrer dans Firestore:
    // pros/{uid}/profile + status "pending" + plan "free_pro_trial" etc.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Profil Pro enregistré ✅ (abonnement bientôt)")),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPrestoBeige,
      appBar: AppBar(
        backgroundColor: kPrestoOrange,
        foregroundColor: Colors.white,
        title: const Text("Profil Pro"),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                "Informations entreprise",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _companyCtrl,
                decoration: _dec("Nom de l'entreprise *"),
                validator: (v) => (v == null || v.trim().isEmpty) ? "Obligatoire" : null,
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
                decoration: _dec("Activité / secteur (ex: plomberie, traiteur)"),
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
                validator: (v) => (v == null || v.trim().isEmpty) ? "Obligatoire" : null,
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _emailCtrl,
                decoration: _dec("Email *"),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v == null || !v.contains("@")) ? "Email invalide" : null,
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

              TextFormField(controller: _addressCtrl, decoration: _dec("Adresse")),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(child: TextFormField(controller: _cityCtrl, decoration: _dec("Ville"))),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
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
