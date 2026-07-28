import 'package:flutter/material.dart';

import 'entrepreneur_pricing_engine.dart';
import 'entrepreneur_pricing_resource_editor.dart' as implementation;

/// Façade publique de l’éditeur de ressources de production.
///
/// Elle maintient une API stable pour le formulaire tout en gardant le détail
/// des interactions machines/accessoires dans un module dédié.
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

  @override
  Widget build(BuildContext context) {
    return implementation.ProductionResourcesEditor(
      machines: machines,
      accessories: accessories,
      electricityRate: electricityRate,
      onMachinesChanged: onMachinesChanged,
      onAccessoriesChanged: onAccessoriesChanged,
    );
  }
}