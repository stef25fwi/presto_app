// Mode de modération de la messagerie : configuration, tuile et badge.
//
// Fragment de la bibliothèque `admin_space_page.dart` : le découpage
// réduit la taille des fichiers sans modifier la visibilité des types.
part of '../admin_space_page.dart';

enum _MessagingModerationMode {
  visibleThenRetract,
  hiddenUntilValidated,
  hybrid,
}

_MessagingModerationMode _messagingModerationModeFromFirestoreValue(
  String value,
) {
  switch (value.trim().toLowerCase()) {
    case 'visible_then_retract':
      return _MessagingModerationMode.visibleThenRetract;
    case 'hidden_until_validated':
      return _MessagingModerationMode.hiddenUntilValidated;
    case 'hybrid':
      return _MessagingModerationMode.hybrid;
    default:
      return _MessagingModerationMode.hybrid;
  }
}

extension on _MessagingModerationMode {
  String get firestoreValue {
    switch (this) {
      case _MessagingModerationMode.visibleThenRetract:
        return 'visible_then_retract';
      case _MessagingModerationMode.hiddenUntilValidated:
        return 'hidden_until_validated';
      case _MessagingModerationMode.hybrid:
        return 'hybrid';
    }
  }

  String get label {
    switch (this) {
      case _MessagingModerationMode.visibleThenRetract:
        return 'Visible puis retrait';
      case _MessagingModerationMode.hiddenUntilValidated:
        return 'Masqué avant validation';
      case _MessagingModerationMode.hybrid:
        return 'Hybride';
    }
  }

  String get shortLabel {
    switch (this) {
      case _MessagingModerationMode.visibleThenRetract:
        return 'Souple';
      case _MessagingModerationMode.hiddenUntilValidated:
        return 'Strict';
      case _MessagingModerationMode.hybrid:
        return 'Hybride';
    }
  }

  String get description {
    switch (this) {
      case _MessagingModerationMode.visibleThenRetract:
        return 'Le message part tout de suite, puis est retiré si la modération détecte un contenu interdit.';
      case _MessagingModerationMode.hiddenUntilValidated:
        return 'Le contenu reste masqué tant que la vérification texte ou image n a pas validé le message.';
      case _MessagingModerationMode.hybrid:
        return 'Les contenus sains restent fluides, les cas moyens ou risqués sont masqués ou basculés en revue.';
    }
  }
}

class _MessagingModerationConfigService {
  _MessagingModerationConfigService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _configRef =>
      _firestore.collection('appConfig').doc('marketplace');

  Stream<_MessagingModerationMode> watchMode({bool ensureExists = false}) {
    if (ensureExists) {
      unawaited(ensureDefaultConfigExists());
    }

    return _configRef.snapshots().map((snapshot) {
      final moderation = snapshot.data()?['moderation'];
      final rawMode = moderation is Map
          ? (moderation['messagingMode'] ?? '').toString()
          : '';
      return _messagingModerationModeFromFirestoreValue(rawMode);
    });
  }

  Future<void> ensureDefaultConfigExists({String? updatedBy}) async {
    final snapshot = await _configRef.get();
    final data = snapshot.data();
    final moderation = data?['moderation'];
    final hasMode = moderation is Map &&
        (moderation['messagingMode'] ?? '').toString().trim().isNotEmpty;
    if (hasMode) {
      return;
    }

    await _configRef.set(<String, dynamic>{
      'moderation': <String, dynamic>{
        'messagingMode': _MessagingModerationMode.hybrid.firestoreValue,
      },
      'updatedAt': FieldValue.serverTimestamp(),
      if (updatedBy != null && updatedBy.trim().isNotEmpty)
        'updatedBy': updatedBy.trim(),
    }, SetOptions(merge: true));
  }

  Future<void> updateMode(
    _MessagingModerationMode mode, {
    String? updatedBy,
  }) async {
    await _configRef.set(<String, dynamic>{
      'moderation': <String, dynamic>{'messagingMode': mode.firestoreValue},
      'updatedAt': FieldValue.serverTimestamp(),
      if (updatedBy != null && updatedBy.trim().isNotEmpty)
        'updatedBy': updatedBy.trim(),
    }, SetOptions(merge: true));
  }
}

class _AdminMessagingModerationTile extends StatefulWidget {
  const _AdminMessagingModerationTile();

  @override
  State<_AdminMessagingModerationTile> createState() =>
      _AdminMessagingModerationTileState();
}

class _AdminMessagingModerationTileState
    extends State<_AdminMessagingModerationTile> {
  final _service = _MessagingModerationConfigService();

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(
      _service.ensureDefaultConfigExists(
        updatedBy: FirebaseAuth.instance.currentUser?.uid,
      ),
    );
  }

  Future<void> _setMode(_MessagingModerationMode mode) async {
    if (_saving) return;

    setState(() => _saving = true);
    try {
      await _service.updateMode(
        mode,
        updatedBy: FirebaseAuth.instance.currentUser?.uid,
      );
      if (!mounted) return;
      showSuccessSnackBar(
        context,
        'Mode de modération messagerie mis à jour : ${mode.label}.',
      );
    } catch (_) {
      if (!mounted) return;
      showErrorSnackBar(
        context,
        'Impossible de mettre à jour la modération messagerie.',
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const titleColor = Color(0xFF111827);
    const subtitleColor = Color(0xFF6B7280);
    const accentColor = Color(0xFF0F766E);

    return StreamBuilder<_MessagingModerationMode>(
      stream: _service.watchMode(ensureExists: true),
      builder: (context, snapshot) {
        final mode = snapshot.data ?? _MessagingModerationMode.hybrid;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.shield_rounded, color: accentColor),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Modération messagerie',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: titleColor,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Choisir le niveau de contrôle des messages texte et image.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: subtitleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SegmentedButton<_MessagingModerationMode>(
                segments: const [
                  ButtonSegment(
                    value: _MessagingModerationMode.visibleThenRetract,
                    label: Text('Souple'),
                    icon: Icon(Icons.bolt_rounded),
                  ),
                  ButtonSegment(
                    value: _MessagingModerationMode.hiddenUntilValidated,
                    label: Text('Strict'),
                    icon: Icon(Icons.visibility_off_rounded),
                  ),
                  ButtonSegment(
                    value: _MessagingModerationMode.hybrid,
                    label: Text('Hybride'),
                    icon: Icon(Icons.tune_rounded),
                  ),
                ],
                selected: {mode},
                onSelectionChanged:
                    _saving ? null : (selection) => _setMode(selection.first),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ModeBadge(label: 'Mode actif : ${mode.label}'),
                  _ModeBadge(label: 'Clé Firestore : ${mode.firestoreValue}'),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mode.label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      mode.description,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: subtitleColor,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ModeBadge extends StatelessWidget {
  final String label;

  const _ModeBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE6FFFB),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0F766E),
        ),
      ),
    );
  }
}
