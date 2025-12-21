import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../services/audio_service.dart';
import 'package:path_provider/path_provider.dart' if (dart.library.html) '';
import 'dart:io' if (dart.library.html) 'dart:html';
import '../services/city_repo_compact.dart';
import '../widgets/city_postal_autocomplete_compact.dart';
import '../widgets/phone_input_field.dart';

const kPrestoOrange = Color(0xFFFF6600);
const kPrestoBlue = Color(0xFF1A73E8);

// Palette alignée avec la page "Je consulte": fond clair neutre + accents Presto
const kPrestoBeige = Colors.white;
const kFieldFill = Colors.white;
const kBorder = Color(0xFFE5E7EB);

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
  final _aiHintCtrl = TextEditingController();

  String _phoneCountryCode = '+33';

  // Budget: type (fixe / à négocier)
  final List<String> _budgetTypes = const ['Fixe', 'À négocier'];
  String _budgetType = 'Fixe';

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
  String _lastTranscript = '';
  bool _aiLoading = false;

  // Pour l'enregistrement audio premium
  late final AudioRecorder _audioRecorder;
  bool _recording = false;

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
    _audioRecorder = AudioRecorder();
    
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
      // Fallback automatique: utiliser l'IA texte pour auto-remplir
      await _fallbackTextAi();
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

        _lastTranscript = text;
        // Remplit / met à jour le champ actif
        ctrl.value = ctrl.value.copyWith(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
          composing: TextRange.empty,
        );
        setState(() {});

        // Quand la reconnaissance est finale, on enchaîne sur l'IA pour auto-remplir
        if (res.finalResult) {
          _runMicAiDraft();
        }
      },
    );
  }

  Future<void> _fallbackTextAi() async {
    // Utilise la description actuelle ou le titre comme indice pour l'IA
    final seedDesc = _descCtrl.text.trim();
    final seedTitle = _titleCtrl.text.trim();
    final hint = seedDesc.isNotEmpty ? seedDesc : seedTitle;

    if (hint.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ajoute une description ou un titre pour l'IA")),
      );
      return;
    }

    _aiHintCtrl.text = hint;
    await _onFillWithAI();
  }

  Future<void> _runMicAiDraft() async {
    final hint = _lastTranscript.trim();
    if (hint.isEmpty || _aiLoading) return;

    setState(() => _aiLoading = true);
    try {
      final draft = await AiOfferService.generateDraft(
        hint: hint,
        currentCity: _cityCtrl.text.trim(),
        currentCategory: _category ?? '',
      );

      if ((draft.title ?? '').trim().isNotEmpty) {
        _titleCtrl.text = draft.title!.trim();
      }
      if ((draft.description ?? '').trim().isNotEmpty) {
        _descCtrl.text = draft.description!.trim();
      }
      if ((draft.category ?? '').trim().isNotEmpty) {
        _category = draft.category!.trim();
      }
      if ((draft.city ?? '').trim().isNotEmpty) {
        _cityCtrl.text = draft.city!.trim();
      }
      if ((draft.postalCode ?? '').trim().isNotEmpty) {
        _cpCtrl.text = draft.postalCode!.trim();
      }

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Texte vocal analysé par l\'IA ✅')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur IA après dictée : $e')),
      );
    } finally {
      if (mounted) setState(() => _aiLoading = false);
    }
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
    _aiHintCtrl.dispose();

    _titleFocus.dispose();
    _descFocus.dispose();
    _cityFocus.dispose();
    _cpFocus.dispose();
    _phoneFocus.dispose();
    _budgetFocus.dispose();

    _stt.stop();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _onFillWithAI() async {
    // ⚠️ adapte ces noms si tes controllers s'appellent autrement
    // ex: _titleController au lieu de _titleCtrl
    final titleCtrl = _titleCtrl;
    final descCtrl  = _descCtrl;
    final cityCtrl  = _cityCtrl;
    final cpCtrl    = _cpCtrl;

    // Téléphone + Budget => on ne touche pas :
    // final phoneCtrl = _phoneCtrl;
    // final budgetCtrl = _budgetCtrl;

    // Si déjà rempli, on demande si on remplace
    if (titleCtrl.text.trim().isNotEmpty || descCtrl.text.trim().isNotEmpty) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Remplissage IA"),
          content: const Text("Tu veux remplacer le titre/description actuels ?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Non")),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Remplacer")),
          ],
        ),
      );

      if (replace != true) return;
    }

    setState(() => _aiLoading = true);

    try {
      final draft = await AiOfferService.generateDraft(
        hint: _aiHintCtrl.text.trim(),
        currentCity: cityCtrl.text.trim(),
        currentCategory: (_category ?? "").toString(),
      );

      // ✅ Remplissages
      if ((draft.title ?? "").trim().isNotEmpty) titleCtrl.text = draft.title!.trim();
      if ((draft.description ?? "").trim().isNotEmpty) descCtrl.text = draft.description!.trim();

      // Catégorie si renvoyée
      if ((draft.category ?? "").trim().isNotEmpty) {
        _category = draft.category!.trim();
      }

      // Ville / CP si renvoyés
      if ((draft.city ?? "").trim().isNotEmpty) cityCtrl.text = draft.city!.trim();
      if ((draft.postalCode ?? "").trim().isNotEmpty) cpCtrl.text = draft.postalCode!.trim();

      // ❌ IMPORTANT : on ne modifie pas Téléphone / Budget

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Brouillon IA généré ✅")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur IA : $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  /// Enregistrement audio Premium avec transcription Chirp 3 EU + Rédaction Gemini
  Future<void> _togglePremiumRecording() async {
    if (_recording) {
      // Arrêter l'enregistrement
      final path = await _audioRecorder.stop();
      if (!mounted) return;
      
      setState(() {
        _recording = false;
      });

      if (path != null && path.isNotEmpty) {
        await _uploadAndTranscribe(path);
      }
    } else {
      // Démarrer l'enregistrement
      if (await _audioRecorder.hasPermission()) {
        final directory = await getTemporaryDirectory();
        final filePath = '${directory.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            sampleRate: 16000,
            numChannels: 1,
          ),
          path: filePath,
        );
        
        if (!mounted) return;
        setState(() => _recording = true);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Permission micro requise")),
        );
      }
    }
  }

  Future<void> _uploadAndTranscribe(String audioPath) async {
    setState(() => _aiLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("Utilisateur non connecté");
      }

      // Upload vers Cloud Storage
      final file = File(audioPath);
      final fileName = 'stt/${user.uid}_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final storageRef = FirebaseStorage.instance.ref().child(fileName);
      
      await storageRef.putFile(file);
      
      // Construire le gcsUri
      final bucket = FirebaseStorage.instance.ref().bucket;
      final gcsUri = 'gs://$bucket/$fileName';

      // Appeler la Cloud Function Premium
      final result = await AiOfferService.transcribeAndDraft(
        gcsUri: gcsUri,
        languageCode: 'fr-FR',
        category: _category ?? '',
        city: _cityCtrl.text.trim(),
      );

      // Remplir les champs
      if ((result.draft.title ?? '').trim().isNotEmpty) {
        _titleCtrl.text = result.draft.title!.trim();
      }
      if ((result.draft.description ?? '').trim().isNotEmpty) {
        _descCtrl.text = result.draft.description!.trim();
      }
      if ((result.draft.category ?? '').trim().isNotEmpty) {
        _category = result.draft.category!.trim();
      }
      if ((result.draft.city ?? '').trim().isNotEmpty) {
        _cityCtrl.text = result.draft.city!.trim();
      }
      if ((result.draft.postalCode ?? '').trim().isNotEmpty) {
        _cpCtrl.text = result.draft.postalCode!.trim();
      }

      // ❌ IMPORTANT : on ne touche pas téléphone/budget

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ Transcription Premium réussie!\n${result.transcript.substring(0, result.transcript.length > 50 ? 50 : result.transcript.length)}..."),
            duration: const Duration(seconds: 4),
          ),
        );
      }

      // Nettoyer le fichier temporaire
      try {
        await file.delete();
      } catch (_) {}

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur Premium IA : $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _aiLoading = false);
    }
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
        'budgetType': _budgetType,
        'phone': _phoneCtrl.text.trim().isEmpty
            ? null
            : '${_phoneCountryCode.trim()} ${_phoneCtrl.text.trim()}',
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
      backgroundColor: Colors.white,
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
          color: Colors.white,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: _MicButton(
                    listening: _listening,
                    onTap: _toggleMic,
                  ),
                ),

                const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text("Assistant IA", style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _aiHintCtrl,
                      decoration: const InputDecoration(
                        labelText: "Décris ton besoin (optionnel)",
                        hintText: "Ex: Peintre pour salon, urgent demain, Les Abymes…",
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _aiLoading ? null : _onFillWithAI,
                        icon: _aiLoading
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.auto_awesome),
                        label: Text(_aiLoading ? "Génération..." : "Remplir automatiquement"),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Bouton Premium avec enregistrement audio (Mobile uniquement)
                    if (!kIsWeb) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: (_aiLoading || _recording) ? null : _togglePremiumRecording,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrestoOrange,
                            foregroundColor: Colors.white,
                          ),
                          icon: _recording
                              ? const Icon(Icons.stop_circle, color: Colors.white)
                              : const Icon(Icons.mic, color: Colors.white),
                          label: Text(_recording ? "Arrêter l'enregistrement" : "🎙️ Premium (Audio)"),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "Premium : Transcription Chirp 3 + Rédaction IA avancée. Téléphone et budget restent à saisir manuellement.",
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                    if (kIsWeb) ...[
                      const SizedBox(height: 6),
                      const Text(
                        "📱 L'enregistrement audio Premium est disponible sur l'app mobile. Téléphone et budget restent à saisir manuellement.",
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

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

              PhoneInputFieldCompact(
                controller: _phoneCtrl,
                labelText: 'Téléphone (optionnel)',
                hintText: '612345678',
                focusNode: _phoneFocus,
                onCountryCodeChanged: (code) => _phoneCountryCode = code,
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: _budgetType,
                      items: _budgetTypes
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          _budgetType = v;
                          if (_budgetType == 'À négocier') {
                            _budgetCtrl.clear();
                          }
                        });
                      },
                      decoration: _decoration(
                        "Budget (fixe ou à négocier)",
                        suffix: const Icon(Icons.keyboard_arrow_down_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _budgetCtrl,
                      focusNode: _budgetFocus,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: _decoration("Montant (€)"),
                      enabled: _budgetType == 'Fixe',
                    ),
                  ),
                ],
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: listening ? kPrestoOrange : kPrestoBlue,
          shape: const CircleBorder(),
          elevation: 4,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: listening 
                  ? null
                  : const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [kPrestoBlue, Color(0xFF0D47A1)],
                    ),
              ),
              child: Icon(
                listening ? Icons.stop_rounded : Icons.mic_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: listening ? kPrestoOrange : kPrestoBlue,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            listening ? 'STOP' : 'IA 🎤',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// Service IA pour générer un brouillon d'offre
// ============================================================================

class OfferDraft {
  final String? title;
  final String? description;
  final String? category;
  final String? city;
  final String? postalCode;
  final List<String>? bullets;
  final List<String>? constraints;

  OfferDraft({
    this.title,
    this.description,
    this.category,
    this.city,
    this.postalCode,
    this.bullets,
    this.constraints,
  });

  factory OfferDraft.fromMap(Map<String, dynamic> m) => OfferDraft(
        title: m['title'] as String?,
        description: m['description'] as String?,
        category: m['category'] as String?,
        city: m['city'] as String?,
        postalCode: m['postalCode'] as String?,
        bullets: m['bullets'] != null ? List<String>.from(m['bullets'] as List) : null,
        constraints: m['constraints'] != null ? List<String>.from(m['constraints'] as List) : null,
      );
}

class AiOfferService {
  /// Génère un brouillon à partir d'un texte (sans audio)
  static Future<OfferDraft> generateDraft({
    required String hint,
    required String currentCity,
    required String currentCategory,
  }) async {
    final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
      .httpsCallable('generateOfferDraft');
    final res = await callable.call({
      'hint': hint,
      'city': currentCity,
      'category': currentCategory,
      'lang': 'fr',
    });

    final data = Map<String, dynamic>.from(res.data as Map);
    return OfferDraft.fromMap(data);
  }

  /// Transcription Premium (Chirp 3) + Rédaction IA
  static Future<({String transcript, OfferDraft draft})> transcribeAndDraft({
    required String gcsUri,
    required String languageCode,
    required String category,
    required String city,
  }) async {
    final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
      .httpsCallable('transcribeAndDraftOffer');
    final res = await callable.call({
      'gcsUri': gcsUri,
      'languageCode': languageCode,
      'category': category,
      'city': city,
    });

    final data = Map<String, dynamic>.from(res.data as Map);
    final transcript = (data['transcript'] ?? '').toString();
    final draftMap = Map<String, dynamic>.from(data['draft'] as Map);
    final draft = OfferDraft.fromMap(draftMap);

    return (transcript: transcript, draft: draft);
  }
}
