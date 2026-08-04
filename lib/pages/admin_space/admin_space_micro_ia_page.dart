// Écran de réglage de la transcription Micro IA.
//
// Fragment de la bibliothèque `admin_space_page.dart` : le découpage
// réduit la taille des fichiers sans modifier la visibilité des types.
part of '../admin_space_page.dart';

enum MicroIaMode { google, whisper, hybride }

enum MicroIaAudioQuality { low, medium, high }

String microIaAudioQualityToRcValue(MicroIaAudioQuality q) {
  switch (q) {
    case MicroIaAudioQuality.low:
      return "LOW";
    case MicroIaAudioQuality.medium:
      return "MEDIUM";
    case MicroIaAudioQuality.high:
      return "HIGH";
  }
}

MicroIaAudioQuality microIaAudioQualityFromRcValue(String v) {
  switch (v.toUpperCase()) {
    case "LOW":
      return MicroIaAudioQuality.low;
    case "HIGH":
      return MicroIaAudioQuality.high;
    default:
      return MicroIaAudioQuality.medium;
  }
}

class MicroIaTranscriptionPage extends StatefulWidget {
  const MicroIaTranscriptionPage({super.key});

  @override
  State<MicroIaTranscriptionPage> createState() =>
      _MicroIaTranscriptionPageState();
}

class _MicroIaTranscriptionPageState extends State<MicroIaTranscriptionPage> {
  static const Color prestoOrange = Color(0xFFFF6600);
  static const Color prestoBlue = Color(0xFF1A73E8);

  final FirebaseFunctions _functions = prestoFirebaseFunctions;

  bool _loading = true;
  bool _saving = false;

