import 'package:flutter/material.dart';

import '../core/localization/locale_controller.dart';
import '../l10n/app_localizations.dart';
import '../utils/friendly_snackbar.dart';

Future<void> _applyLocale(BuildContext context, Locale? locale) async {
  if (locale == null) {
    await LocaleController.instance.useSystemLocale();
  } else {
    await LocaleController.instance.setLocale(locale);
  }
  if (!context.mounted) return;
  Navigator.of(context).pop();
  showPrestoSnackBar(context, AppLocalizations.of(context).languageChanged);
}

/// Feuille de sélection de la langue de l'application.
///
/// `null` correspond au suivi automatique de la langue de l'appareil ; le
/// choix est persisté par [LocaleController].
void showLanguagePickerSheet(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => ListenableBuilder(
      listenable: LocaleController.instance,
      builder: (builderContext, _) {
        final current = LocaleController.instance.locale;
        Widget option(Locale? value, String label) => RadioListTile<Locale?>(
              value: value,
              groupValue: current,
              title: Text(label),
              onChanged: (selected) => _applyLocale(builderContext, selected),
            );
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.languageTitle,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              option(null, l10n.languageSystem),
              option(const Locale('fr'), l10n.languageFrench),
              option(const Locale('en'), l10n.languageEnglish),
              option(const Locale('es'), l10n.languageSpanish),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    ),
  );
}
