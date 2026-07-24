import 'package:flutter/material.dart';

class AgentAuthorizationTile extends StatelessWidget {
  final int pendingCount;
  final VoidCallback onTap;

  const AgentAuthorizationTile({
    super.key,
    required this.pendingCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasPending = pendingCount > 0;
    return Semantics(
      button: true,
      label: hasPending
          ? '$pendingCount demandes d’autorisation des agents en attente'
          : 'Aucune demande d’autorisation des agents en attente',
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: hasPending
                  ? const Color(0xFFFF6600)
                  : const Color(0xFFE5E7EB),
              width: hasPending ? 1.5 : 1,
            ),
            boxShadow: const [
              BoxShadow(
                blurRadius: 18,
                offset: Offset(0, 8),
                color: Color(0x12000000),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: hasPending
                      ? const Color(0xFFFFEEE4)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.smart_toy_outlined,
                  color: hasPending
                      ? const Color(0xFFFF6600)
                      : const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dialogue avec les agents',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      hasPending
                          ? '$pendingCount autorisation${pendingCount > 1 ? 's' : ''} à examiner'
                          : 'Aucune action sensible en attente',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: hasPending
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: hasPending
                            ? const Color(0xFFC2410C)
                            : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              if (hasPending)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6600),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$pendingCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              const SizedBox(width: 10),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}