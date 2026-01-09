class MicroIaStreamClient {
  static Future<MicroIaStreamClient> connect({
    required Uri url,
    required String token,
    Duration timeout = const Duration(seconds: 6),
  }) =>
      Future.error(
        UnsupportedError('Streaming Micro IA non supporté sur cette plateforme'),
      );
}