  MicroIaMode _mode = MicroIaMode.hybride;
  MicroIaAudioQuality _audioQuality = MicroIaAudioQuality.medium;
  bool _fallback = true;
  double _quality = 0.62;
  bool _ultraFastEnabled = false;
  final List<String> _languages = ['fr-FR'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _prepareAdminCallableAuth() async {
    try {
      await MicroIaService.prepareSecureCallableContext(
        forceRefreshToken: true,
        forceRefreshAppCheckToken: true,
      );
    } catch (_) {
      // Best effort: the callable will still provide the definitive auth error.
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      await _prepareAdminCallableAuth();
      final callable = _functions.httpsCallable(
        'adminGetMicroIaConfig',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
      );
      HttpsCallableResult<dynamic> res;
      try {
        res = await callable.call<dynamic>({});
      } on FirebaseFunctionsException catch (e) {
        if (e.code != 'unauthenticated' && e.code != 'permission-denied') {
          rethrow;
        }
        await _prepareAdminCallableAuth();
        res = await callable.call<dynamic>({});
      }
      final data = Map<String, dynamic>.from(res.data as Map);

      final modeStr = (data['mode'] ?? 'HYBRID').toString().toUpperCase();
      final fallback = data['fallbackEnabled'] == true;
      final threshold = (data['qualityThreshold'] as num?)?.toDouble() ?? 0.62;
      final lang = (data['languageCode'] ?? 'fr-FR').toString().trim();
      final audioQualityStr = (data['audioQuality'] ??
              data['audio_quality'] ??
              data['microia_audio_quality'] ??
              'MEDIUM')
          .toString();
      final ultraFast = (data['ultraFastEnabled'] ??
              data['microia_ultra_fast_enabled'] ??
              data['microia_ultrafast_enabled'] ??
              data['microia_ultra_fast'] ??
              false) ==
          true;

      setState(() {
        _mode = _modeFromRemote(modeStr);
        _fallback = fallback;
        _quality = threshold.clamp(0.0, 1.0);
        _audioQuality = microIaAudioQualityFromRcValue(audioQualityStr);
        _ultraFastEnabled = ultraFast;
        _languages
          ..clear()
          ..add(lang.isEmpty ? 'fr-FR' : lang);
      });
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      if (e.code == 'permission-denied' || e.code == 'unauthenticated') {
        _snack('Accès admin requis.');
        Navigator.of(context).maybePop();
        return;
      }
      _snack(e.message ?? 'Erreur admin');
    } catch (e) {
      if (!mounted) return;
      _snack('Erreur admin: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  MicroIaMode _modeFromRemote(String mode) {
    switch (mode) {
      case 'GOOGLE_ONLY':
        return MicroIaMode.google;
      case 'WHISPER_ONLY':
        return MicroIaMode.whisper;
      case 'HYBRID':
      default:
        return MicroIaMode.hybride;
    }
  }

  String _modeToRemote(MicroIaMode mode) {
    switch (mode) {
      case MicroIaMode.google:
        return 'GOOGLE_ONLY';
      case MicroIaMode.whisper:
        return 'WHISPER_ONLY';
      case MicroIaMode.hybride:
        return 'HYBRID';
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      await _prepareAdminCallableAuth();
      final callable = _functions.httpsCallable(
        'adminSetMicroIaConfig',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );

      final lang = _languages.isNotEmpty ? _languages.first.trim() : 'fr-FR';

      final res = await callable.call<dynamic>({
        'mode': _modeToRemote(_mode),
        'fallbackEnabled': _fallback,
        'qualityThreshold': _quality,
        'languageCode': lang.isEmpty ? 'fr-FR' : lang,
        'microia_audio_quality': microIaAudioQualityToRcValue(_audioQuality),
        'ultraFastEnabled': _ultraFastEnabled,
      });

      final data = (res.data is Map)
          ? Map<String, dynamic>.from(res.data as Map)
          : <String, dynamic>{};

      final modeStr = (data['mode'] ?? _modeToRemote(_mode)).toString();
      final fallback = data['fallbackEnabled'] == true;
      final threshold =
          (data['qualityThreshold'] as num?)?.toDouble() ?? _quality;
      final languageCode = (data['languageCode'] ?? lang).toString();
      final audioQualityStr = (data['audioQuality'] ??
              data['audio_quality'] ??
              data['microia_audio_quality'] ??
              microIaAudioQualityToRcValue(_audioQuality))
          .toString();
      final ultraFast = (data['ultraFastEnabled'] ??
              data['microia_ultra_fast_enabled'] ??
              data['microia_ultrafast_enabled'] ??
              data['microia_ultra_fast'] ??
              _ultraFastEnabled) ==
          true;

      setState(() {
        _mode = _modeFromRemote(modeStr.toUpperCase());
        _fallback = fallback;
        _quality = threshold.clamp(0.0, 1.0);
        _audioQuality = microIaAudioQualityFromRcValue(audioQualityStr);
        _ultraFastEnabled = ultraFast;
        _languages
          ..clear()
          ..add(languageCode.trim().isEmpty ? 'fr-FR' : languageCode.trim());
      });

      _snack('Enregistré (Remote Config)');
    } on FirebaseFunctionsException catch (e) {
      _snack(e.message ?? 'Erreur admin');
    } catch (e) {
      _snack('Erreur admin: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    showSuccessSnackBar(context, msg);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A73E8),
        foregroundColor: Colors.white,
        elevation: 0.5,
        titleSpacing: 16,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: 'Retour',
        ),
        title: const Text(
          'Micro-IA — Transcription',
          style: kPrestoAppBarTitleStyle,
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(prestoOrange),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: _MicroIaCard(
                  prestoOrange: prestoOrange,
                  prestoBlue: prestoBlue,
                  mode: _mode,
                  audioQuality: _audioQuality,
                  fallback: _fallback,
                  quality: _quality,
                  ultraFastEnabled: _ultraFastEnabled,
                  languages: _languages,
                  onModeChanged: (m) => setState(() => _mode = m),
                  onUltraFastChanged: (v) =>
                      setState(() => _ultraFastEnabled = v),
                  onAudioQualityChanged: (q) async {
                    final prev = _audioQuality;
                    setState(() => _audioQuality = q);

                    try {
                      await _prepareAdminCallableAuth();
                      final callable = _functions.httpsCallable(
                        'adminSetMicroIaConfig',
                        options: HttpsCallableOptions(
                          timeout: const Duration(seconds: 30),
                        ),
                      );

                      final lang = _languages.isNotEmpty
                          ? _languages.first.trim()
                          : 'fr-FR';

                      await callable.call<dynamic>({
                        'mode': _modeToRemote(_mode),
                        'fallbackEnabled': _fallback,
                        'qualityThreshold': _quality,
                        'languageCode': lang.isEmpty ? 'fr-FR' : lang,
                        'audio_quality': microIaAudioQualityToRcValue(q),
                        'ultraFastEnabled': _ultraFastEnabled,
                      });
                    } on FirebaseFunctionsException catch (e) {
                      if (mounted) setState(() => _audioQuality = prev);
                      _snack(e.message ?? 'Erreur admin');
                    } catch (e) {
                      if (mounted) setState(() => _audioQuality = prev);
                      _snack('Erreur admin: $e');
                    }
                  },
                  onFallbackChanged: (v) => setState(() => _fallback = v),
                  onQualityChanged: (v) => setState(() => _quality = v),
                  onAddLanguage: () =>
                      _snack('Ajouter une langue (à brancher)'),
                  onRemoveLanguage: (code) =>
                      setState(() => _languages.remove(code)),
                  onSave: _saving ? null : _save,
                  saving: _saving,
                ),
              ),
      ),
    );
  }
}
