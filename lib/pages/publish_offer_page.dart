import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, debugPrint;
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cross_file/cross_file.dart';
import '../services/audio_service.dart';
import '../services/micro_ia_service.dart';
import '../features/publish_offer/ai_offer_service.dart';
import '../features/micro_ia/web_audio_recorder_stub.dart'
    if (dart.library.html) '../features/micro_ia/web_audio_recorder.dart';
import '../utils/crashlytics_context.dart';
import '../utils/retry.dart';
import '../utils/friendly_snackbar.dart';
import '../utils/recording_path.dart';
import '../services/city_repo_compact.dart';
import '../widgets/city_postal_autocomplete_compact.dart';
import '../widgets/phone_input_field.dart';
import '../constants.dart';

const kPrestoOrange = Color(0xFFFF6600);
const kPrestoBlue = Color(0xFF1A73E8);

// Palette alignée avec la page "Je consulte": fond clair neutre + accents Presto
const kPrestoBeige = Colors.white;
const kFieldFill = Colors.white;
const kBorder = Color(0xFFE5E7EB);

class PublishOfferPage extends StatefulWidget {
  final CityRepoCompact? repo;

  const PublishOfferPage({
    super.key,
    this.repo,
  });

  @override
  State<PublishOfferPage> createState() => _PublishOfferPageState();
}

