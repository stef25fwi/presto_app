import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class TypographyAuditService {
  const TypographyAuditService._();

  static String buildPrettyJson(BuildContext context) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(buildAudit(context));
  }

  static Map<String, dynamic> buildAudit(BuildContext context) {
    final media = MediaQuery.of(context);
    final theme = Theme.of(context);
    final defaultTextStyle = DefaultTextStyle.of(context);

    return {
      'auditVersion': 1,
      'generatedAt': DateTime.now().toIso8601String(),
      'runtime': {
        'isWeb': kIsWeb,
        'platform': defaultTargetPlatform.name,
        'debugMode': kDebugMode,
        'profileMode': kProfileMode,
        'releaseMode': kReleaseMode,
        'url': kIsWeb ? Uri.base.toString() : null,
      },
      'screen': {
        'width': media.size.width,
        'height': media.size.height,
        'devicePixelRatio': media.devicePixelRatio,
        'orientation': media.orientation.name,
        'padding': _edgeInsetsToJson(media.padding),
        'viewPadding': _edgeInsetsToJson(media.viewPadding),
        'viewInsets': _edgeInsetsToJson(media.viewInsets),
      },
      'androidWebMatchRuntime': {
        'textScaler': media.textScaler.toString(),
        'scale11': media.textScaler.scale(11),
        'scale12': media.textScaler.scale(12),
        'scale13': media.textScaler.scale(13),
        'scale14': media.textScaler.scale(14),
        'scale16': media.textScaler.scale(16),
        'boldText': media.boldText,
        'highContrast': media.highContrast,
        'platformBrightness': media.platformBrightness.name,
      },
      'theme': {
        'brightness': theme.brightness.name,
        'useMaterial3': theme.useMaterial3,
        'fontFamilyFromBodyMedium': theme.textTheme.bodyMedium?.fontFamily,
        'defaultTextStyle': _textStyleToJson(defaultTextStyle.style),
        'textTheme': _textThemeToJson(theme.textTheme),
        'primaryTextTheme': _textThemeToJson(theme.primaryTextTheme),
      },
      'recommendedAndroidPatch': {
        'fontFamily': theme.textTheme.bodyMedium?.fontFamily ?? 'Inter',
        'textScaler': 1.0,
        'boldText': false,
        'note':
            'Référence à appliquer côté Android pour éviter les écarts de taille ou de graisse par rapport au rendu Web validé.',
      },
    };
  }

  static Map<String, dynamic> _textThemeToJson(TextTheme theme) {
    return {
      'displayLarge': _textStyleToJson(theme.displayLarge),
      'displayMedium': _textStyleToJson(theme.displayMedium),
      'displaySmall': _textStyleToJson(theme.displaySmall),
      'headlineLarge': _textStyleToJson(theme.headlineLarge),
      'headlineMedium': _textStyleToJson(theme.headlineMedium),
      'headlineSmall': _textStyleToJson(theme.headlineSmall),
      'titleLarge': _textStyleToJson(theme.titleLarge),
      'titleMedium': _textStyleToJson(theme.titleMedium),
      'titleSmall': _textStyleToJson(theme.titleSmall),
      'bodyLarge': _textStyleToJson(theme.bodyLarge),
      'bodyMedium': _textStyleToJson(theme.bodyMedium),
      'bodySmall': _textStyleToJson(theme.bodySmall),
      'labelLarge': _textStyleToJson(theme.labelLarge),
      'labelMedium': _textStyleToJson(theme.labelMedium),
      'labelSmall': _textStyleToJson(theme.labelSmall),
    };
  }

  static Map<String, dynamic>? _textStyleToJson(TextStyle? style) {
    if (style == null) return null;

    return {
      'fontFamily': style.fontFamily,
      'fontFamilyFallback': style.fontFamilyFallback,
      'fontSize': style.fontSize,
      'fontWeight': _fontWeightToString(style.fontWeight),
      'fontStyle': style.fontStyle?.name,
      'height': style.height,
      'leadingDistribution': style.leadingDistribution?.name,
      'letterSpacing': style.letterSpacing,
      'wordSpacing': style.wordSpacing,
      'color': _colorToHex(style.color),
      'backgroundColor': _colorToHex(style.backgroundColor),
      'decoration': style.decoration?.toString(),
      'decorationColor': _colorToHex(style.decorationColor),
      'decorationStyle': style.decorationStyle?.name,
      'decorationThickness': style.decorationThickness,
      'textBaseline': style.textBaseline?.name,
      'overflow': style.overflow?.name,
      'debugLabel': style.debugLabel,
    };
  }

  static String? _fontWeightToString(FontWeight? weight) {
    if (weight == null) return null;

    final values = <FontWeight, String>{
      FontWeight.w100: 'w100',
      FontWeight.w200: 'w200',
      FontWeight.w300: 'w300',
      FontWeight.w400: 'w400',
      FontWeight.w500: 'w500',
      FontWeight.w600: 'w600',
      FontWeight.w700: 'w700',
      FontWeight.w800: 'w800',
      FontWeight.w900: 'w900',
    };

    return values[weight] ?? weight.toString();
  }

  static String? _colorToHex(Color? color) {
    if (color == null) return null;

    final value = color.toARGB32().toRadixString(16).padLeft(8, '0');
    return '#${value.toUpperCase()}';
  }

  static Map<String, double> _edgeInsetsToJson(EdgeInsets insets) {
    return {
      'left': insets.left,
      'top': insets.top,
      'right': insets.right,
      'bottom': insets.bottom,
    };
  }
}
