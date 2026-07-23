import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../features/operating_mode/app_operating_mode.dart';
import '../../pages/legal_info_page.dart';
import '../../services/auth_error_mapper.dart';
import '../../services/auth_service.dart';
import 'verify_email_page.dart';

typedef RegisterWithEmailCallback = Future<void> Function({
  required String email,
  required String password,
  required String displayName,
  required String fullName,
  required String firstName,
  required String lastName,
  required String pseudo,
});

typedef RecordLegalAcceptanceCallback = Future<void> Function(
  AppOperatingModeState state,
);

class RegisterPage extends StatefulWidget {
  const RegisterPage({
    super.key,
    this.registerWithEmail,
    this.recordLegalAcceptance,
    this.successPageBuilder,
  });

  static const routeName = '/register';

  final RegisterWithEmailCallback? registerWithEmail;
  final RecordLegalAcceptanceCallback? recordLegalAcceptance;
  final WidgetBuilder? successPageBuilder;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _lastNameCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _pseudoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  String get _lastName => _lastNameCtrl.text.trim();
  String get _firstName => _firstNameCtrl.text.trim();

  String get _computedFullName {
    final parts = <String>[
      _firstName,
      _lastName,
    ].where((value) => value.trim().isNotEmpty).toList();
    return parts.join(' ').trim();
  }

  bool _loading = false;
  bool _hidePassword = true;
  bool _legalAccepted = false;

  @override
  void dispose() {
    _lastNameCtrl.dispose();
    _firstNameCtrl.dispose();
    _pseudoCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _recordAcceptance() async {
    final injected = widget.recordLegalAcceptance;
    if (injected != null) {
      await injected(AppOperatingModeState.defaults());
      return;
    }

    AppOperatingModeState state = AppOperatingModeState.defaults();
    AppOperatingModeService? service;
    try {
      service = AppOperatingModeService();
      state = await service.getState();
    } catch (_) {
      // La création du compte ne doit pas échouer si la configuration juridique
      // distante est momentanément indisponible. La version bêta embarquée reste
      // la référence de secours et la preuve est écrite dès que Firebase répond.
    }

    String? uid;
    try {
      uid = FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      uid = null;
    }
    if (uid == null || uid.isEmpty || service == null) return;
    await service.recordAcceptance(userId: uid, state: state);
  }

  Future<void> _register() async {
    if (!_legalAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Veuillez accepter les CGU et la politique de confidentialité.',
          ),
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    final email = _emailCtrl.text;
    final password = _passwordCtrl.text;
    final pseudo = _pseudoCtrl.text.trim();
    final fullName = _computedFullName;
    final firstName = _firstName;
    final lastName = _lastName;

    try {
      final registerWithEmail = widget.registerWithEmail;
      if (registerWithEmail != null) {
        await registerWithEmail(
          email: email,
          password: password,
          displayName: pseudo,
          fullName: fullName,
          firstName: firstName,
          lastName: lastName,
          pseudo: pseudo,
        );
      } else {
        await AuthService.instance.registerWithEmail(
          email: email,
          password: password,
          displayName: pseudo,
          fullName: fullName,
          firstName: firstName,
          lastName: lastName,
          pseudo: pseudo,
        );
      }

      await _recordAcceptance();
      if (!mounted) return;

      final successPageBuilder = widget.successPageBuilder;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: successPageBuilder ?? (_) => const VerifyEmailPage(),
        ),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AuthErrorMapper.message(e))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _pseudoValidator(String? value) {
    final text = (value ?? '').trim();
    if (text.length < 2) return 'Pseudo obligatoire (2 caractères minimum).';
    if (text.length > 30) return 'Pseudo trop long (30 caractères maximum).';
    return null;
  }

  String? _emailValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Email obligatoire.';
    if (!text.contains('@')) return 'Email invalide.';
    return null;
  }

  String? _passwordValidator(String? value) {
    final text = value ?? '';
    if (text.length < 8) return '8 caractères minimum.';
    if (!RegExp(r'[A-Za-z]').hasMatch(text)) {
      return 'Ajoute au moins une lettre.';
    }
    if (!RegExp(r'[0-9]').hasMatch(text)) return 'Ajoute au moins un chiffre.';
    return null;
  }

  void _openLegal(int tab) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LegalInfoPage(initialTab: tab),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFFF6600);

    return Scaffold(
      appBar: AppBar(title: const Text('Créer un compte')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Text(
                        'Bienvenue sur Prestō',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Center(
                      child: Text(
                        'Particulier',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: orange,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _lastNameCtrl,
                            textInputAction: TextInputAction.next,
                            textCapitalization: TextCapitalization.words,
                            autofillHints: const [AutofillHints.familyName],
                            decoration: const InputDecoration(
                              labelText: 'Nom *',
                              hintText: 'Votre nom',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                            validator: (value) =>
                                (value?.trim().isEmpty ?? true)
                                    ? 'Nom obligatoire'
                                    : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _firstNameCtrl,
                            textInputAction: TextInputAction.next,
                            textCapitalization: TextCapitalization.words,
                            autofillHints: const [AutofillHints.givenName],
                            decoration: const InputDecoration(
                              labelText: 'Prénom *',
                              hintText: 'Votre prénom',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                            validator: (value) =>
                                (value?.trim().isEmpty ?? true)
                                    ? 'Prénom obligatoire'
                                    : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _pseudoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Pseudo',
                        hintText: 'Votre nom affiché publiquement',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.alternate_email),
                      ),
                      validator: _pseudoValidator,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: _emailValidator,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _hidePassword,
                      decoration: InputDecoration(
                        labelText: 'Mot de passe',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _hidePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () => setState(
                            () => _hidePassword = !_hidePassword,
                          ),
                        ),
                      ),
                      validator: _passwordValidator,
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _legalAccepted,
                      onChanged: _loading
                          ? null
                          : (value) => setState(
                                () => _legalAccepted = value == true,
                              ),
                      title: Wrap(
                        children: [
                          const Text('J’accepte les '),
                          _LegalLink(
                            label: 'CGU',
                            onTap: () => _openLegal(2),
                          ),
                          const Text(' et la '),
                          _LegalLink(
                            label: 'politique de confidentialité',
                            onTap: () => _openLegal(1),
                          ),
                          const Text('.'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: orange,
                        ),
                        onPressed: _loading ? null : _register,
                        child: _loading
                            ? const CircularProgressIndicator()
                            : const Text('Créer mon compte'),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: TextButton(
                        onPressed: () => _openLegal(0),
                        child: const Text('Mentions légales'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LegalLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _LegalLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFFF6600),
          fontWeight: FontWeight.w700,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}
