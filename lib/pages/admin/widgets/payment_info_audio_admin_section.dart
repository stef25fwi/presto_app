import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:presto_app/services/firebase_functions_region.dart';
import 'package:presto_app/services/payment_info_audio_service.dart';

class PaymentInfoAudioAdminSection extends StatefulWidget {
  const PaymentInfoAudioAdminSection({super.key});

  @override
  State<PaymentInfoAudioAdminSection> createState() =>
      _PaymentInfoAudioAdminSectionState();
}

class _PaymentInfoAudioAdminSectionState
    extends State<PaymentInfoAudioAdminSection> {
  final _service = PaymentInfoAudioService();
  bool _uploading = false;
  bool _generating = false;

  Future<void> _pickAndUploadMp3() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final Uint8List? bytes = file.bytes;
    if (bytes == null) {
      _showSnack('Fichier MP3 non lisible.');
      return;
    }
    setState(() => _uploading = true);
    try {
      await _service.uploadAudio(bytes, file.name);
      _showSnack('Audio du popup mis à jour.');
    } catch (e) {
      _showSnack('Erreur upload audio : $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _generateMp3FromText() async {
    setState(() => _generating = true);
    try {
      await callPrestoFunction<dynamic>(
        functions: prestoFirebaseFunctions,
        name: 'generatePaymentInfoAudio',
        timeout: const Duration(seconds: 120),
        area: 'admin-audio',
      );
      _showSnack('MP3 régénéré depuis le texte du popup.');
    } on FirebaseFunctionsException catch (e) {
      _showSnack('Erreur génération : ${e.message ?? e.code}');
    } catch (e) {
      _showSnack('Erreur génération : $e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String?>(
      stream: _service.watchAudioUrl(),
      builder: (context, snapshot) {
        final audioUrl = snapshot.data;
        final hasAudio = audioUrl?.isNotEmpty == true;
        final busy = _uploading || _generating;
        return Card(
          elevation: 0,
          margin: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Lecture popup paiement',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF07184A),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Mets à jour le fichier MP3 lu dans le popup "Infos paiement".\n'
                  'Tu peux importer un MP3 manuellement ou régénérer depuis le texte du popup via IA (OpenAI TTS).',
                  style: TextStyle(fontSize: 14, color: Color(0xFF4A5878)),
                ),
                const SizedBox(height: 12),
                Text(
                  hasAudio
                      ? 'MP3 configuré dans Firebase Storage.'
                      : 'Aucun MP3 configuré.',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: hasAudio ? Colors.green : Colors.orange,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: busy ? null : _generateMp3FromText,
                    icon: _generating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome_rounded),
                    label: Text(
                      _generating
                          ? 'Génération en cours...'
                          : 'Régénérer le MP3 depuis le texte (IA)',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : _pickAndUploadMp3,
                    icon: _uploading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file_rounded),
                    label: Text(
                      _uploading
                          ? 'Upload en cours...'
                          : 'Importer un MP3 manuellement',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
