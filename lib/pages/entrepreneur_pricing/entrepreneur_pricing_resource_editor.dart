import 'package:flutter/material.dart';

import 'entrepreneur_pricing_accessory_dialog.dart';
import 'entrepreneur_pricing_machine_dialog.dart';
import 'entrepreneur_pricing_models.dart';
import 'entrepreneur_pricing_resource_tiles.dart';

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
        0.0,
        (total, item) => total + item.kwhPerUnit,
      );

  double get totalElectricityCost => machines.fold<double>(
        0.0,
        (total, item) => total + item.costPerUnit(electricityRate),
      );

  double get totalAccessoryCost => accessories.fold<double>(
        0.0,
        (total, item) => total + item.costPerUnit,
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ResourceHeader(
          icon: Icons.precision_manufacturing_outlined,
          title: 'Machines utilisées',
          subtitle: 'Puissance × durée × quantité',
          actionLabel: 'Ajouter une machine',
          onPressed: () => _addMachine(context),
        ),
        const SizedBox(height: 8),
        if (machines.isEmpty)
          const EmptyResource(
            text:
                'Ajoute chaque machine pour calculer sa consommation électrique exacte.',
          )
        else
          ...machines.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: MachineResourceTile(
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
        ResourceSummaryPill(
          icon: Icons.electric_bolt_rounded,
          text:
              '${resourceNumber(totalKwh, 4)} kWh par unité • '
              '${resourceMoney(totalElectricityCost)} €',
        ),
        const SizedBox(height: 18),
        ResourceHeader(
          icon: Icons.construction_outlined,
          title: 'Accessoires et fournitures',
          subtitle: 'Quantité utilisée × prix unitaire',
          actionLabel: 'Ajouter un accessoire',
          onPressed: () => _addAccessory(context),
        ),
        const SizedBox(height: 8),
        if (accessories.isEmpty)
          const EmptyResource(
            text:
                'Ajoute les accessoires consommés : lames, buses, gants, mèches, filtres…',
          )
        else
          ...accessories.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AccessoryResourceTile(
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
        ResourceSummaryPill(
          icon: Icons.payments_outlined,
          text: '${resourceMoney(totalAccessoryCost)} € par unité',
        ),
      ],
    );
  }

  Future<void> _addMachine(BuildContext context) async {
    final value = await showProductionMachineDialog(context);
    if (value != null) onMachinesChanged([...machines, value]);
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
    if (value != null) onAccessoriesChanged([...accessories, value]);
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