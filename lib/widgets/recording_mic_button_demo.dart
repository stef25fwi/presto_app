import 'package:flutter/material.dart';
import 'recording_mic_button.dart';

/// Page de démonstration du bouton d'enregistrement vocal
/// 
/// Pour tester : flutter run -t lib/widgets/recording_mic_button_demo.dart
class RecordingMicButtonDemo extends StatefulWidget {
  const RecordingMicButtonDemo({super.key});

  @override
  State<RecordingMicButtonDemo> createState() => _RecordingMicButtonDemoState();
}

class _RecordingMicButtonDemoState extends State<RecordingMicButtonDemo> {
  bool _isRecording = false;

  void _toggleRecording() {
    setState(() {
      _isRecording = !_isRecording;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Recording Mic Button Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A73E8)),
        useMaterial3: true,
      ),
      home: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          title: const Text('🎤 Recording Mic Button Demo'),
          centerTitle: true,
          elevation: 0,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Démonstration interactive
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '🎯 Démonstration interactive',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Cliquez sur le bouton ci-dessous pour basculer entre les états',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Center(
                          child: SizedBox(
                            width: 400,
                            child: RecordingMicButton(
                              isRecording: _isRecording,
                              onTap: _toggleRecording,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: Text(
                            _isRecording
                                ? '🔴 État: Enregistrement actif'
                                : '⚪ État: Inactif',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _isRecording
                                  ? const Color(0xFFE53935)
                                  : const Color(0xFF1A73E8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Spécifications techniques
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '📋 Spécifications techniques',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildSpecItem(
                          '🎨 Design',
                          'Hauteur: 110px, Padding: 20x16, Border radius: 30px',
                        ),
                        _buildSpecItem(
                          '🎭 Animations',
                          'Pulsation micro: 1.0 → 1.25 scale (600ms)\nBarres audio: 8 barres, hauteur 10-40px',
                        ),
                        _buildSpecItem(
                          '🎨 Couleurs',
                          'Inactif: #1A73E8 (Bleu Presto)\nActif: #E53935 (Rouge vif)',
                        ),
                        _buildSpecItem(
                          '✨ Effets',
                          'Ombre portée animée, ripple effect au clic\nTransitions fluides (300ms cubic)',
                        ),
                        _buildSpecItem(
                          '♿ Accessibilité',
                          'Semantics activé, labels descriptifs\nÉtats désactivés supportés',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // États du bouton
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '🔄 États du bouton',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // État inactif
                        const Text(
                          '1. État inactif',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: RecordingMicButton(
                            isRecording: false,
                            onTap: () {},
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // État enregistrement
                        const Text(
                          '2. État enregistrement',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: RecordingMicButton(
                            isRecording: true,
                            onTap: () {},
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // État désactivé
                        const Text(
                          '3. État désactivé',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: RecordingMicButton(
                            isRecording: false,
                            onTap: () {},
                            isDisabled: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Exemple de code
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '💻 Exemple d\'utilisation',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade900,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const SelectableText(
                            '''import 'package:flutter/material.dart';
import 'widgets/recording_mic_button.dart';

class MyPage extends StatefulWidget {
  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  bool _isRecording = false;

  Future<void> _toggleRecording() async {
    setState(() => _isRecording = !_isRecording);
    
    if (_isRecording) {
      // Démarrer l'enregistrement
      await startAudioRecording();
    } else {
      // Arrêter et traiter
      await stopAndProcessAudio();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RecordingMicButton(
      isRecording: _isRecording,
      onTap: _toggleRecording,
    );
  }
}''',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpecItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              description,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  runApp(const RecordingMicButtonDemo());
}
