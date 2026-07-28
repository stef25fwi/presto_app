import 'package:flutter/material.dart';

import 'entrepreneur_pricing_models.dart';

class ProductionResourcesEditor extends StatelessWidget {
  const ProductionResourcesEditor({
    super.key,
    required this.machines,
    required this.accessories,
    required this.electricityRate,
    required this.onMachinesChanged,
    required this.onAccessoriesChanged,
  });

  final List<ProductionMachineUsage> machines;
  final List<ProductionAccessoryUsage> accessories;
  final double electricityRate;
  final ValueChanged<List<ProductionMachineUsage>> onMachinesChanged;
  final ValueChanged<List<ProductionAccessoryUsage>> onAccessoriesChanged;

  double get totalKwh => machines.fold<double>(
        0,
        (total, item) => total + item.kwhPerUnit,
      );

  double get totalElectricityCost => machines.fold<double>(
        0,
        (total, item) => total + item.costPerUnit(electricityRate),
      );

  double get totalAccessoryCost => accessories.fold<double>(
        0,
        (total, item) => total + item.costPerUnit,
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ResourceHeader(
          icon: Icons.precision_manufacturing_outlined,
          title: 'Machines utilisées',
          subtitle: 'Puissance × durée × quantité',
          actionLabel: 'Ajouter une machine',
          onPressed: () => _addMachine(context),
        ),
        const SizedBox(height: 8),
        if (machines.isEmpty)
          const _EmptyResource(
            text:
                'Ajoute chaque machine pour calculer sa consommation électrique exacte.',
          )
        else
          ...machines.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _MachineTile(
                    machine: entry.value,
                    electricityRate: electricityRate,
                    onEdit: () => _editMachine(context, entry.key),
                    onDelete: () {
                      final updated = List<ProductionMachineUsage>.from(machines)
                        ..removeAt(entry.key);
                      onMachinesChanged(updated);
                    },
                  ),
                ),
              ),
        _SummaryPill(
          icon: Icons.electric_bolt_rounded,
          text:
              '${_number(totalKwh, 4)} kWh par unité • ${_money(totalElectricityCost)} €',
        ),
        const SizedBox(height: 18),
        _ResourceHeader(
          icon: Icons.construction_outlined,
          title: 'Accessoires et fournitures',
          subtitle: 'Quantité utilisée × prix unitaire',
          actionLabel: 'Ajouter un accessoire',
          onPressed: () => _addAccessory(context),
        ),
        const SizedBox(height: 8),
        if (accessories.isEmpty)
          const _EmptyResource(
            text:
                'Ajoute les accessoires réellement consommés : lames, buses, gants, mèches, filtres…',
          )
        else
          ...accessories.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _AccessoryTile(
                    accessory: entry.value,
                    onEdit: () => _editAccessory(context, entry.key),
                    onDelete: () {
                      final updated =
                          List<ProductionAccessoryUsage>.from(accessories)
                            ..removeAt(entry.key);
                      onAccessoriesChanged(updated);
                    },
                  ),
                ),
              ),
        _SummaryPill(
          icon: Icons.payments_outlined,
          text: '${_money(totalAccessoryCost)} € d’accessoires par unité',
        ),
      ],
    );
  }

  Future<void> _addMachine(BuildContext context) async {
    final value = await showProductionMachineDialog(context);
    if (value == null) return;
    onMachinesChanged([...machines, value]);
  }

  Future<void> _editMachine(BuildContext context, int index) async {
    final value = await showProductionMachineDialog(
      context,
      initialValue: machines[index],
    );
    if (value == null) return;
    final updated = List<ProductionMachineUsage>.from(machines);
    updated[index] = value;
    onMachinesChanged(updated);
  }

  Future<void> _addAccessory(BuildContext context) async {
    final value = await showProductionAccessoryDialog(context);
    if (value == null) return;
    onAccessoriesChanged([...accessories, value]);
  }

  Future<void> _editAccessory(BuildContext context, int index) async {
    final value = await showProductionAccessoryDialog(
      context,
      initialValue: accessories[index],
    );
    if (value == null) return;
    final updated = List<ProductionAccessoryUsage>.from(accessories);
    updated[index] = value;
    onAccessoriesChanged(updated);
  }
}

