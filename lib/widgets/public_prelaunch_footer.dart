import 'package:flutter/material.dart';

class PublicPrelaunchFooter extends StatelessWidget {
  const PublicPrelaunchFooter({
    super.key,
    required this.compact,
    required this.veryCompact,
    required this.onOpen,
  });

  static const _links = <({String label, String path})>[
    (label: 'Mentions légales', path: '/mentions-legales'),
    (label: 'CGU', path: '/cgu'),
  ];

  final bool compact;
  final bool veryCompact;
  final Future<void> Function(String path) onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Semantics(
          label: 'Informations légales',
          container: true,
          child: LayoutBuilder(
            builder: (context, constraints) {
              const columns = 2;
              const gap = 6.0;
              final itemWidth =
                  (constraints.maxWidth - (gap * (columns - 1))) / columns;

              return Wrap(
                key: const Key('public-prelaunch-footer-links'),
                spacing: gap,
                runSpacing: 4,
                alignment: WrapAlignment.center,
                children: _links.map((link) {
                  return SizedBox(
                    width: itemWidth,
                    child: TextButton(
                      key: Key('public-prelaunch-link-${link.path}'),
                      onPressed: () => onOpen(link.path),
                      style: TextButton.styleFrom(
                        alignment: Alignment.center,
                        foregroundColor: const Color(0xFF175DB8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 8,
                        ),
                        minimumSize: const Size(44, 40),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: TextStyle(
                          fontSize: compact ? 12 : 13,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                          decorationThickness: 1,
                        ),
                      ),
                      child: Text(link.label, textAlign: TextAlign.center),
                    ),
                  );
                }).toList(growable: false),
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'ilipresto.fr',
          style: TextStyle(
            color: const Color(0xFF6A7785),
            fontSize: veryCompact ? 13 : 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}
