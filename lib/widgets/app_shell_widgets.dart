import 'package:flutter/material.dart';

class PrestoResponsiveFrame extends StatelessWidget {
  const PrestoResponsiveFrame({super.key, required this.child});

  final Widget child;

  static const double _kMaxContentWidth = 960;
  static const double _kBreakpoint = 1000;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width <= _kBreakpoint) return child;
    return ColoredBox(
      color: Colors.white,
      child: Center(
        child: SizedBox(
          width: _kMaxContentWidth,
          height: double.infinity,
          child: child,
        ),
      ),
    );
  }
}

class CardShell extends StatelessWidget {
  const CardShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}
