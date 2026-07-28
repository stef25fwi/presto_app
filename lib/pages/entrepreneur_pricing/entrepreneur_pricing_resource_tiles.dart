import 'package:flutter/material.dart';

import 'entrepreneur_pricing_models.dart';

class ResourceHeader extends StatelessWidget {
  const ResourceHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFF0F4C81)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.add_rounded),
          label: Text(actionLabel),
        ),
      ],
    );
  }
}

class MachineResourceTile extends StatelessWidget {
  const MachineResourceTile({
    super.key,
    required this.machine,
    required this.electricityRate,
    required this.onEdit,
    required this.onDelete,
  });

  final ProductionMachineUsage machine;
  final double electricityRate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return _ResourceTile(
      icon: Icons.precision_manufacturing_outlined,
      title: machine.name,
      subtitle:
          '${resourceNumber(machine.watts, 0)} W • '
          '${resourceNumber(machine.minutesPerUnit, 1)} min • ×${machine.quantity}',
      trailing:
          '${resourceNumber(machine.kwhPerUnit, 4)} kWh\n'
          '${resourceMoney(machine.costPerUnit(electricityRate))} €',
      onEdit: onEdit,
      onDelete: onDelete,
    );
  }
}

class AccessoryResourceTile extends StatelessWidget {
  const AccessoryResourceTile({
    super.key,
    required this.accessory,
    required this.onEdit,
    required this.onDelete,
  });

  final ProductionAccessoryUsage accessory;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return _ResourceTile(
      icon: Icons.construction_outlined,
      title: accessory.name,
      subtitle:
          '${resourceNumber(accessory.quantityPerUnit, 2)} × '
          '${resourceMoney(accessory.unitPrice)} €',
      trailing: '${resourceMoney(accessory.costPerUnit)} €',
      onEdit: onEdit,
      onDelete: onDelete,
    );
  }
}

class _ResourceTile extends StatelessWidget {
  const _ResourceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onEdit,
    required this.onDelete,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String trailing;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3E7EC)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF0F4C81)),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          Text(
            trailing,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F4C81),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Actions',
            onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Modifier')),
              PopupMenuItem(value: 'delete', child: Text('Supprimer')),
            ],
          ),
        ],
      ),
    );
  }
}

class EmptyResource extends StatelessWidget {
  const EmptyResource({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: Colors.black54,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class ResourceSummaryPill extends StatelessWidget {
  const ResourceSummaryPill({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF1A73E8)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

String resourceMoney(double value) => resourceNumber(value, 2);

String resourceNumber(double value, int digits) =>
    (value.isFinite ? value : 0.0)
        .toStringAsFixed(digits)
        .replaceAll('.', ',');