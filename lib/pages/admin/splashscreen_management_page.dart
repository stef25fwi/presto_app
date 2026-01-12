import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../constants.dart';
import '../../utils/friendly_snackbar.dart';

class SplashscreenManagementPage extends StatefulWidget {
  const SplashscreenManagementPage({super.key});

  @override
  State<SplashscreenManagementPage> createState() =>
      _SplashscreenManagementPageState();
}

class _SplashscreenManagementPageState
    extends State<SplashscreenManagementPage> {
  static const Color prestoOrange = Color(0xFFFF6600);
  static const Color prestoBlue = Color(0xFF1A73E8);

  bool _loading = true;
  String _activeSplashscreen = 'v1';

  // Liste des splashscreens disponibles
  final List<Map<String, dynamic>> _splashscreens = [
    {
      'id': 'v1',
      'name': 'Splashscreen V1',
      'description': 'Version originale avec logo et animation de base',
      'icon': Icons.star_rounded,
      'color': prestoOrange,
    },
    {
      'id': 'v2',
      'name': 'Splashscreen V2',
      'description': 'Version moderne avec animations avancées',
      'icon': Icons.auto_awesome_rounded,
      'color': prestoBlue,
    },
    {
      'id': 'v3',
      'name': 'Splashscreen V3',
      'description': 'Version minimaliste et élégante',
      'icon': Icons.trending_up_rounded,
      'color': Colors.purple,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadActiveSplashscreen();
  }

  Future<void> _loadActiveSplashscreen() async {
    setState(() => _loading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('splashscreen')
          .get();

      if (doc.exists) {
        final data = doc.data();
        setState(() {
          _activeSplashscreen = data?['active'] ?? 'v1';
        });
      }
    } catch (e) {
      if (mounted) {
        showSuccessSnackBar(context, 'Erreur lors du chargement: $e');
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _setActiveSplashscreen(String splashId) async {
    try {
      await FirebaseFirestore.instance
          .collection('config')
          .doc('splashscreen')
          .set({
        'active': splashId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() {
        _activeSplashscreen = splashId;
      });

      if (mounted) {
        final splash = _splashscreens.firstWhere((s) => s['id'] == splashId);
        showSuccessSnackBar(
          context,
          '${splash['name']} activé avec succès !',
        );
      }
    } catch (e) {
      if (mounted) {
        showSuccessSnackBar(context, 'Erreur lors de l\'activation: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        titleSpacing: 16,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: 'Retour',
        ),
        title: const Text(
          'Gestion Splashscreen',
          style: kPrestoAppBarTitleStyle,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadActiveSplashscreen,
            tooltip: 'Rafraîchir',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(prestoOrange),
              ),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // En-tête informatif
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: prestoOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: prestoOrange.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: prestoOrange,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Sélectionne le splashscreen à afficher au démarrage de l\'application.',
                              style: TextStyle(
                                color: Colors.grey.shade800,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Titre de la section
                    Text(
                      'Versions disponibles',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                    ),
                    const SizedBox(height: 12),

                    // Liste des splashscreens
                    ..._splashscreens.map((splash) {
                      final isActive = _activeSplashscreen == splash['id'];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _SplashscreenCard(
                          id: splash['id'] as String,
                          name: splash['name'] as String,
                          description: splash['description'] as String,
                          icon: splash['icon'] as IconData,
                          color: splash['color'] as Color,
                          isActive: isActive,
                          onToggle: (value) {
                            if (value) {
                              _setActiveSplashscreen(splash['id'] as String);
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
    );
  }
}

class _SplashscreenCard extends StatelessWidget {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final bool isActive;
  final ValueChanged<bool> onToggle;

  const _SplashscreenCard({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.isActive,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? color.withOpacity(0.5) : Colors.grey.shade300,
          width: isActive ? 2 : 1,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Icône
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),

            // Infos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      if (isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.green.shade300,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 14,
                                color: Colors.green.shade700,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Actif',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Toggle
            Switch(
              value: isActive,
              onChanged: onToggle,
              activeColor: color,
              activeTrackColor: color.withOpacity(0.3),
            ),
          ],
        ),
      ),
    );
  }
}
