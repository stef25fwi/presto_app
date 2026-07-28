import 'package:flutter/material.dart';

import 'entrepreneur_pricing_models.dart';

Future<ProductionMachineUsage?> showProductionMachineDialog(
  BuildContext context, {
  ProductionMachineUsage? initialValue,
}) async {
  final name = TextEditingController(
    text: initialValue?.name ?? 'Machine principale',
  );
  final watts = TextEditingController(
    text: _editable(initialValue?.watts ?? 1000),
  );
  final minutes = TextEditingController(
    text: _editable(initialValue?.minutesPerUnit ?? 30),
  );
  final quantity = TextEditingController(
    text: '${initialValue?.quantity ?? 1}',
  );

  try {
    return await showDialog<ProductionMachineUsage>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          initialValue == null ? 'Ajouter une machine' : 'Modifier la machine',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const ValueKey('machine-name'),
                controller: name,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nom de la machine',
                  prefixIcon: Icon(Icons.precision_manufacturing_outlined),
                ),
              ),
              const SizedBox(height: 10),
              _DialogNumberField(
                key: const ValueKey('machine-watts'),
                controller: watts,
                label: 'Puissance',
                suffix: 'W',
              ),
              const SizedBox(height: 10),
              _DialogNumberField(
                key: const ValueKey('machine-minutes'),
                controller: minutes,
                label: 'Temps d’utilisation par unité',
                suffix: 'min',
              ),
              const SizedBox(height: 10),
              _DialogNumberField(
                key: const ValueKey('machine-quantity'),
                controller: quantity,
                label: 'Nombre de machines identiques',
                suffix: 'nb',
                integer: true,
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
              final machineName = name.text.trim();
              final machineWatts = _parse(watts.text);
              final machineMinutes = _parse(minutes.text);
              final machineQuantity = int.tryParse(quantity.text.trim()) ?? 0;
              if (machineName.isEmpty ||
                  machineWatts <= 0 ||
                  machineMinutes <= 0 ||
                  machineQuantity <= 0) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Renseigne un nom, une puissance, une durée et une quantité valides.',
                    ),
                  ),
                );
                return;
              }
              Navigator.of(dialogContext).pop(
                ProductionMachineUsage(
                  name: machineName,
                  watts: machineWatts,
                  minutesPerUnit: machineMinutes,
                  quantity: machineQuantity,
                ),
              );
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  } finally {
    name.dispose();
    watts.dispose();
    minutes.dispose();
    quantity.dispose();
  }
}

class _DialogNumberField extends StatelessWidget {
  const _DialogNumberField({
    super.key,
    required this.controller,
    required this.label,
    required this.suffix,
    this.integer = false,
  });

  final TextEditingController controller;
  final String label;
  final String suffix;
  final bool integer;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: integer
          ? TextInputType.number
          : const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, suffixText: suffix),
    );
  }
}

double _parse(String value) => double.tryParse(
      value.trim().replaceAll(' ', '').replaceAll(',', '.'),
    ) ??
    0.0;

String _editable(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toString();