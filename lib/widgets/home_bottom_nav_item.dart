import 'package:flutter/material.dart';

class HomeBottomNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool isBig;
  final VoidCallback onTap;

  const HomeBottomNavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.isBig = false,
  });

  @override
  State<HomeBottomNavItem> createState() => _HomeBottomNavItemState();
}

class _HomeBottomNavItemState extends State<HomeBottomNavItem>
    with SingleTickerProviderStateMixin {
  static const Color _kPrestoOrange = Color(0xFFFF6600);

  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant HomeBottomNavItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected && !oldWidget.selected) {
      _controller.forward().then((_) {
        if (mounted) {
          _controller.reverse();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Colors.white;
    final fontWeight = widget.selected ? FontWeight.w700 : FontWeight.w500;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                padding: EdgeInsets.all(widget.isBig ? 6 : 4),
                decoration: BoxDecoration(
                  color: widget.isBig
                      ? Colors.white
                      : widget.selected
                          ? Colors.white.withOpacity(0.35)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: widget.isBig
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : widget.selected
                          ? [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.5),
                                blurRadius: 12,
                                spreadRadius: 3,
                              ),
                            ]
                          : null,
                ),
                child: Icon(
                  widget.icon,
                  size: widget.isBig ? 28 : 24,
                  color: widget.isBig ? _kPrestoOrange : color,
                ),
              ),
            ),
            const SizedBox(height: 3),
            SizedBox(
              width: 70,
              child: Text(
                widget.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: widget.isBig ? 10.5 : 10,
                  height: 1.05,
                  color: color,
                  fontWeight: fontWeight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}