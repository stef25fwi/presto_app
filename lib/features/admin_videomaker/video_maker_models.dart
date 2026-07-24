import 'package:cloud_functions/cloud_functions.dart';
import 'package:image_picker/image_picker.dart';

const maxVideoMakerImageBytes = 5 * 1024 * 1024;
const maxVideoMakerReferenceImages = 3;

class GeneratedVideo {
  final String id;
  final String prompt;
  final String status;
  final String model;
  final String aspectRatio;
  final String durationSeconds;
  final String resolution;
  final int referenceImageCount;
  final List<String> referenceImageNames;
  final String? publicUrl;
  final String? fileName;
  final int? sizeBytes;
  final DateTime? createdAt;
  final DateTime? generatedAt;
  final String? errorMessage;

  const GeneratedVideo({
    required this.id,
    required this.prompt,
    required this.status,
    required this.model,
    required this.aspectRatio,
    required this.durationSeconds,
    required this.resolution,
    required this.referenceImageCount,
    required this.referenceImageNames,
    required this.publicUrl,
    required this.fileName,
    required this.sizeBytes,
    required this.createdAt,
    required this.generatedAt,
    required this.errorMessage,
  });

  factory GeneratedVideo.fromObject(Object? value) {
    final map = stringMap(value);
    final rawNames = map['referenceImageNames'];
    return GeneratedVideo(
      id: (map['id'] ?? '').toString(),
      prompt: (map['prompt'] ?? 'Sans prompt').toString(),
      status: (map['status'] ?? 'processing').toString(),
      model: (map['model'] ?? 'veo-3.1-generate-preview').toString(),
      aspectRatio: (map['aspectRatio'] ?? '9:16').toString(),
      durationSeconds: (map['durationSeconds'] ?? '8').toString(),
      resolution: (map['resolution'] ?? '720p').toString(),
      referenceImageCount: int.tryParse(
            (map['referenceImageCount'] ?? 0).toString(),
          ) ??
          0,
      referenceImageNames: rawNames is List
          ? rawNames.map((value) => value.toString()).toList(growable: false)
          : const <String>[],
      publicUrl: _nullableString(map['publicUrl']),
      fileName: _nullableString(map['fileName']),
      sizeBytes: int.tryParse((map['sizeBytes'] ?? '').toString()),
      createdAt: DateTime.tryParse((map['createdAt'] ?? '').toString()),
      generatedAt: DateTime.tryParse((map['generatedAt'] ?? '').toString()),
      errorMessage: _nullableString(map['errorMessage']),
    );
  }
}

const supportedVideoMakerImageMimeTypes = <String>{
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/heic',
  'image/heif',
};

String imageMimeTypeFor(XFile file) {
  final provided = file.mimeType?.toLowerCase().trim();
  if (provided != null && provided.isNotEmpty) return provided;
  final name = file.name.toLowerCase();
  if (name.endsWith('.png')) return 'image/png';
  if (name.endsWith('.webp')) return 'image/webp';
  if (name.endsWith('.heic')) return 'image/heic';
  if (name.endsWith('.heif')) return 'image/heif';
  return 'image/jpeg';
}

Map<String, Object?> stringMap(Object? value) {
  if (value is! Map) return const <String, Object?>{};
  return <String, Object?>{
    for (final entry in value.entries) entry.key.toString(): entry.value,
  };
}

String formatVideoMakerDate(DateTime? date) {
  if (date == null) return 'Date indisponible';
  final local = date.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}

String formatVideoMakerBytes(int bytes) {
  if (bytes < 1024) return '$bytes o';
  final kilobytes = bytes / 1024;
  if (kilobytes < 1024) return '${kilobytes.toStringAsFixed(1)} Ko';
  return '${(kilobytes / 1024).toStringAsFixed(1)} Mo';
}

String friendlyVideoMakerFunctionError(FirebaseFunctionsException error) {
  final rawMessage = error.message?.trim();
  final message = rawMessage == null || rawMessage.isEmpty ? null : rawMessage;
  switch (error.code) {
    case 'unauthenticated':
      return 'Reconnectez-vous avant d’utiliser Videomaker.';
    case 'permission-denied':
      return 'Cette fonction est réservée aux administrateurs.';
    case 'invalid-argument':
      return message ?? 'Le prompt ou les images sont invalides.';
    case 'failed-precondition':
      return message ?? 'Configurez une clé API Gemini compatible avec VEO.';
    case 'deadline-exceeded':
      return 'VEO met plus de temps que prévu. '
          'Actualisez la bibliothèque dans quelques instants.';
    case 'resource-exhausted':
      return 'Quota VEO atteint. Vérifiez la facturation et les limites.';
    case 'unavailable':
      return message ?? 'Le service vidéo est temporairement indisponible.';
    default:
      return message ?? 'La génération VEO a échoué.';
  }
}

String? _nullableString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
