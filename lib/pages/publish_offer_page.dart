import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cross_file/cross_file.dart';
import '../config/env/openai_config.dart';
import '../models/ai/listing_ai_request.dart';
import '../services/audio_service.dart';
import '../services/ai/listing_audio_ai_service.dart';
import '../services/ai/openai_service.dart';
import '../features/publish_offer/ai_offer_service.dart';
import '../features/micro_ia/web_audio_recorder_stub.dart'
    if (dart.library.html) '../features/micro_ia/web_audio_recorder.dart';
import '../utils/crashlytics_context.dart';
import '../utils/friendly_snackbar.dart';
import '../utils/recording_path.dart';
import '../services/city_repo_compact.dart';
import '../services/offer_indexing.dart';
import '../widgets/city_postal_autocomplete_compact.dart';
import '../widgets/phone_input_field.dart';
import '../constants.dart';

const kPrestoOrange = Color(0xFFFF6600);
const kPrestoBlue = Color(0xFF1A73E8);

// Palette alignée avec la page "Je consulte": fond clair neutre + accents Presto
const kPrestoBeige = Colors.white;
const kFieldFill = Colors.white;
const kBorder = Color(0xFFE5E7EB);

@Deprecated(
    'Prototype legacy non utilisé. Utiliser PublishOfferPage dans lib/main.dart.')
class LegacyPublishOfferPage extends StatefulWidget {
  final CityRepoCompact? repo;

  const LegacyPublishOfferPage({
    super.key,
    this.repo,
  });

  @override
  State<LegacyPublishOfferPage> createState() => _LegacyPublishOfferPageState();
}

