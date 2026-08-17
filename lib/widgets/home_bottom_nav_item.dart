import 'package:flutter/material.dart';

class HomeBottomNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool isBig;
  final int badgeCount;
  final VoidCallback onTap;

  const HomeBottomNavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.isBig = false,
    this.badgeCount = 0,
  });

  @override
  State<HomeBottomNavItem> createState() => _HomeBottomNavItemState();
}

class _HomeBottomNavItemState extends State<HomeBottomNavItem>
    with SingleTickerProviderStateMixin {
  static const Color _kPrestoOrange = Color(0xFFFF6600);
  static const double _iconSlotHeight = 46;
  static const double _labelSlotHeight = 22;

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
    final String? badgeLabel =
        widget.badgeCount <= 0 ? null : widget.badgeCount.toString();

    return Semantics(
      button: true,
      selected: widget.selected,
      label: badgeLabel == null
          ? widget.label
          : '${widget.label}, $badgeLabel non lus',
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: widget.onTap,
          child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: SizedBox(
          height: _iconSlotHeight + 3 + _labelSlotHeight,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: _iconSlotHeight,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(widget.isBig ? 7 : 5),
                          decoration: BoxDecoration(
                            color: widget.isBig
                                ? Colors.white
                                : widget.selected
                                    ? Colors.white.withValues(alpha: 0.35)
                                    : Colors.transparent,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: widget.isBig
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.35),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : widget.selected
                                    ? [
                                        BoxShadow(
                                          color: Colors.white.withValues(alpha: 0.5),
                                          blurRadius: 12,
                                          spreadRadius: 3,
                                        ),
                                      ]
                                    : null,
                          ),
                          child: Icon(
                            widget.icon,
                            size: widget.isBig ? 32 : 27,
                            color: widget.isBig ? _kPrestoOrange : color,
                          ),
                        ),
                        if (badgeLabel != null)
                          Positioned(
                            right: -6,
                            top: -4,
                            child: Container(
                              constraints: const BoxConstraints(
                                minWidth: 18,
                                minHeight: 18,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 5),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(999),
                                border:
                                    Border.all(color: Colors.white, width: 1.5),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                badgeLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 3),
              SizedBox(
                width: 70,
                height: _labelSlotHeight,
                child: Align(
                  alignment: Alignment.topCenter,
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
              ),
            ],
          ),
        ),
      ),
        ),
      ),
    );
  }
}
