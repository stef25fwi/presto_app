import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/publish_ai/publish_ai_state.dart';

void main() {
  test('expose tous les états simples du pipeline', () {
    expect(const PublishAiIdle(), isA<PublishAiState>());
    expect(const PublishAiPreparing(), isA<PublishAiState>());
    expect(const PublishAiRecording(), isA<PublishAiState>());
    expect(const PublishAiUploading(), isA<PublishAiState>());
    expect(const PublishAiTranscribing(), isA<PublishAiState>());
  });

  test('conserve le message d indisponibilité du microphone', () {
    const state = PublishAiMicUnavailable('Microphone indisponible');

    expect(state.message, 'Microphone indisponible');
  });

  test('conserve les informations de profil manquantes', () {
    const state = PublishAiProfileNotReady(
      message: 'Profil incomplet',
      missingFields: <String>['displayName', 'city'],
    );

    expect(state.message, 'Profil incomplet');
    expect(state.missingFields, <String>['displayName', 'city']);
  });

  test('conserve le résultat du transcript et du brouillon', () {
    const state = PublishAiResult(
      transcript: 'Je cherche un jardinier',
      draft: <String, dynamic>{
        'title': 'Entretien de jardin',
        'categoryId': 'garden',
      },
      modeUsed: 'HYBRID',
    );

    expect(state.transcript, 'Je cherche un jardinier');
    expect(state.draft?['title'], 'Entretien de jardin');
    expect(state.modeUsed, 'HYBRID');
  });

  test('accepte un résultat sans brouillon', () {
    const state = PublishAiResult(
      transcript: 'Texte uniquement',
      draft: null,
      modeUsed: 'GOOGLE_ONLY',
    );

    expect(state.draft, isNull);
    expect(state.modeUsed, 'GOOGLE_ONLY');
  });

  test('conserve les détails d une erreur terminale', () {
    final cause = StateError('backend indisponible');
    final state = PublishAiFailure(
      code: 'unavailable',
      message: 'Réessayez plus tard',
      cause: cause,
    );

    expect(state.code, 'unavailable');
    expect(state.message, 'Réessayez plus tard');
    expect(state.cause, same(cause));
  });
}
