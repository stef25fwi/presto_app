import 'package:flutter/material.dart';

import 'models/agent_authorization_request.dart';
import 'services/agent_authorization_service.dart';

class AgentAuthorizationCenterPage extends StatelessWidget {
  final String superAdminUid;
  final AgentAuthorizationService service;

  AgentAuthorizationCenterPage({
    super.key,
    required this.superAdminUid,
    AgentAuthorizationService? service,
  }) : service = service ?? AgentAuthorizationService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Dialogue avec les agents'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: StreamBuilder<List<AgentAuthorizationRequest>>(
        stream: service.watchPendingRequests(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _StateMessage(
              icon: Icons.error_outline_rounded,
              title: 'Impossible de charger les demandes',
              message: '${snapshot.error}',
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final requests = snapshot.data!;
          if (requests.isEmpty) {
            return const _StateMessage(
              icon: Icons.verified_user_outlined,
              title: 'Tout est sous contrôle',
              message: 'Aucune action d’agent ne nécessite une autorisation.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final request = requests[index];
              return _AuthorizationCard(
                request: request,
                onOpen: () => _showDecisionDialog(context, request),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showDecisionDialog(
    BuildContext context,
    AgentAuthorizationRequest request,
  ) async {
    final controller = TextEditingController();
    bool submitting = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> decide(bool approve) async {
              final comment = controller.text.trim();
              final commentRequired = request.risk == AgentAuthorizationRisk.high ||
                  request.risk == AgentAuthorizationRisk.critical ||
                  !approve;
              if (commentRequired && comment.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ajoutez un commentaire pour cette décision.'),
                  ),
                );
                return;
              }
              setState(() => submitting = true);
              try {
                if (approve) {
                  await service.approve(
                    requestId: request.id,
                    superAdminUid: superAdminUid,
                    comment: comment,
                  );
                } else {
                  await service.reject(
                    requestId: request.id,
                    superAdminUid: superAdminUid,
                    comment: comment,
                  );
                }
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              } catch (error) {
                setState(() => submitting = false);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$error')),
                  );
                }
              }
            }

            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.smart_toy_outlined),
                  const SizedBox(width: 10),
                  Expanded(child: Text(request.title)),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _InfoLine(label: 'Agent', value: request.agentLabel),
                      _InfoLine(label: 'Action', value: request.actionType),
                      _InfoLine(label: 'Risque', value: request.risk.name),
                      const SizedBox(height: 12),
                      Text(
                        request.summary,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(request.reason),
                      if (request.affectedResources.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        const Text(
                          'Éléments concernés',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        ...request.affectedResources.map(
                          (resource) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text('• $resource'),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextField(
                        controller: controller,
                        minLines: 2,
                        maxLines: 4,
                        enabled: !submitting,
                        decoration: const InputDecoration(
                          labelText: 'Commentaire du superadmin',
                          hintText: 'Motif, limite ou consigne donnée à l’agent',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => decide(false),
                  child: const Text('Refuser'),
                ),
                FilledButton.icon(
                  onPressed: submitting ? null : () => decide(true),
                  icon: submitting
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                  label: const Text('Autoriser'),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
  }
}

class _AuthorizationCard extends StatelessWidget {
  final AgentAuthorizationRequest request;
  final VoidCallback onOpen;

  const _AuthorizationCard({required this.request, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFFFEEE4),
                foregroundColor: Color(0xFFFF6600),
                child: Icon(Icons.smart_toy_outlined),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('${request.agentLabel} • ${request.actionType}'),
                    const SizedBox(height: 8),
                    Text(
                      request.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _RiskBadge(risk: request.risk),
            ],
          ),
        ),
      ),
    );
  }
}

class _RiskBadge extends StatelessWidget {
  final AgentAuthorizationRisk risk;

  const _RiskBadge({required this.risk});

  @override
  Widget build(BuildContext context) {
    final color = switch (risk) {
      AgentAuthorizationRisk.low => const Color(0xFF047857),
      AgentAuthorizationRisk.medium => const Color(0xFFB45309),
      AgentAuthorizationRisk.high => const Color(0xFFC2410C),
      AgentAuthorizationRisk.critical => const Color(0xFFB91C1C),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        risk.name.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;

  const _InfoLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _StateMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 50, color: const Color(0xFF6B7280)),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}