import 'dart:math' as math;

enum EntrepreneurPricingMode { standard, expert }

extension EntrepreneurPricingModeLabel on EntrepreneurPricingMode {
  String get label =>
      this == EntrepreneurPricingMode.standard ? 'Standard' : 'Expert';
}

double pricingJsonDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0.0;
}

int pricingJsonInt(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _positive(double value) => value < 0 ? 0.0 : value;
int _positiveInt(int value) => value < 0 ? 0 : value;

class ProductionMachineUsage {
  const ProductionMachineUsage({
    required this.name,
    required this.watts,
    required this.minutesPerUnit,
    this.quantity = 1,
  });

  final String name;
  final double watts;
  final double minutesPerUnit;
  final int quantity;

  double get kwhPerUnit =>
      (_positive(watts) / 1000.0) *
      (_positive(minutesPerUnit) / 60.0) *
      _positiveInt(quantity).toDouble();

  double costPerUnit(double electricityRate) =>
      kwhPerUnit * _positive(electricityRate);

  Map<String, dynamic> toJson() => {
        'name': name,
        'watts': watts,
        'minutesPerUnit': minutesPerUnit,
        'quantity': quantity,
      };

  factory ProductionMachineUsage.fromJson(Map<String, dynamic> json) {
    return ProductionMachineUsage(
      name: json['name']?.toString() ?? 'Machine',
      watts: pricingJsonDouble(json['watts']),
      minutesPerUnit: pricingJsonDouble(json['minutesPerUnit']),
      quantity: math.max(pricingJsonInt(json['quantity']), 1),
    );
  }
}

class ProductionAccessoryUsage {
  const ProductionAccessoryUsage({
    required this.name,
    required this.quantityPerUnit,
    required this.unitPrice,
  });

  final String name;
  final double quantityPerUnit;
  final double unitPrice;

  double get costPerUnit =>
      _positive(quantityPerUnit) * _positive(unitPrice);

  Map<String, dynamic> toJson() => {
        'name': name,
        'quantityPerUnit': quantityPerUnit,
        'unitPrice': unitPrice,
      };

  factory ProductionAccessoryUsage.fromJson(Map<String, dynamic> json) {
    return ProductionAccessoryUsage(
      name: json['name']?.toString() ?? 'Accessoire',
      quantityPerUnit: pricingJsonDouble(json['quantityPerUnit']),
      unitPrice: pricingJsonDouble(json['unitPrice']),
    );
  }
}

class EntrepreneurPricingDraft {
  const EntrepreneurPricingDraft({
    required this.projectName,
    required this.mode,
    required this.expectedPriceTtc,
    required this.materials,
    required this.packaging,
    required this.consumables,
    required this.workMinutes,
    required this.hourlyRate,
    required this.monthlyFixedCosts,
    required this.monthlyVolume,
    required this.equipmentInvestment,
    required this.equipmentSharePerUnit,
    required this.externalFeePercent,
    required this.externalFixedFee,
    required this.marginPercent,
    required this.vatPercent,
    required this.regionCode,
    required this.electricityRate,
    required this.waterM3PerUnit,
    required this.waterRate,
    required this.transportPerUnit,
    required this.otherCostsPerUnit,
    required this.machines,
    required this.accessories,
    required this.marketLow,
    required this.marketMid,
    required this.marketHigh,
    required this.prudentVolume,
    required this.highVolume,
  });

  final String projectName;
  final EntrepreneurPricingMode mode;
  final double expectedPriceTtc;
  final double materials;
  final double packaging;
  final double consumables;
  final int workMinutes;
  final double hourlyRate;
  final double monthlyFixedCosts;
  final int monthlyVolume;
  final double equipmentInvestment;
  final double equipmentSharePerUnit;
  final double externalFeePercent;
  final double externalFixedFee;
  final double marginPercent;
  final double vatPercent;
  final String regionCode;
  final double electricityRate;
  final double waterM3PerUnit;
  final double waterRate;
  final double transportPerUnit;
  final double otherCostsPerUnit;
  final List<ProductionMachineUsage> machines;
  final List<ProductionAccessoryUsage> accessories;
  final double marketLow;
  final double marketMid;
  final double marketHigh;
  final int prudentVolume;
  final int highVolume;

  double get machineKwhPerUnit => machines.fold<double>(
        0.0,
        (total, machine) => total + machine.kwhPerUnit,
      );

  double get machineElectricityCostPerUnit => machines.fold<double>(
        0.0,
        (total, machine) => total + machine.costPerUnit(electricityRate),
      );

  double get accessoriesCostPerUnit => accessories.fold<double>(
        0.0,
        (total, accessory) => total + accessory.costPerUnit,
      );

  Map<String, dynamic> toJson() => {
        'projectName': projectName,
        'mode': mode.name,
        'expectedPriceTtc': expectedPriceTtc,
        'materials': materials,
        'packaging': packaging,
        'consumables': consumables,
        'workMinutes': workMinutes,
        'hourlyRate': hourlyRate,
        'monthlyFixedCosts': monthlyFixedCosts,
        'monthlyVolume': monthlyVolume,
        'equipmentInvestment': equipmentInvestment,
        'equipmentSharePerUnit': equipmentSharePerUnit,
        'externalFeePercent': externalFeePercent,
        'externalFixedFee': externalFixedFee,
        'marginPercent': marginPercent,
        'vatPercent': vatPercent,
        'regionCode': regionCode,
        'electricityRate': electricityRate,
        'waterM3PerUnit': waterM3PerUnit,
        'waterRate': waterRate,
        'transportPerUnit': transportPerUnit,
        'otherCostsPerUnit': otherCostsPerUnit,
        'machines': machines.map((item) => item.toJson()).toList(),
        'accessories': accessories.map((item) => item.toJson()).toList(),
        'marketLow': marketLow,
        'marketMid': marketMid,
        'marketHigh': marketHigh,
        'prudentVolume': prudentVolume,
        'highVolume': highVolume,
      };

  factory EntrepreneurPricingDraft.fromJson(Map<String, dynamic> json) {
    List<T> decodeList<T>(
      Object? raw,
      T Function(Map<String, dynamic>) decoder,
    ) {
      if (raw is! List) return <T>[];
      return raw
          .whereType<Map>()
          .map((item) => decoder(Map<String, dynamic>.from(item)))
          .toList();
    }

    return EntrepreneurPricingDraft(
      projectName: json['projectName']?.toString() ?? 'Calcul sans nom',
      mode: json['mode'] == EntrepreneurPricingMode.expert.name
          ? EntrepreneurPricingMode.expert
          : EntrepreneurPricingMode.standard,
      expectedPriceTtc: pricingJsonDouble(json['expectedPriceTtc']),
      materials: pricingJsonDouble(json['materials']),
      packaging: pricingJsonDouble(json['packaging']),
      consumables: pricingJsonDouble(json['consumables']),
      workMinutes: pricingJsonInt(json['workMinutes']),
      hourlyRate: pricingJsonDouble(json['hourlyRate']),
      monthlyFixedCosts: pricingJsonDouble(json['monthlyFixedCosts']),
      monthlyVolume: math.max(pricingJsonInt(json['monthlyVolume']), 1),
      equipmentInvestment: pricingJsonDouble(json['equipmentInvestment']),
      equipmentSharePerUnit:
          pricingJsonDouble(json['equipmentSharePerUnit']),
      externalFeePercent: pricingJsonDouble(json['externalFeePercent']),
      externalFixedFee: pricingJsonDouble(json['externalFixedFee']),
      marginPercent: pricingJsonDouble(json['marginPercent']),
      vatPercent: pricingJsonDouble(json['vatPercent']),
      regionCode: json['regionCode']?.toString() ?? '971',
      electricityRate: pricingJsonDouble(json['electricityRate']),
      waterM3PerUnit: pricingJsonDouble(json['waterM3PerUnit']),
      waterRate: pricingJsonDouble(json['waterRate']),
      transportPerUnit: pricingJsonDouble(json['transportPerUnit']),
      otherCostsPerUnit: pricingJsonDouble(json['otherCostsPerUnit']),
      machines: decodeList(
        json['machines'],
        ProductionMachineUsage.fromJson,
      ),
      accessories: decodeList(
        json['accessories'],
        ProductionAccessoryUsage.fromJson,
      ),
      marketLow: pricingJsonDouble(json['marketLow']),
      marketMid: pricingJsonDouble(json['marketMid']),
      marketHigh: pricingJsonDouble(json['marketHigh']),
      prudentVolume: math.max(pricingJsonInt(json['prudentVolume']), 1),
      highVolume: math.max(pricingJsonInt(json['highVolume']), 1),
    );
  }
}

class EntrepreneurPricingCalculation {
  const EntrepreneurPricingCalculation({
    required this.materialCost,
    required this.accessoryCost,
    required this.machineKwh,
    required this.machineElectricityCost,
    required this.waterCost,
    required this.transportAndOtherCost,
    required this.laborCost,
    required this.fixedCostPerUnit,
    required this.amortizationPerUnit,
    required this.costPrice,
    required this.minimumPriceTtc,
    required this.suggestedPriceTtc,
    required this.expectedUnitProfit,
    required this.suggestedUnitProfit,
    required this.unitsToAmortize,
    required this.breakEvenUnits,
    required this.expectedPriceIsProfitable,
  });

  final double materialCost;
  final double accessoryCost;
  final double machineKwh;
  final double machineElectricityCost;
  final double waterCost;
  final double transportAndOtherCost;
  final double laborCost;
  final double fixedCostPerUnit;
  final double amortizationPerUnit;
  final double costPrice;
  final double minimumPriceTtc;
  final double suggestedPriceTtc;
  final double expectedUnitProfit;
  final double suggestedUnitProfit;
  final int unitsToAmortize;
  final int breakEvenUnits;
  final bool expectedPriceIsProfitable;

  Map<String, dynamic> toJson() => {
        'materialCost': materialCost,
        'accessoryCost': accessoryCost,
        'machineKwh': machineKwh,
        'machineElectricityCost': machineElectricityCost,
        'waterCost': waterCost,
        'transportAndOtherCost': transportAndOtherCost,
        'laborCost': laborCost,
        'fixedCostPerUnit': fixedCostPerUnit,
        'amortizationPerUnit': amortizationPerUnit,
        'costPrice': costPrice,
        'minimumPriceTtc': minimumPriceTtc,
        'suggestedPriceTtc': suggestedPriceTtc,
        'expectedUnitProfit': expectedUnitProfit,
        'suggestedUnitProfit': suggestedUnitProfit,
        'unitsToAmortize': unitsToAmortize,
        'breakEvenUnits': breakEvenUnits,
        'expectedPriceIsProfitable': expectedPriceIsProfitable,
      };

  factory EntrepreneurPricingCalculation.fromJson(Map<String, dynamic> json) {
    return EntrepreneurPricingCalculation(
      materialCost: pricingJsonDouble(json['materialCost']),
      accessoryCost: pricingJsonDouble(json['accessoryCost']),
      machineKwh: pricingJsonDouble(json['machineKwh']),
      machineElectricityCost:
          pricingJsonDouble(json['machineElectricityCost']),
      waterCost: pricingJsonDouble(json['waterCost']),
      transportAndOtherCost:
          pricingJsonDouble(json['transportAndOtherCost']),
      laborCost: pricingJsonDouble(json['laborCost']),
      fixedCostPerUnit: pricingJsonDouble(json['fixedCostPerUnit']),
      amortizationPerUnit: pricingJsonDouble(json['amortizationPerUnit']),
      costPrice: pricingJsonDouble(json['costPrice']),
      minimumPriceTtc: pricingJsonDouble(json['minimumPriceTtc']),
      suggestedPriceTtc: pricingJsonDouble(json['suggestedPriceTtc']),
      expectedUnitProfit: pricingJsonDouble(json['expectedUnitProfit']),
      suggestedUnitProfit: pricingJsonDouble(json['suggestedUnitProfit']),
      unitsToAmortize: pricingJsonInt(json['unitsToAmortize']),
      breakEvenUnits: pricingJsonInt(json['breakEvenUnits']),
      expectedPriceIsProfitable: json['expectedPriceIsProfitable'] == true,
    );
  }
}

class EntrepreneurPricingScenario {
  const EntrepreneurPricingScenario({
    required this.label,
    required this.volume,
    required this.revenueTtc,
    required this.monthlyProfit,
  });

  final String label;
  final int volume;
  final double revenueTtc;
  final double monthlyProfit;
}

class EntrepreneurPricingEngine {
  const EntrepreneurPricingEngine._();

  static EntrepreneurPricingCalculation compute(
    EntrepreneurPricingDraft draft,
  ) {
    final materialCost = _positive(draft.materials) +
        _positive(draft.packaging) +
        _positive(draft.consumables);
    final expert = draft.mode == EntrepreneurPricingMode.expert;
    final accessoryCost = expert ? draft.accessoriesCostPerUnit : 0.0;
    final machineKwh = expert ? draft.machineKwhPerUnit : 0.0;
    final machineElectricityCost =
        expert ? draft.machineElectricityCostPerUnit : 0.0;
    final waterCost = expert
        ? _positive(draft.waterM3PerUnit) * _positive(draft.waterRate)
        : 0.0;
    final transportAndOther = expert
        ? _positive(draft.transportPerUnit) +
            _positive(draft.otherCostsPerUnit)
        : 0.0;
    final laborCost = (_positiveInt(draft.workMinutes).toDouble() / 60.0) *
        _positive(draft.hourlyRate);
    final safeVolume = math.max(draft.monthlyVolume, 1);
    final fixedCostPerUnit =
        _positive(draft.monthlyFixedCosts) / safeVolume.toDouble();
    final amortization = _positive(draft.equipmentSharePerUnit);
    final costPrice = materialCost +
        accessoryCost +
        machineElectricityCost +
        waterCost +
        transportAndOther +
        laborCost +
        fixedCostPerUnit +
        amortization;

    final feeRate = (_positive(draft.externalFeePercent) / 100.0)
        .clamp(0.0, 0.999)
        .toDouble();
    final fixedFee = _positive(draft.externalFixedFee);
    final marginRate = _positive(draft.marginPercent) / 100.0;
    final vatRate = _positive(draft.vatPercent) / 100.0;
    final minimumHt = (costPrice + fixedFee) / (1.0 - feeRate);
    final suggestedHt =
        ((costPrice * (1.0 + marginRate)) + fixedFee) / (1.0 - feeRate);
    final minimumTtc = minimumHt * (1.0 + vatRate);
    final suggestedTtc = suggestedHt * (1.0 + vatRate);

    final expectedHt = _positive(draft.expectedPriceTtc) / (1.0 + vatRate);
    final expectedFees = (expectedHt * feeRate) + fixedFee;
    final expectedProfit = expectedHt - costPrice - expectedFees;
    final suggestedFees = (suggestedHt * feeRate) + fixedFee;
    final suggestedProfit = suggestedHt - costPrice - suggestedFees;
    final unitsToAmortize =
        draft.equipmentInvestment > 0.0 && amortization > 0.0
            ? (draft.equipmentInvestment / amortization).ceil()
            : 0;

    final referenceTtc =
        draft.expectedPriceTtc > 0.0 ? draft.expectedPriceTtc : suggestedTtc;
    final referenceHt = referenceTtc / (1.0 + vatRate);
    final referenceFees = (referenceHt * feeRate) + fixedFee;
    final variableCost = costPrice - fixedCostPerUnit;
    final unitContribution = referenceHt - referenceFees - variableCost;
    final breakEvenUnits = draft.monthlyFixedCosts <= 0.0
        ? 0
        : unitContribution > 0.0
            ? (draft.monthlyFixedCosts / unitContribution).ceil()
            : 0;

    return EntrepreneurPricingCalculation(
      materialCost: materialCost,
      accessoryCost: accessoryCost,
      machineKwh: machineKwh,
      machineElectricityCost: machineElectricityCost,
      waterCost: waterCost,
      transportAndOtherCost: transportAndOther,
      laborCost: laborCost,
      fixedCostPerUnit: fixedCostPerUnit,
      amortizationPerUnit: amortization,
      costPrice: costPrice,
      minimumPriceTtc: minimumTtc,
      suggestedPriceTtc: suggestedTtc,
      expectedUnitProfit: expectedProfit,
      suggestedUnitProfit: suggestedProfit,
      unitsToAmortize: unitsToAmortize,
      breakEvenUnits: breakEvenUnits,
      expectedPriceIsProfitable:
          draft.expectedPriceTtc > 0.0 && expectedProfit >= 0.0,
    );
  }

  static EntrepreneurPricingScenario computeScenario(
    EntrepreneurPricingDraft draft, {
    required String label,
    required int volume,
  }) {
    final safeVolume = math.max(volume, 1);
    final calculation = compute(draft);
    final vatRate = _positive(draft.vatPercent) / 100.0;
    final feeRate = (_positive(draft.externalFeePercent) / 100.0)
        .clamp(0.0, 0.999)
        .toDouble();
    final fixedFee = _positive(draft.externalFixedFee);
    final priceTtc = draft.expectedPriceTtc > 0.0
        ? draft.expectedPriceTtc
        : calculation.suggestedPriceTtc;
    final priceHt = priceTtc / (1.0 + vatRate);
    final fees = (priceHt * feeRate) + fixedFee;
    final variableCost = calculation.costPrice - calculation.fixedCostPerUnit;
    final monthlyProfit =
        ((priceHt - fees - variableCost) * safeVolume.toDouble()) -
            _positive(draft.monthlyFixedCosts);

    return EntrepreneurPricingScenario(
      label: label,
      volume: safeVolume,
      revenueTtc: priceTtc * safeVolume.toDouble(),
      monthlyProfit: monthlyProfit,
    );
  }
}