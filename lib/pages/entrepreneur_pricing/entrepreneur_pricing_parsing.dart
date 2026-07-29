double pricingParseNumber(String value) => double.tryParse(
      value.trim().replaceAll(' ', '').replaceAll(',', '.'),
    ) ??
    0.0;

int pricingParseInteger(String value) =>
    int.tryParse(value.trim().replaceAll(' ', '')) ?? 0;

String pricingFormMoney(double value) =>
    (value.isFinite ? value : 0.0).toStringAsFixed(2).replaceAll('.', ',');
