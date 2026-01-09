import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Widget to display user moderation warnings on profile
class UserModerationStatus extends StatefulWidget {
  final String userId;

  const UserModerationStatus({
    super.key,
    required this.userId,
  });

  @override
  State<UserModerationStatus> createState() => _UserModerationStatusState();
}

class _UserModerationStatusState extends State<UserModerationStatus> {
  late final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('offers')
          .where('userId', isEqualTo: widget.userId)
          .where('moderation.status', whereIn: ['REJECTED', 'PENDING'])
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final rejectedCount = snapshot.data!.docs
            .where((doc) => doc['moderation']['status'] == 'REJECTED')
            .length;

        final pendingCount = snapshot.data!.docs
            .where((doc) => doc['moderation']['status'] == 'PENDING')
            .length;

        if (rejectedCount == 0 && pendingCount == 0) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_rounded, color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Avertissements de modération',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (rejectedCount > 0) ...[
                Text(
                  'Annonces rejetées: $rejectedCount',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (pendingCount > 0) ...[
                const SizedBox(height: 4),
                Text(
                  'Annonces en attente: $pendingCount',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
