import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
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
      final ref = FirebaseStorage.instance.ref(
        PaymentInfoAudioService.storagePath,
      );
      await ref.putData(
        bytes,
        SettableMetadata(
          contentType: 'audio/mpeg',
          customMetadata: {
            'usage': 'payment_info_popup',
            'fileName': file.name,
          },
        ),
      );
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance
          .collection(PaymentInfoAudioService.configCollection)
          .doc(PaymentInfoAudioService.configDoc)
          .set({
        'audioUrl': url,
        'storagePath': PaymentInfoAudioService.storagePath,
        'fileName': file.name,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _showSnack('Audio du popup mis à jour.');
    } catch (e) {
      _showSnack('Erreur upload audio : $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
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
                  'Mets à jour le fichier MP3 lu dans le popup “Infos paiement”.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF4A5878),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  audioUrl == null || audioUrl.isEmpty
                      ? 'Aucun MP3 configuré.'
                      : 'MP3 configuré dans Firebase Storage.',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: audioUrl == null || audioUrl.isEmpty
                        ? Colors.orange
                        : Colors.green,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _uploading ? null : _pickAndUploadMp3,
                    icon: _uploading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file_rounded),
                    label: Text(
                      _uploading ? 'Upload en cours...' : 'Mettre à jour le MP3',
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
