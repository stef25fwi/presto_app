import 'package:path_provider/path_provider.dart';

Future<String> createTempAudioPath(
    {String prefix = 'presto', String extension = 'wav'}) async {
  final dir = await getTemporaryDirectory();
  final ext = extension.trim().isEmpty ? 'wav' : extension.trim();
  return '${dir.path}/${prefix}_${DateTime.now().millisecondsSinceEpoch}.$ext';
}

Future<String> createTempWavPath({String prefix = 'presto'}) async {
  return createTempAudioPath(prefix: prefix, extension: 'wav');
}
