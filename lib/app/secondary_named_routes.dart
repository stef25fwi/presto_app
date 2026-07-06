import 'package:flutter/material.dart';

import '../pages/toolbox_page.dart';
import '../pages/toolbox_hub_page.dart';

Map<String, WidgetBuilder> buildSecondaryNamedRoutes() {
  return <String, WidgetBuilder>{
    AppRoutes.toolboxHub: (_) => const ToolboxPage(),
    AppRoutes.toolboxCurrent: (_) => const CurrentToolboxPage(),
    AppRoutes.entrepreneurCalculator: (_) => const EntrepreneurCalculatorPage(),
  };
}
