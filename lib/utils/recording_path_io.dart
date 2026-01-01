import 'package:path_provider/path_provider.dart';

Future<String> createTempWavPath({String prefix = 'presto'}) async {
  final dir = await getTemporaryDirectory();
  return '${dir.path}/${prefix}_${DateTime.now().millisecondsSinceEpoch}.wav';
}
