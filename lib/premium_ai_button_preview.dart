import 'package:flutter/material.dart';
import 'widgets/premium_ai_button.dart';

/// Page de démonstration du bouton Premium AI
class PremiumAiButtonPreview extends StatefulWidget {
  const PremiumAiButtonPreview({Key? key}) : super(key: key);

  @override
  State<PremiumAiButtonPreview> createState() => _PremiumAiButtonPreviewState();
}

class _PremiumAiButtonPreviewState extends State<PremiumAiButtonPreview> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bouton Premium AI - Preview'),
        backgroundColor: const Color(0xFF1A73E8),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Titre
            const Text(
              'Bouton Premium AI',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Style Flutter Material 3 avec dégradé et ombre douce',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // État normal
            _buildSection(
              title: 'État Normal',
              description: 'Bouton prêt à être cliqué',
              child: PremiumAiButton(
                onPressed: () => _simulateAction(),
                label: 'Décrire mon besoin (IA)',
              ),
            ),
            const SizedBox(height: 40),

            // État chargement
            _buildSection(
              title: 'État Chargement',
              description: 'Affiche le spinner de progression',
              child: PremiumAiButton(
                onPressed: () {},
                label: 'Décrire mon besoin (IA)',
                isLoading: true,
              ),
            ),
            const SizedBox(height: 40),

            // État désactivé
            _buildSection(
              title: 'État Désactivé',
              description: 'Bouton inactif (onPressed = null)',
              child: PremiumAiButton(
                onPressed: null,
                label: 'Décrire mon besoin (IA)',
              ),
            ),
            const SizedBox(height: 40),

            // Spécifications techniques
            _buildSpecifications(),
            const SizedBox(height: 40),

            // Exemple de code
            _buildCodeExample(),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String description,
    required Widget child,
  }) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Center(child: child),
      ],
    );
  }

  Widget _buildSpecifications() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Spécifications',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          _specItem('Couleur', '#1A73E8 (Bleu Presto)'),
          _specItem('Dégradé', '#2D84F6 (haut) → #1A73E8 (bas)'),
          _specItem('Forme', 'Pilule (borderRadius: 20px)'),
          _specItem('Largeur', '92% de l\'écran'),
          _specItem('Hauteur', '56px'),
          _specItem('Ombre', 'blur: 14, opacity: 18%'),
          _specItem('Icône', 'Icons.auto_awesome (Sparkles)'),
          _specItem('Police', 'Titillium Web Semi-bold 17px'),
          _specItem('Texte', 'Décrire mon besoin (IA)'),
        ],
      ),
    );
  }

  Widget _specItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF1A73E8),
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeExample() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Exemple de code',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2D2D30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: const Text(
                '''PremiumAiButton(
  onPressed: () => _startMic(),
  label: 'Décrire mon besoin (IA)',
  isLoading: _isLoading,
)''',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Color(0xFFCE9178),
                  height: 1.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _simulateAction() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✨ Bouton premium cliqué!'),
        duration: Duration(seconds: 2),
      ),
    );
    await Future.delayed(const Duration(seconds: 1));
  }
}
