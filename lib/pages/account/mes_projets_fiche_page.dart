import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../toolbox_page.dart';

const Color _kOrange = Color(0xFFFF6600);
const Color _kBg = Color(0xFFF6F7FB);

class MesProjetsFichePage extends StatelessWidget {
  const MesProjetsFichePage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text('Ma fiche projet'),
        backgroundColor: _kOrange,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Nouveau projet',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ToolboxPage())),
          ),
        ],
      ),
      body: uid == null ? const _NotSignedIn() : _ParcoursListBody(uid: uid),
    );
  }
}

class _NotSignedIn extends StatelessWidget {
  const _NotSignedIn();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.folder_off_rounded,
              size: 56,
              color: Color(0xFFD1D5DB),
            ),
            const SizedBox(height: 16),
            const Text(
              'Connectez-vous pour accéder à vos projets.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParcoursListBody extends StatelessWidget {
  final String uid;
  const _ParcoursListBody({required this.uid});

  @override
  Widget build(BuildContext context) {
    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('parcours')
        .orderBy('updatedAt', descending: true);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: col.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(_kOrange),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Erreur de chargement : ${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
              ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return _EmptyState();
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final data = docs[i].data();
            return _ParcoursCard(data: data);
          },
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _kOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.folder_open_rounded,
                size: 38,
                color: _kOrange,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Aucun projet sauvegardé',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Utilisez la boîte à outils pour créer\nvotre premier projet d\'entreprise.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _kOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ToolboxPage())),
              icon: const Icon(Icons.rocket_launch_rounded),
              label: const Text('Démarrer un projet'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParcoursCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ParcoursCard({required this.data});

  String get _title {
    final raw =
        ((data['data'] as Map?)?.cast<String, dynamic>()['projectText'] ?? '')
            as String;
    final trimmed = raw.trim();
    return trimmed.isNotEmpty ? trimmed : 'Projet sans titre';
  }

  String get _activityType {
    return ((data['data'] as Map?)?.cast<String, dynamic>()['activityType'] ??
            '')
        .toString()
        .trim();
  }

  String get _region {
    final territory =
        ((data['data'] as Map?)?.cast<String, dynamic>()['territory'] as Map?)
            ?.cast<String, dynamic>();
    return (territory?['region'] ?? '').toString().trim();
  }

  bool get _isCompleted => (data['status'] ?? '').toString() == 'completed';

  DateTime? get _updatedAt {
    final ts = data['updatedAt'];
    if (ts is Timestamp) return ts.toDate();
    return null;
  }

  static const _months = [
    '',
    'jan',
    'fév',
    'mar',
    'avr',
    'mai',
    'juin',
    'juil',
    'aoû',
    'sep',
    'oct',
    'nov',
    'déc',
  ];

  String _formatDate(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${_months[dt.month]} ${dt.year} à ${h}h$m';
  }

  @override
  Widget build(BuildContext context) {
    final updated = _updatedAt;
    final subtitle = [
      if (_activityType.isNotEmpty) _activityType,
      if (_region.isNotEmpty) _region,
    ].join(' · ');

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const ToolboxPage())),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _isCompleted
                      ? const Color(0xFFD1FAE5)
                      : _kOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _isCompleted
                      ? Icons.check_circle_rounded
                      : Icons.edit_note_rounded,
                  color: _isCompleted ? const Color(0xFF059669) : _kOrange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _isCompleted
                                ? const Color(0xFFD1FAE5)
                                : const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _isCompleted ? 'Terminé' : 'Brouillon',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _isCompleted
                                  ? const Color(0xFF059669)
                                  : _kOrange,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                    if (updated != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Modifié le ${_formatDate(updated)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFB0B7C3),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFD1D5DB),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
