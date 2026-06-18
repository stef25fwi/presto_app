import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service Flutter équivalent au snippet Web Firebase AI :
/// `getAI(firebaseApp, { backend: new GoogleAIBackend() })`.
///
/// Firebase est déjà initialisé au démarrage de l'app (`main.dart`). Ce service
/// réutilise donc l'app Firebase par défaut, App Check et Auth.
class FirebaseGeminiService {
  FirebaseGeminiService({FirebaseAI? ai})
      : _ai = ai ??
            FirebaseAI.googleAI(
              appCheck: FirebaseAppCheck.instance,
              auth: FirebaseAuth.instance,
            );

  static const String defaultModel = 'gemini-3-flash-preview';

  final FirebaseAI _ai;

  GenerativeModel generativeModel({
    String model = defaultModel,
    GenerationConfig? generationConfig,
    List<SafetySetting>? safetySettings,
    Content? systemInstruction,
  }) {
    return _ai.generativeModel(
      model: model,
      generationConfig: generationConfig,
      safetySettings: safetySettings,
      systemInstruction: systemInstruction,
    );
  }

  Future<String> generateText(
    String prompt, {
    String model = defaultModel,
    GenerationConfig? generationConfig,
    List<SafetySetting>? safetySettings,
    String? systemInstruction,
  }) async {
    final response = await generativeModel(
      model: model,
      generationConfig: generationConfig,
      safetySettings: safetySettings,
      systemInstruction:
          systemInstruction == null ? null : Content.system(systemInstruction),
    ).generateContent(<Content>[Content.text(prompt)]);

    return response.text?.trim() ?? '';
  }
}