Future<ProductionMachineUsage?> showProductionMachineDialog(
  BuildContext context, {
  ProductionMachineUsage? initialValue,
}) async {
  final nameController = TextEditingController(
    text: initialValue?.name ?? 'Machine principale',
  );
  final wattsController = TextEditingController(
    text: _editable(initialValue?.watts ?? 1000),
  );
  final minutesController = TextEditingController(
    text: _editable(initialValue?.minutesPerUnit ?? 30),
  );
  final quantityController = TextEditingController(
    text: '${initialValue?.quantity ?? 1}',
  );

  try {
    return await showDialog<ProductionMachineUsage>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(initialValue == null ? 'Ajouter une machine' : 'Modifier la machine'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const ValueKey('machine-name'),
                controller: nameController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nom de la machine',
                  prefixIcon: Icon(Icons.precision_manufacturing_outlined),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey('machine-watts'),
                controller: wattsController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Puissance',
                  suffixText: 'W',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey('machine-minutes'),
                controller: minutesController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Temps d’utilisation par unité',
                  suffixText: 'min',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey('machine-quantity'),
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Nombre de machines identiques',
                  suffixText: 'nb',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              final watts = _parse(wattsController.text);
              final minutes = _parse(minutesController.text);
              final quantity = int.tryParse(quantityController.text.trim()) ?? 0;
              if (name.isEmpty || watts <= 0 || minutes <= 0 || quantity <= 0) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('Renseigne un nom, une puissance, une durée et une quantité valides.'),
                  ),
                );
                return;
              }
              Navigator.of(dialogContext).pop(
                ProductionMachineUsage(
                  name: name,
                  watts: watts,
                  minutesPerUnit: minutes,
                  quantity: quantity,
                ),
              );
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  } finally {
    nameController.dispose();
    wattsController.dispose();
    minutesController.dispose();
    quantityController.dispose();
  }
}

Future<ProductionAccessoryUsage?> showProductionAccessoryDialog(
  BuildContext context, {
  ProductionAccessoryUsage? initialValue,
}) async {
  final nameController = TextEditingController(
    text: initialValue?.name ?? 'Accessoire',
  );
  final quantityController = TextEditingController(
    text: _editable(initialValue?.quantityPerUnit ?? 1),
  );
  final priceController = TextEditingController(
    text: _editable(initialValue?.unitPrice ?? 1),
  );

  try {
    return await showDialog<ProductionAccessoryUsage>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          initialValue == null ? 'Ajouter un accessoire' : 'Modifier l’accessoire',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const ValueKey('accessory-name'),
                controller: nameController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nom de l’accessoire',
                  prefixIcon: Icon(Icons.construction_outlined),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey('accessory-quantity'),
                controller: quantityController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Quantité utilisée par unité',
                  suffixText: 'qté',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey('accessory-price'),
                controller: priceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Prix unitaire',
                  suffixText: '€',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              final quantity = _parse(quantityController.text);
              final price = _parse(priceController.text);
              if (name.isEmpty || quantity <= 0 || price < 0) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('Renseigne un nom, une quantité et un prix valides.'),
                  ),
                );
                return;
              }
              Navigator.of(dialogContext).pop(
                ProductionAccessoryUsage(
                  name: name,
                  quantityPerUnit: quantity,
                  unitPrice: price,
                ),
              );
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  } finally {
    nameController.dispose();
    quantityController.dispose();
    priceController.dispose();
  }
}

class _ResourceHeader extends StatelessWidget {
  const _ResourceHeader({
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
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
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

class _MachineTile extends StatelessWidget {
  const _MachineTile({
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
          '${_number(machine.watts, 0)} W • ${_number(machine.minutesPerUnit, 1)} min • ×${machine.quantity}',
      trailing:
          '${_number(machine.kwhPerUnit, 4)} kWh\n${_money(machine.costPerUnit(electricityRate))} €',
      onEdit: onEdit,
      onDelete: onDelete,
    );
  }
}

class _AccessoryTile extends StatelessWidget {
  const _AccessoryTile({
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
          '${_number(accessory.quantityPerUnit, 2)} × ${_money(accessory.unitPrice)} €',
      trailing: '${_money(accessory.costPerUnit)} €',
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
                const SizedBox(height: 2),
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

class _EmptyResource extends StatelessWidget {
  const _EmptyResource({required this.text});

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

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({required this.icon, required this.text});

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

double _parse(String value) => double.tryParse(
      value.trim().replaceAll(' ', '').replaceAll(',', '.'),
    ) ??
    0;

String _money(double value) => _number(value, 2);

String _number(double value, int digits) =>
    (value.isFinite ? value : 0).toStringAsFixed(digits).replaceAll('.', ',');

String _editable(double value) {
  final rounded = value.roundToDouble();
  return value == rounded ? value.toStringAsFixed(0) : value.toString();
}