class _PublishOfferPageState extends State<PublishOfferPage> {
  final _formKey = GlobalKey<FormState>();
  late final CityRepoCompact _repo;

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
  }

  Future<void> trace(String step, Map<String, dynamic> data) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anon';
      await FirebaseFirestore.instance.collection('debug_microia').add({
        'uid': uid,
        'step': step,
        'data': data,
        'ts': FieldValue.serverTimestamp(),
        'platform': kIsWeb ? 'web' : defaultTargetPlatform.toString(),
      });
    } catch (e) {
      debugPrint('[debug_microia] trace failed: $e');
    }
  }

  // ignore: unused_element
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

  void _applyDraftToForm(OfferDraft draft, {String? transcript}) {
    // ⚠️ Ne jamais modifier Téléphone / Budget ici.

    // Titre
    final nextTitle = (draft.title ?? '').trim();
    if (nextTitle.isNotEmpty && _titleCtrl.text.trim().isEmpty) {
      _titleCtrl.text = nextTitle;
    }

    // Description
    final nextDesc = (draft.description ?? '').trim();
    final currentDesc = _descCtrl.text.trim();
    final transcriptTrim = (transcript ?? '').trim();
    final canReplaceDesc = currentDesc.isEmpty || (transcriptTrim.isNotEmpty && currentDesc == transcriptTrim);
    if (nextDesc.isNotEmpty && canReplaceDesc) {
      _descCtrl.text = nextDesc;
    }

    // Catégorie
    final nextCat = (draft.category ?? '').trim();
    if ((_category == null || _category!.trim().isEmpty) && nextCat.isNotEmpty) {
      // On ne force que si la catégorie fait partie des choix affichés.
      if (_categories.contains(nextCat)) {
        _category = nextCat;
      }
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
  }

  // ignore: unused_element
  Future<void> _toggleMic() async {
    // STT désactivé : on force MicroIA
    await _togglePremiumRecording();
  }

  InputDecoration _decoration(String hint, {Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: kFieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
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
    super.dispose();
  }

  // ignore: unused_element
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

      if (replace != true) return;
    }

    if (_aiLoading) return;

    setState(() => _aiLoading = true);

    try {
      final draft = await AiOfferService.generateDraft(
        hint: _aiHintCtrl.text.trim(),
        currentCity: cityCtrl.text.trim(),
        currentCategory: (_category ?? "").toString(),
      );

      // ✅ Remplissages
      if ((draft.title ?? "").trim().isNotEmpty)
        titleCtrl.text = draft.title!.trim();
      if ((draft.description ?? "").trim().isNotEmpty)
        descCtrl.text = draft.description!.trim();

      // Catégorie si renvoyée
      if ((draft.category ?? "").trim().isNotEmpty) {
        _category = draft.category!.trim();
      }

      // Ville / CP si renvoyés
      if ((draft.city ?? "").trim().isNotEmpty)
        cityCtrl.text = draft.city!.trim();
      if ((draft.postalCode ?? "").trim().isNotEmpty)
        cpCtrl.text = draft.postalCode!.trim();

      // ❌ IMPORTANT : on ne modifie pas Téléphone / Budget

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
        if (!mounted) return;
        setState(() => _recording = false);

        await _stopWebMicAndProcess();
      } else {
        try {
          await _webRec.start();
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
        final filePath = await createTempAudioPath(prefix: 'presto_audio', extension: 'wav');
        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 16000,
            numChannels: 1,
          ),
          path: filePath,
        );

        if (!mounted) return;
        setState(() => _recording = true);
      } else {
        if (!mounted) return;
        showSuccessSnackBar(context, "Permission micro requise");
      }
    }
  }

  Future<void> _stopWebMicAndProcess() async {
    if (_aiLoading) return;
    setState(() => _aiLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('Not authenticated');

      await CrashlyticsContext.setUserId(uid);
      await CrashlyticsContext.setKey('flow', 'webMic');

      final blob = await _webRec.stopToBlob();
      // Ultra perf: conversion côté navigateur -> WAV PCM16 16k mono (évite ffmpeg côté serveur)
      final wavBytes = await webBlobToWav16kMono(blob);

      final bytes = wavBytes.length;
      debugPrint('[IA AUDIO WEB] wavBytes=$bytes');

      await trace('web_before_upload', {
        'bytes': bytes,
      });

      if (bytes < 30000) {
        throw Exception(
          'Audio invalide (blob trop petit: $bytes bytes). Réessaie en parlant plus près du micro.',
        );
      }

      final ts = DateTime.now().millisecondsSinceEpoch;
      final storagePath = 'stt/${uid}_$ts.wav';

      final ref = FirebaseStorage.instance.ref(storagePath);
      await ref.putData(
        wavBytes,
        SettableMetadata(contentType: 'audio/wav'),
      );

      await trace('web_after_upload', {
        'storagePath': storagePath,
        'bytes': bytes,
      });

      final out = await MicroIaService.processAudio(
        storagePath: storagePath,
        languageCode: 'fr-FR',
      );

      final transcript = (out['text'] ?? '').toString();
      if (transcript.trim().isNotEmpty) {
        _descCtrl.text = transcript.trim();
      }

      // Option A: après transcription, générer un brouillon (titre/catégorie/ville/CP)
      try {
        final draft = await AiOfferService.generateDraft(
          hint: transcript.trim().isEmpty ? _descCtrl.text.trim() : transcript.trim(),
          currentCity: _cityCtrl.text.trim(),
          currentCategory: (_category ?? '').trim(),
        );
        _applyDraftToForm(draft, transcript: transcript);
        await trace('web_after_draft', {
          'title': draft.title,
          'category': draft.category,
          'city': draft.city,
          'postalCode': draft.postalCode,
        });
      } catch (e) {
        // best-effort: on garde au minimum la transcription.
        await trace('web_draft_error', {
          'error': e.toString(),
        });
      }

      if (mounted) {
        setState(() {});
        showSuccessSnackBar(context, 'Transcription web OK ✅');
      }
    } catch (e, st) {
      await CrashlyticsContext.recordError(
        e is Exception ? e : Exception(e.toString()),
        st,
        reason: 'Web mic record/process failed',
        fatal: false,
        keys: {
          'component': 'PublishOfferPage',
          'flow': 'webMic',
        },
      );

      if (mounted) {
        if (isTimeoutError(e)) {
          showTimeoutSnackBar(context);
        } else {
          showSuccessSnackBar(context, 'Erreur Premium IA (web) : $e');
        }
      }
    } finally {
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  Future<void> _uploadAndTranscribe(String audioPath) async {
    if (_aiLoading) return;
    setState(() => _aiLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("Utilisateur non connecté");
      }

      await CrashlyticsContext.setUserId(user.uid);
      await CrashlyticsContext.setKey('flow', 'uploadAndTranscribe');

      // Upload vers Cloud Storage (compatible Web: pas de dart:io / putFile)
      final xfile = XFile(audioPath);
      final audioBytes = await xfile.readAsBytes();
      final bytes = audioBytes.length;

      debugPrint('[IA AUDIO] bytes=$bytes path=$audioPath');

      await trace('before_upload', {
        'path': audioPath,
        'bytes': bytes,
      });

      if (bytes < 30000) {
        throw Exception(
          "Audio invalide (fichier trop petit: $bytes bytes). Réessaie en parlant plus près du micro.",
        );
      }

        final lower = audioPath.toLowerCase();
        final isM4a = lower.endsWith('.m4a');
        final isMp4 = lower.endsWith('.mp4');
        final ext = isM4a ? 'm4a' : (isMp4 ? 'mp4' : 'wav');
        final contentType = (isM4a || isMp4) ? 'audio/mp4' : 'audio/wav';

        final fileName = 'stt/${user.uid}_${DateTime.now().millisecondsSinceEpoch}.$ext';

      final storageRef = FirebaseStorage.instance.ref().child(fileName);

      await retry(
        () => storageRef
            .putData(
              audioBytes,
              SettableMetadata(
                contentType: contentType,
                cacheControl: 'private, max-age=3600',
              ),
            )
            .timeout(const Duration(seconds: 60)),
        maxAttempts: 3,
        retryIf: (e) {
          if (e is TimeoutException) return true;
          if (e is FirebaseException) {
            return e.code == 'network-error' ||
                e.code == 'retry-limit-exceeded' ||
                e.code == 'unknown';
          }
          return false;
        },
      );

      final meta = await storageRef.getMetadata();
      debugPrint(
        '[IA AUDIO] uploaded size=${meta.size} bytes contentType=${meta.contentType}',
      );

      await trace('after_upload', {
        'storagePath': fileName,
        'bytes': bytes,
      });

      // Construire le gcsUri
      final bucket = FirebaseStorage.instance.ref().bucket;
      final gcsUri = 'gs://$bucket/$fileName';

      await CrashlyticsContext.setKeys({
        'storagePath': fileName,
        'gcsUri': gcsUri,
      });

      // Appeler le nouveau service Micro-IA
      debugPrint(
          "[IA AUDIO] calling microIaProcessAudio storagePath=$fileName");
      final out = await MicroIaService.processAudio(
        storagePath: fileName, // le path dans le bucket
        languageCode: 'fr-FR',
      );

      debugPrint(
        "[IA AUDIO] microIaProcessAudio OK mode=${out['modeUsed']} score=${out['quality']?['score']}",
      );

      final modeUsed = (out['modeUsed'] ?? '').toString();
      final score = ((out['quality']?['score'] ?? 0.0) as num).toDouble();
      final reasons = (out['quality']?['reasons'] ?? []).toString();

      await trace('after_process', {
        'storagePath': fileName,
        'modeUsed': modeUsed,
        'score': score,
        'reasons': reasons,
      });

      final transcript = (out['text'] ?? '').toString();
      // Info qualité (optionnel)

      // Pour l'instant, on met le transcript dans la description
      // Tu peux ensuite rappeler un autre callable pour générer le draft si besoin
      if (transcript.trim().isNotEmpty) {
        _descCtrl.text = transcript.trim();
      }

      // Option A: après transcription, générer un brouillon (titre/catégorie/ville/CP)
      try {
        final draft = await AiOfferService.generateDraft(
          hint: transcript.trim().isEmpty ? _descCtrl.text.trim() : transcript.trim(),
          currentCity: _cityCtrl.text.trim(),
          currentCategory: (_category ?? '').trim(),
        );
        _applyDraftToForm(draft, transcript: transcript);

        await trace('after_draft', {
          'title': draft.title,
          'category': draft.category,
          'city': draft.city,
          'postalCode': draft.postalCode,
        });
      } catch (e) {
        // best-effort: on garde au minimum la transcription.
        await trace('draft_error', {
          'error': e.toString(),
        });
      }

      if (mounted) {
        setState(() {});
        showSuccessSnackBar(
          context,
          "IA: $modeUsed score=${(score * 100).toStringAsFixed(0)}% reasons=$reasons",
        );
      }

      // Note: nettoyage local non applicable ici (XFile)
    } catch (e, st) {
      await trace('error', {
        'path': audioPath,
        'error': e.toString(),
      });
      await CrashlyticsContext.recordError(
        e is Exception ? e : Exception(e.toString()),
        st,
        reason: 'Upload/transcribe failed',
        fatal: false,
        keys: {
          'component': 'PublishOfferPage',
          'flow': 'uploadAndTranscribe',
        },
      );
      if (mounted) {
        if (isTimeoutError(e)) {
          showTimeoutSnackBar(context);
        } else {
          showSuccessSnackBar(context, "Erreur Premium IA : $e");
        }
      }
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
        'ownerId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'status': 'active',
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
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            onPressed: () {
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
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrestoBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _aiLoading ? null : _togglePremiumRecording,
                    icon: _aiLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Icon(
                            _recording ? Icons.stop_circle : Icons.mic_rounded),
                    label: Text(
                      _aiLoading
                          ? "Analyse en cours..."
                          : (_recording
                              ? "Arrêter l'enregistrement"
                              : "Décrivez votre besoin"),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
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
                      // Bouton Premium avec enregistrement audio (Mobile uniquement)
                      if (!kIsWeb) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: (_aiLoading || _recording)
                                ? null
                                : _togglePremiumRecording,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kPrestoOrange,
                              foregroundColor: Colors.white,
                            ),
                            icon: _recording
                                ? const Icon(Icons.stop_circle,
                                    color: Colors.white)
                                : const Icon(Icons.mic, color: Colors.white),
                            label: Text(_recording
                                ? "Arrêter l'enregistrement"
                                : "🎙️ Premium (Audio)"),
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
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? "Titre obligatoire"
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _category,
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
                        initialValue: _budgetType,
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

// ignore: unused_element
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
