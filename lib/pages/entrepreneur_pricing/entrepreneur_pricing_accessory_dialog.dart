import 'package:flutter/material.dart';

import 'entrepreneur_pricing_models.dart';

Future<ProductionAccessoryUsage?> showProductionAccessoryDialog(
  BuildContext context, {
  ProductionAccessoryUsage? initialValue,
}) async {
  final name = TextEditingController(text: initialValue?.name ?? 'Accessoire');
  final quantity = TextEditingController(
    text: _editable(initialValue?.quantityPerUnit ?? 1),
  );
  final price = TextEditingController(
    text: _editable(initialValue?.unitPrice ?? 1),
  );

  try {
    return await showDialog<ProductionAccessoryUsage>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          initialValue == null
              ? 'Ajouter un accessoire'
              : 'Modifier l’accessoire',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const ValueKey('accessory-name'),
                controller: name,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nom de l’accessoire',
                  prefixIcon: Icon(Icons.construction_outlined),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey('accessory-quantity'),
                controller: quantity,
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
                controller: price,
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
              final accessoryName = name.text.trim();
              final accessoryQuantity = _parse(quantity.text);
              final accessoryPrice = _parse(price.text);
              if (accessoryName.isEmpty ||
                  accessoryQuantity <= 0 ||
                  accessoryPrice < 0) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Renseigne un nom, une quantité et un prix valides.',
                    ),
                  ),
                );
                return;
              }
              Navigator.of(dialogContext).pop(
                ProductionAccessoryUsage(
                  name: accessoryName,
                  quantityPerUnit: accessoryQuantity,
                  unitPrice: accessoryPrice,
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
    quantity.dispose();
    price.dispose();
  }
}

double _parse(String value) => double.tryParse(
      value.trim().replaceAll(' ', '').replaceAll(',', '.'),
    ) ??
    0.0;

String _editable(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toString();