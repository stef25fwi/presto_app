import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/firebase_functions_region.dart';
import 'video_maker_models.dart';

typedef VideoMakerVideosLoader = Future<List<GeneratedVideo>> Function();
typedef VideoMakerGenerator = Future<void> Function(
  Map<String, Object?> parameters,
);
typedef VideoMakerImagePicker = Future<XFile?> Function();
typedef VideoMakerVideoOpener = Future<bool> Function(Uri uri);
typedef VideoMakerVideoSharer = Future<bool> Function(
  GeneratedVideo video,
  Rect? shareOrigin,
);

Future<XFile?> pickVideoMakerImageFromGallery(ImagePicker picker) {
  return picker.pickImage(
    source: ImageSource.gallery,
    imageQuality: 92,
    maxWidth: 2048,
    maxHeight: 2048,
  );
}

Future<void> generateVideoWithFunctions(
  Map<String, Object?> parameters,
) async {
  await callPrestoFunction<dynamic>(
    functions: prestoFirebaseFunctions,
    name: 'adminGenerateVideo',
    timeout: const Duration(minutes: 9),
    area: 'admin-videomaker',
    parameters: parameters,
  );
}

Future<List<GeneratedVideo>> loadVideosWithFunctions() async {
  final result = await callPrestoFunction<dynamic>(
    functions: prestoFirebaseFunctions,
    name: 'adminListGeneratedVideos',
    timeout: const Duration(seconds: 45),
    area: 'admin-videomaker',
    parameters: const <String, Object?>{'limit': 50},
  );
  final rawVideos = stringMap(result.data)['videos'];
  return rawVideos is List
      ? rawVideos.map(GeneratedVideo.fromObject).toList(growable: false)
      : const <GeneratedVideo>[];
}

Future<bool> openGeneratedVideo(Uri uri) {
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<bool> shareGeneratedVideo(
  GeneratedVideo video,
  Rect? shareOrigin,
) async {
  final url = video.publicUrl!;
  try {
    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(minutes: 2));
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        response.bodyBytes.isEmpty) {
      throw StateError('Téléchargement vidéo impossible.');
    }

    await Share.shareXFiles(
      [
        XFile.fromData(
          response.bodyBytes,
          mimeType: 'video/mp4',
          name: 'veo-${video.id}.mp4',
        ),
      ],
      text: 'Vidéo iliprestō créée avec VEO',
      subject: 'Vidéo iliprestō',
      sharePositionOrigin: shareOrigin,
    );
    return true;
  } catch (_) {
    await Share.share(
      'Vidéo iliprestō créée avec VEO\n$url',
      subject: 'Vidéo iliprestō',
      sharePositionOrigin: shareOrigin,
    );
    return false;
  }
}
