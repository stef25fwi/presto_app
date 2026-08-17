import 'package:flutter/material.dart';

import '../app/typography_settings.dart';

/// Floating typography control — visible on ALL platforms (Android + web).
/// Renders a small pill button anchored to the bottom-right corner.
/// Tapping it opens a bottom sheet with scale and font-weight sliders.
class TypographyFloatingPanel extends StatelessWidget {
  const TypographyFloatingPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          bottom: 90,
          right: 12,
          child: _TypographyPillButton(),
        ),
      ],
    );
  }
}

class _TypographyPillButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: typographySettings,
      builder: (ctx, _) {
        final isDefault = typographySettings.scale == 1.0 &&
            typographySettings.fontFamily == 'Inter' &&
            typographySettings.fontWeightDelta == 0;
        return Semantics(
          button: true,
          label: 'Réglages de taille et police de texte',
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openSheet(ctx),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDefault
                  ? Colors.black.withValues(alpha: 0.45)
                  : const Color(0xFF1A73E8),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.text_fields_rounded,
                    size: 16, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  'Aa',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontFamily: typographySettings.fontFamily,
                  ),
                ),
              ],
            ),
          ),
            ),
          ),
        );
      },
    );
  }

  void _openSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _TypographySheet(),
    );
  }
}

class _TypographySheet extends StatefulWidget {
  const _TypographySheet();

  @override
  State<_TypographySheet> createState() => _TypographySheetState();
}

class _TypographySheetState extends State<_TypographySheet> {
  late double _scale;
  late String _font;
  late int _weightDelta;

  static const _prestoBlue = Color(0xFF1A73E8);

  @override
  void initState() {
    super.initState();
    _scale = typographySettings.scale;
    _font = typographySettings.fontFamily;
    _weightDelta = typographySettings.fontWeightDelta;
  }

  bool get _isModified =>
      _scale != typographySettings.scale ||
      _font != typographySettings.fontFamily ||
      _weightDelta != typographySettings.fontWeightDelta;

  bool get _isDefault =>
      typographySettings.scale == 1.0 &&
      typographySettings.fontFamily == 'Inter' &&
      typographySettings.fontWeightDelta == 0;

  void _apply() {
    typographySettings.apply(
      scale: _scale,
      fontFamily: _font,
      fontWeightDelta: _weightDelta,
    );
    setState(() {});
  }

  void _reset() {
    setState(() {
      _scale = 1.0;
      _font = 'Inter';
      _weightDelta = 0;
    });
    typographySettings.reset();
  }

  String _weightLabel(int delta) {
    const labels = {
      -2: '−2 léger',
      -1: '−1',
      0: 'Normal',
      1: '+1',
      2: '+2 gras'
    };
    return labels[delta] ?? '$delta';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  const Icon(Icons.text_fields_rounded,
                      size: 20, color: _prestoBlue),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Typographie',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  if (!_isDefault)
                    TextButton(
                      onPressed: _reset,
                      child: const Text('Réinitialiser',
                          style: TextStyle(fontSize: 13)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Taille (scale)
            _Row(
              label: 'Taille',
              child: Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _scale,
                      min: 0.8,
                      max: 1.4,
                      divisions: 12,
                      activeColor: _prestoBlue,
                      onChanged: (v) => setState(() => _scale = v),
                    ),
                  ),
                  SizedBox(
                    width: 46,
                    child: Text(
                      '${(_scale * 100).round()}%',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            ),

            // Graisse (weight delta)
            _Row(
              label: 'Graisse',
              child: Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _weightDelta.toDouble(),
                      min: -2,
                      max: 2,
                      divisions: 4,
                      activeColor: _prestoBlue,
                      onChanged: (v) =>
                          setState(() => _weightDelta = v.round()),
                    ),
                  ),
                  SizedBox(
                    width: 72,
                    child: Text(
                      _weightLabel(_weightDelta),
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            ),

            // Police (font family)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const SizedBox(
                    width: 58,
                    child: Text('Police',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                  ...kAvailableFontFamilies.map((f) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(f,
                              style: TextStyle(
                                  fontFamily: f,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                          selected: _font == f,
                          selectedColor: const Color(0xFFE8F0FE),
                          onSelected: (_) => setState(() => _font = f),
                          side: BorderSide(
                            color: _font == f
                                ? _prestoBlue
                                : const Color(0xFFD7DEE8),
                          ),
                          labelPadding:
                              const EdgeInsets.symmetric(horizontal: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 4),

            // Live preview
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(_scale)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aperçu — $_font ${(_scale * 100).round()}%'
                      '${_weightDelta != 0 ? ' graisse${_weightDelta > 0 ? '+' : ''}$_weightDelta' : ''}',
                      style: TextStyle(
                        fontFamily: _font,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.black38,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('Titre de section',
                        style: TextStyle(
                          fontFamily: _font,
                          fontSize: 18,
                          fontWeight:
                              shiftFontWeight(FontWeight.w700, _weightDelta),
                        )),
                    Text(
                      'Texte courant — iliprestō propose des services.',
                      style: TextStyle(
                        fontFamily: _font,
                        fontSize: 14,
                        fontWeight:
                            shiftFontWeight(FontWeight.w500, _weightDelta),
                        height: 1.35,
                      ),
                    ),
                    Text('Label 12 px',
                        style: TextStyle(
                          fontFamily: _font,
                          fontSize: 12,
                          fontWeight:
                              shiftFontWeight(FontWeight.w500, _weightDelta),
                          color: Colors.black54,
                        )),
                  ],
                ),
              ),
            ),

            // Apply button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isModified ? _apply : null,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Appliquer à toute l\'app'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _prestoBlue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 58,
            child: Text(label,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
