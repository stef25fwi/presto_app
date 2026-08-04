import 'package:flutter/material.dart';

import 'entrepreneur_pricing_models.dart';

Future<ProductionAccessoryUsage?> showProductionAccessoryDialog(
  BuildContext context, {
  ProductionAccessoryUsage? initialValue,
}) {
  return showDialog<ProductionAccessoryUsage>(
    context: context,
    builder: (_) => _ProductionAccessoryDialog(initialValue: initialValue),
  );
}

class _ProductionAccessoryDialog extends StatefulWidget {
  const _ProductionAccessoryDialog({this.initialValue});

  final ProductionAccessoryUsage? initialValue;

  @override
  State<_ProductionAccessoryDialog> createState() =>
      _ProductionAccessoryDialogState();
}

class _ProductionAccessoryDialogState
    extends State<_ProductionAccessoryDialog> {
  late final TextEditingController _name;
  late final TextEditingController _quantity;
  late final TextEditingController _price;

  @override
  void initState() {
    super.initState();
    final initialValue = widget.initialValue;
    _name = TextEditingController(text: initialValue?.name ?? 'Accessoire');
    _quantity = TextEditingController(
      text: _editable(initialValue?.quantityPerUnit ?? 1),
    );
    _price = TextEditingController(
      text: _editable(initialValue?.unitPrice ?? 1),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _price.dispose();
    super.dispose();
  }

  void _save() {
    final accessoryName = _name.text.trim();
    final accessoryQuantity = _parse(_quantity.text);
    final accessoryPrice = _parse(_price.text);
    if (accessoryName.isEmpty ||
        accessoryQuantity <= 0 ||
        accessoryPrice < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Renseigne un nom, une quantité et un prix valides.',
          ),
        ),
      );
      return;
    }
    Navigator.of(context).pop(
      ProductionAccessoryUsage(
        name: accessoryName,
        quantityPerUnit: accessoryQuantity,
        unitPrice: accessoryPrice,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initialValue == null
            ? 'Ajouter un accessoire'
            : 'Modifier l’accessoire',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('accessory-name'),
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nom de l’accessoire',
                prefixIcon: Icon(Icons.construction_outlined),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('accessory-quantity'),
              controller: _quantity,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Quantité utilisée par unité',
                suffixText: 'qté',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('accessory-price'),
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
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

double _parse(String value) =>
    double.tryParse(value.trim().replaceAll(' ', '').replaceAll(',', '.')) ??
    0.0;

String _editable(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toString();