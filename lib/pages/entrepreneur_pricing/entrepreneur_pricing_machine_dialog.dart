import 'package:flutter/material.dart';

import 'entrepreneur_pricing_models.dart';

Future<ProductionMachineUsage?> showProductionMachineDialog(
  BuildContext context, {
  ProductionMachineUsage? initialValue,
}) =>
    showDialog<ProductionMachineUsage>(
      context: context,
      builder: (_) => _ProductionMachineDialog(initialValue: initialValue),
    );

class _ProductionMachineDialog extends StatefulWidget {
  const _ProductionMachineDialog({this.initialValue});

  final ProductionMachineUsage? initialValue;

  @override
  State<_ProductionMachineDialog> createState() =>
      _ProductionMachineDialogState();
}

class _ProductionMachineDialogState extends State<_ProductionMachineDialog> {
  late final TextEditingController _name;
  late final TextEditingController _watts;
  late final TextEditingController _minutes;
  late final TextEditingController _quantity;

  @override
  void initState() {
    super.initState();
    final initialValue = widget.initialValue;
    _name = TextEditingController(
      text: initialValue?.name ?? 'Machine principale',
    );
    _watts = TextEditingController(
      text: _editable(initialValue?.watts ?? 1000),
    );
    _minutes = TextEditingController(
      text: _editable(initialValue?.minutesPerUnit ?? 30),
    );
    _quantity = TextEditingController(
      text: '${initialValue?.quantity ?? 1}',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _watts.dispose();
    _minutes.dispose();
    _quantity.dispose();
    super.dispose();
  }

  void _save() {
    final machineName = _name.text.trim();
    final machineWatts = _parse(_watts.text);
    final machineMinutes = _parse(_minutes.text);
    final machineQuantity = int.tryParse(_quantity.text.trim()) ?? 0;

    if (machineName.isEmpty ||
        machineWatts <= 0 ||
        machineMinutes <= 0 ||
        machineQuantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Renseigne un nom, une puissance, une durée et une quantité valides.',
          ),
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      ProductionMachineUsage(
        name: machineName,
        watts: machineWatts,
        minutesPerUnit: machineMinutes,
        quantity: machineQuantity,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initialValue == null
            ? 'Ajouter une machine'
            : 'Modifier la machine',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('machine-name'),
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nom de la machine',
                prefixIcon: Icon(Icons.precision_manufacturing_outlined),
              ),
            ),
            const SizedBox(height: 10),
            _DialogNumberField(
              key: const ValueKey('machine-watts'),
              controller: _watts,
              label: 'Puissance',
              suffix: 'W',
            ),
            const SizedBox(height: 10),
            _DialogNumberField(
              key: const ValueKey('machine-minutes'),
              controller: _minutes,
              label: 'Temps d’utilisation par unité',
              suffix: 'min',
            ),
            const SizedBox(height: 10),
            _DialogNumberField(
              key: const ValueKey('machine-quantity'),
              controller: _quantity,
              label: 'Nombre de machines identiques',
              suffix: 'nb',
              integer: true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Enregistrer'),
        ),
      ],
    );
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
