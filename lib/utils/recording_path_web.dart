Future<String> createTempAudioPath({String prefix = 'presto', String extension = 'wav'}) async {
  throw UnsupportedError('Temporary file path is not available on web');
}

Future<String> createTempWavPath({String prefix = 'presto'}) async {
  return createTempAudioPath(prefix: prefix, extension: 'wav');
}
