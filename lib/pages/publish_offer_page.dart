import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/city_repo_compact.dart';
import '../widgets/city_postal_autocomplete_compact.dart';

const kPrestoOrange = Color(0xFFFF6600);
const kPrestoBlue = Color(0xFF1A73E8);

// Fond "beige" comme sur ta capture
const kPrestoBeige = Color(0xFFFCEEE2);
const kFieldFill = Color(0xFFF7F2EB);
const kBorder = Color(0xFFD9D2C9);

class PublishOfferPage extends StatefulWidget {
  final CityRepoCompact? repo;
  final bool enableSpeechToText;

  const PublishOfferPage({
    super.key,
    this.repo,
    this.enableSpeechToText = true,
  });

  @override
  State<PublishOfferPage> createState() => _PublishOfferPageState();
}

class _PublishOfferPageState extends State<PublishOfferPage> {
  final _formKey = GlobalKey<FormState>();
  late final CityRepoCompact _repo;

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _cpCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();

  String? _category;

  // Focus pour savoir quel champ remplir à la dictée
  final _titleFocus = FocusNode();
  final _descFocus = FocusNode();
  final _cityFocus = FocusNode();
  final _cpFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _budgetFocus = FocusNode();

  late final stt.SpeechToText _stt;
  bool _sttReady = false;
  bool _listening = false;

  final List<String> _categories = const [
    'Jardinage',
    'Bricolage',
    'Ménage',
    'Restauration / Extra',
    'DJ / Sono',
    'Baby-sitting',
    'Transport / Livraison',
    'Informatique',
    'Autre',
  ];

  @override
  void initState() {
    super.initState();
    _repo = widget.repo ?? CityRepoCompact();

    _stt = stt.SpeechToText();
    if (widget.enableSpeechToText) {
      _initStt();
    } else {
      _sttReady = false;
    }
  }

  Future<void> _initStt() async {
    try {
      final ok = await _stt.initialize(
        onStatus: (s) {
          if (!mounted) return;
          if (s == 'done' || s == 'notListening') {
            setState(() => _listening = false);
          }
        },
        onError: (e) {
          if (!mounted) return;
          setState(() => _listening = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Micro indisponible : ${e.errorMsg}')),
          );
        },
      );
      if (!mounted) return;
      setState(() => _sttReady = ok);
    } catch (_) {
      if (!mounted) return;
      setState(() => _sttReady = false);
    }
  }

  TextEditingController _activeController() {
    if (_titleFocus.hasFocus) return _titleCtrl;
    if (_descFocus.hasFocus) return _descCtrl;
    if (_cityFocus.hasFocus) return _cityCtrl;
    if (_cpFocus.hasFocus) return _cpCtrl;
    if (_phoneFocus.hasFocus) return _phoneCtrl;
    if (_budgetFocus.hasFocus) return _budgetCtrl;
    // Par défaut : description (logique "décrire le besoin")
    return _descCtrl;
  }

  Future<void> _toggleMic() async {
    if (!_sttReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            kIsWeb
                ? "La dictée n'est pas disponible sur ce navigateur (essaie Chrome en HTTPS)."
                : "La dictée n'est pas disponible (permission micro ?).",
          ),
        ),
      );
      return;
    }

    if (_listening) {
      await _stt.stop();
      if (!mounted) return;
      setState(() => _listening = false);
      return;
    }

    final ctrl = _activeController();

    setState(() => _listening = true);

    await _stt.listen(
      localeId: 'fr_FR',
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
      ),
      onResult: (res) {
        if (!mounted) return;
        final text = res.recognizedWords.trim();
        if (text.isEmpty) return;

        // Remplit / met à jour le champ actif
        ctrl.value = ctrl.value.copyWith(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
          composing: TextRange.empty,
        );
        setState(() {});
      },
    );
  }

  InputDecoration _decoration(String hint, {Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: kFieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kPrestoBlue, width: 1.5),
      ),
      suffixIcon: suffix,
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _cityCtrl.dispose();
    _cpCtrl.dispose();
    _phoneCtrl.dispose();
    _budgetCtrl.dispose();

    _titleFocus.dispose();
    _descFocus.dispose();
    _cityFocus.dispose();
    _cpFocus.dispose();
    _phoneFocus.dispose();
    _budgetFocus.dispose();

    _stt.stop();
    super.dispose();
  }

  void _publish() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vous devez être connecté")),
      );
      return;
    }

    try {
      final city = _cityCtrl.text.trim();
      final cp = _cpCtrl.text.trim();
      final budgetStr = _budgetCtrl.text.trim();
      final budget = budgetStr.isEmpty ? null : int.tryParse(budgetStr);

      await FirebaseFirestore.instance.collection('offers').add({
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'category': _category ?? 'Autre',
        // 🔥 Compatibilité : écriture des 2 variantes
        'city': city,
        'location': city,
        'cp': cp.isEmpty ? null : cp,
        'postalCode': cp.isEmpty ? null : cp,
        'budget': budget,
        'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'userId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Offre publiée avec succès ✅")),
      );
      
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de la publication : $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPrestoBeige,
      appBar: AppBar(
        backgroundColor: kPrestoOrange,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          "Je publie une offre",
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            onPressed: () {
              // TODO: remplace par ta navigation Home
              Navigator.popUntil(context, (r) => r.isFirst);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Container(
          color: const Color(0xFFE3F0FF), // Bleu clair
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Décrivez votre besoin à notre IA",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1B1B1B),
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            "Plus votre demande est claire, plus vous aurez de réponses adaptées.",
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF7A7A7A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _MicButton(
                      listening: _listening,
                      onTap: _toggleMic,
                    ),
                  ],
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _titleCtrl,
                focusNode: _titleFocus,
                textInputAction: TextInputAction.next,
                decoration: _decoration("Titre de l'offre *"),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? "Titre obligatoire" : null,
              ),

              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: _category,
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v),
                decoration: _decoration("Catégorie",
                    suffix: const Icon(Icons.keyboard_arrow_down_rounded)),
              ),

              const SizedBox(height: 12),

              TextFormField(
                controller: _descCtrl,
                focusNode: _descFocus,
                minLines: 5,
                maxLines: 8,
                decoration: _decoration("Description détaillée *"),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? "Description obligatoire"
                    : null,
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: CityPostalAutocompleteCompact(
                      repo: _repo,
                      cityCtrl: _cityCtrl,
                      cpCtrl: _cpCtrl,
                      decoration: _decoration("Lieu / Ville *"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _cpCtrl,
                      focusNode: _cpFocus,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      decoration: _decoration("C/P"),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              TextFormField(
                controller: _phoneCtrl,
                focusNode: _phoneFocus,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: _decoration("Téléphone (optionnel)"),
              ),

              const SizedBox(height: 12),

              TextFormField(
                controller: _budgetCtrl,
                focusNode: _budgetFocus,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: _decoration("Budget proposé (€)"),
              ),

              const SizedBox(height: 18),

              SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrestoOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _publish,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text(
                    "Publier l'offre",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                "* Champs obligatoires",
                style: TextStyle(fontSize: 12, color: Color(0xFF7A7A7A)),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  }
}

class _MicButton extends StatelessWidget {
  final bool listening;
  final VoidCallback onTap;

  const _MicButton({
    required this.listening,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            listening ? Icons.stop_rounded : Icons.mic_rounded,
            color: kPrestoBlue,
            size: 26,
          ),
        ),
      ),
    );
  }
}