class _LegacyPublishOfferPageState extends State<LegacyPublishOfferPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final CityRepoCompact _repo;
  final OpenAiService _openAiService = OpenAiService();
  final ListingAudioAiService _listingAudioAiService = ListingAudioAiService();

  final WebAudioRecorder _webRec = WebAudioRecorder();

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

  // STT (speech_to_text) désactivé: Android trop variable, et la page utilise le pipeline Premium Audio.
  bool _aiLoading = false;

  // Pour l'enregistrement audio premium
  late final AudioRecorder _audioRecorder;
  late final AnimationController _recordingPulseController;
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
    _audioRecorder = AudioRecorder();
    _recordingPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  String _normalizedCategoryValue(String value) {
    var normalized = value.trim().toLowerCase();
    const replacements = <String, String>{
      'à': 'a',
      'â': 'a',
      'ä': 'a',
      'ç': 'c',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'î': 'i',
      'ï': 'i',
      'ô': 'o',
      'ö': 'o',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'œ': 'oe',
      '-': ' ',
      '/': ' ',
      '_': ' ',
    };
    replacements.forEach((key, replacement) {
      normalized = normalized.replaceAll(key, replacement);
    });
    return normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String? _resolveSuggestedCategory(String rawCategory) {
    final normalized = _normalizedCategoryValue(rawCategory);
    if (normalized.isEmpty) return null;

    for (final category in _categories) {
      final normalizedCandidate = _normalizedCategoryValue(category);
      if (normalizedCandidate == normalized ||
          normalizedCandidate.contains(normalized) ||
          normalized.contains(normalizedCandidate)) {
        return category;
      }
    }

    const keywordMap = <String, String>{
      'jardin': 'Jardinage',
      'bricol': 'Bricolage',
      'menage': 'Ménage',
      'restauration': 'Restauration / Extra',
      'extra': 'Restauration / Extra',
      'dj': 'DJ / Sono',
      'sono': 'DJ / Sono',
      'baby': 'Baby-sitting',
      'livraison': 'Transport / Livraison',
      'transport': 'Transport / Livraison',
      'informatique': 'Informatique',
      'autre': 'Autre',
    };

    for (final entry in keywordMap.entries) {
      if (normalized.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  void _startRecordingPulse() {
    _recordingPulseController
      ..stop()
      ..reset()
      ..repeat();
  }

  void _stopRecordingPulse() {
    _recordingPulseController
      ..stop()
      ..reset();
  }

  String _buildDraftHint({
    String transcript = '',
    bool includeExistingDescription = false,
  }) {
    final parts = <String>[];

    void addBlock(String label, String value) {
      final clean = value.trim();
      if (clean.isEmpty) return;
      if (parts.any((part) => part.contains(clean))) return;
      parts.add('$label:\n$clean');
    }

    final transcriptText = transcript.trim();
    addBlock('Transcription vocale', transcriptText);

    final typedHint = _aiHintCtrl.text.trim();
    if (typedHint != transcriptText) {
      addBlock('Précisions utilisateur', typedHint);
    }

    if (includeExistingDescription) {
      final currentDescription = _descCtrl.text.trim();
      if (currentDescription != transcriptText &&
          currentDescription != typedHint) {
        addBlock('Description actuelle', currentDescription);
      }
    }

    return parts.join('\n\n').trim();
  }

  void _applyTranscriptFallback(String transcript) {
    final cleanTranscript = transcript.trim();
    if (cleanTranscript.isEmpty) return;

    if (_descCtrl.text.trim().isEmpty) {
      _descCtrl.text = cleanTranscript;
    }
  }

  void _applyDraftToForm(
    OfferDraft draft, {
    String? transcript,
    bool replaceExistingTitleDescription = false,
  }) {
    // ⚠️ Ne jamais modifier Téléphone / Budget ici.
    var shouldRebuild = false;

    // Titre
    final nextTitle = draft.bestTitle();
    if (nextTitle.isNotEmpty &&
        (replaceExistingTitleDescription || _titleCtrl.text.trim().isEmpty)) {
      _titleCtrl.text = nextTitle;
    }

    // Description
    final nextDesc = draft.composedDescription(transcript: transcript);
    final currentDesc = _descCtrl.text.trim();
    final transcriptTrim = (transcript ?? '').trim();
    final canReplaceDesc = replaceExistingTitleDescription ||
        currentDesc.isEmpty ||
        (transcriptTrim.isNotEmpty && currentDesc == transcriptTrim);
    if (nextDesc.isNotEmpty && canReplaceDesc) {
      _descCtrl.text = nextDesc;
    }

    // Catégorie
    final nextCat = (draft.category ?? '').trim();
    final resolvedCategory = _resolveSuggestedCategory(nextCat);
    if ((_category == null || _category!.trim().isEmpty) &&
        resolvedCategory != null) {
      _category = resolvedCategory;
      shouldRebuild = true;
    }

    // Ville / CP
    final nextCity = (draft.city ?? '').trim();
    final nextCp = (draft.postalCode ?? '').trim();
    if (nextCity.isNotEmpty && _cityCtrl.text.trim().isEmpty) {
      _cityCtrl.text = nextCity;
    }
    if (nextCp.isNotEmpty && _cpCtrl.text.trim().isEmpty) {
      _cpCtrl.text = nextCp;
    }

    final inferredBudget = draft.inferredFixedBudgetAmount();
    if (inferredBudget != null && _budgetCtrl.text.trim().isEmpty) {
      _budgetType = 'Fixe';
      _budgetCtrl.text = inferredBudget.toString();
      shouldRebuild = true;
    }

    if (shouldRebuild && mounted) {
      setState(() {});
    }
  }

  ListingAiRequest _buildListingAiRequest({required String input}) {
    return ListingAiRequest(
      input: input,
      city: _cityCtrl.text.trim(),
      category: (_category ?? '').trim(),
      languageCode: OpenAiConfig.defaultLanguageCode,
    );
  }

  OfferDraft _draftFromListingResult(Map<String, dynamic> payload) {
    return OfferDraft.fromMap(payload);
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

    _audioRecorder.dispose();
    _recordingPulseController.dispose();
    super.dispose();
  }

  Future<void> _onFillWithAI() async {
    if (_aiLoading) return;
    // ⚠️ adapte ces noms si tes controllers s'appellent autrement
    // ex: _titleController au lieu de _titleCtrl
    final titleCtrl = _titleCtrl;
    final descCtrl = _descCtrl;
    final cityCtrl = _cityCtrl;
    final cpCtrl = _cpCtrl;

    // Téléphone + Budget => on ne touche pas :
    // final phoneCtrl = _phoneCtrl;
    // final budgetCtrl = _budgetCtrl;

    // Si déjà rempli, on demande si on remplace
    var replaceExistingTitleDescription = false;
    if (titleCtrl.text.trim().isNotEmpty || descCtrl.text.trim().isNotEmpty) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            "Remplissage IA",
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: const Text(
            "Tu veux remplacer le titre/description actuels ?",
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Non")),
            ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Remplacer")),
          ],
        ),
      );

      if (!mounted) return;
      if (replace == null) return;
      replaceExistingTitleDescription = replace;
    }

    if (_aiLoading) return;

    final hint = _buildDraftHint(includeExistingDescription: true);
    if (hint.isEmpty) {
      showSuccessSnackBar(
        context,
        "Ajoutez quelques précisions avant de lancer l'assistant IA.",
      );
      return;
    }

    setState(() => _aiLoading = true);

    try {
      final draft = await _openAiService.extractListingFieldsFromText(
        _buildListingAiRequest(input: hint),
      );

      _applyDraftToForm(
        _draftFromListingResult(draft.toDraftPayload()),
        replaceExistingTitleDescription: replaceExistingTitleDescription,
      );

      if (mounted) {
        setState(() {});
        showSuccessSnackBar(context, "Brouillon IA généré ✅");
      }
    } catch (e) {
      if (mounted) {
        if (isTimeoutError(e)) {
          showTimeoutSnackBar(context);
        } else {
          showSuccessSnackBar(context, "Erreur IA : $e");
        }
      }
    } finally {
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  /// Enregistrement audio Premium avec transcription Chirp 3 EU + Rédaction Gemini
  Future<void> _togglePremiumRecording() async {
    if (_aiLoading) return;

    if (kIsWeb) {
      if (_recording) {
        _stopRecordingPulse();
        if (!mounted) return;
        setState(() => _recording = false);

        await _stopWebMicAndProcess();
      } else {
        try {
          await _webRec.start();
          _startRecordingPulse();
          if (!mounted) return;
          setState(() => _recording = true);
        } catch (e) {
          if (!mounted) return;
          showSuccessSnackBar(context, 'Micro web indisponible: $e');
        }
      }
      return;
    }

    if (_recording) {
      // Arrêter l'enregistrement
      final path = await _audioRecorder.stop();
      _stopRecordingPulse();
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
        // Ultra perf: WAV PCM16 16k mono (évite ffmpeg côté serveur)
        final filePath =
            await createTempAudioPath(prefix: 'presto_audio', extension: 'wav');
        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 16000,
            numChannels: 1,
          ),
          path: filePath,
        );

        _startRecordingPulse();
        if (!mounted) return;
        setState(() => _recording = true);
      } else {
        if (!mounted) return;
        showSuccessSnackBar(context, "Permission micro requise");
      }
    }
  }

  Future<void> _stopWebMicAndProcess() async {
    try {
      final blob = await _webRec.stopToBlob();
      final wavBytes = await webBlobToWav16kMono(blob);
      await _processRecordedAudioBytes(
        audioBytes: wavBytes,
        contentType: 'audio/wav',
        extension: 'wav',
        flow: 'webMic',
      );
    } catch (e) {
      // Crashlytics already reported inside _processRecordedAudioBytes
      if (mounted) {
        if (isTimeoutError(e)) {
          showTimeoutSnackBar(context);
        } else {
          showSuccessSnackBar(context, 'Erreur Premium IA (web) : $e');
        }
      }
    }
  }

  Future<void> _uploadAndTranscribe(String audioPath) async {
    if (_aiLoading) return;

    try {
      final audioBytes = await XFile(audioPath).readAsBytes();
      final lower = audioPath.toLowerCase();
      final extension = lower.endsWith('.m4a')
          ? 'm4a'
          : (lower.endsWith('.mp4') ? 'mp4' : 'wav');
      final contentType = extension == 'wav' ? 'audio/wav' : 'audio/mp4';

      await _processRecordedAudioBytes(
        audioBytes: audioBytes,
        contentType: contentType,
        extension: extension,
        flow: 'uploadAndTranscribe',
      );
    } catch (e) {
      // Crashlytics already reported inside _processRecordedAudioBytes
      if (mounted) {
        if (isTimeoutError(e)) {
          showTimeoutSnackBar(context);
        } else {
          showSuccessSnackBar(context, "Erreur Premium IA : $e");
        }
      }
    }
  }

  Future<void> _processRecordedAudioBytes({
    required Uint8List audioBytes,
    required String contentType,
    required String extension,
    required String flow,
  }) async {
    if (_aiLoading) return;
    setState(() => _aiLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("Utilisateur non connecté");
      }

      await CrashlyticsContext.setUserId(user.uid);
      await CrashlyticsContext.setKey('flow', flow);

      final bytes = audioBytes.length;
      debugPrint('[IA AUDIO] bytes=$bytes flow=$flow');

      if (bytes < 30000) {
        throw Exception(
          "Audio invalide (fichier trop petit: $bytes bytes). Réessaie en parlant plus près du micro.",
        );
      }

      final result = await _listingAudioAiService
          .extractListingFieldsFromAudioBytes(
            ownerUid: user.uid,
            audioBytes: audioBytes,
            contentType: contentType,
            extension: extension,
            request: _buildListingAiRequest(input: ''),
          )
          .timeout(const Duration(seconds: 90));

      final transcript = result.transcriptText;
      final score = result.confidenceScore ?? 0.0;

      // Apply transcript immediately as fallback
      _applyTranscriptFallback(transcript);

      if (transcript.isNotEmpty) {
        final draft = _draftFromListingResult(result.toDraftPayload());
        _applyDraftToForm(draft, transcript: transcript);
      }

      if (mounted) {
        setState(() {});
        final qualityPct = (score * 100).clamp(0, 100).toStringAsFixed(0);
        showSuccessSnackBar(
          context,
          transcript.isEmpty
              ? 'Analyse IA terminée. Vérifiez les champs.'
              : 'Transcription IA appliquée ($qualityPct%). Vérifiez les champs avant publication.',
        );
      }
    } catch (e, st) {
      await CrashlyticsContext.recordError(
        e is Exception ? e : Exception(e.toString()),
        st,
        reason: 'Recorded audio processing failed',
        fatal: false,
        keys: {
          'component': 'PublishOfferPage',
          'flow': flow,
        },
      );
      rethrow;
    } finally {
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  void _publish() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      showSuccessSnackBar(context, "Vous devez être connecté");
      return;
    }

    try {
      final city = _cityCtrl.text.trim();
      final cp = _cpCtrl.text.trim();
      final budgetStr = _budgetCtrl.text.trim();
      final budget = budgetStr.isEmpty ? null : int.tryParse(budgetStr);
      final normalizedOffer = buildOfferIndexFields(
        category: _category ?? 'Autre',
        city: city,
        postalCode: cp,
        budget: budget,
        isActive: true,
        status: 'active',
      );

      await FirebaseFirestore.instance.collection('offers').add({
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'budget': budget,
        'budgetType': _budgetType,
        'phone': _phoneCtrl.text.trim().isEmpty
            ? null
            : '${_phoneCountryCode.trim()} ${_phoneCtrl.text.trim()}',
        'userId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        ...normalizedOffer,
      });

      if (!mounted) return;

      showSuccessSnackBar(context, "Offre publiée avec succès ✅");

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      showSuccessSnackBar(context, "Erreur lors de la publication : $e");
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
          style: kPrestoAppBarTitleStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
          ),
        ],
      ),
      body: SafeArea(
        child: Container(
          color: Colors.white,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              children: [
                AnimatedBuilder(
                  animation: _recordingPulseController,
                  builder: (context, _) => _MicButton(
                    listening: _recording,
                    loading: _aiLoading,
                    pulseValue: _recordingPulseController.value,
                    onPressed: _aiLoading ? null : _togglePremiumRecording,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(15),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text("Assistant IA",
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _aiHintCtrl,
                        decoration: const InputDecoration(
                          labelText: "Décris ton besoin (optionnel)",
                          hintText:
                              "Ex: Peintre pour salon, urgent demain, Les Abymes…",
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed:
                              (_aiLoading || _recording) ? null : _onFillWithAI,
                          icon: const Icon(Icons.auto_awesome_rounded),
                          label: const Text('Remplir à partir du texte'),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "Parlez avec le bouton au-dessus ou saisissez quelques précisions ici. L'IA complète le titre, la description, la catégorie, la ville, le code postal et le budget quand il est clairement détecté.",
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleCtrl,
                  focusNode: _titleFocus,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration("Titre de l'offre *"),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? "Titre obligatoire"
                      : null,
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
                  labelText: 'Téléphone de contact (optionnel)',
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
                            .map((t) =>
                                DropdownMenuItem(value: t, child: Text(t)))
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
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
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
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
  final bool loading;
  final double pulseValue;
  final VoidCallback? onPressed;

  const _MicButton({
    required this.listening,
    required this.loading,
    required this.pulseValue,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    final baseColor = listening ? const Color(0xFFD72638) : kPrestoBlue;
    final glowColor = listening ? const Color(0xFFFF7A7A) : kPrestoBlue;
    final title = loading
        ? 'Analyse en cours...'
        : (listening ? 'Stop' : 'Décrire mon besoin (IA)');
    final subtitle = loading
        ? 'Transcription et remplissage de l’annonce'
        : (listening
            ? 'Parlez maintenant puis appuyez sur stop'
            : 'Touchez pour lancer l’enregistrement vocal');

    return SizedBox(
      height: 92,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (listening) ...[
            Transform.scale(
              scale: 1.0 + (pulseValue * 0.18),
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: glowColor.withAlpha(40),
                ),
              ),
            ),
            Transform.scale(
              scale: 1.0 + (pulseValue * 0.32),
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: glowColor.withAlpha(18),
                ),
              ),
            ),
          ],
          Opacity(
            opacity: isEnabled ? 1 : 0.65,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: onPressed,
                child: Ink(
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: listening
                          ? const [Color(0xFFE53935), Color(0xFFB71C1C)]
                          : const [kPrestoBlue, Color(0xFF0D47A1)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: baseColor.withAlpha(45),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withAlpha(28),
                          ),
                          child: loading
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : Icon(
                                  listening
                                      ? Icons.stop_circle_rounded
                                      : Icons.mic_rounded,
                                  color: Colors.white,
                                  size: 26,
                                ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  color: Colors.white.withAlpha(220),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          listening
                              ? Icons.radio_button_checked_rounded
                              : Icons.graphic_eq_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
