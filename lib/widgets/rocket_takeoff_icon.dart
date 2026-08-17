import 'package:flutter/material.dart';

/// Icône fusée animée (décollage + flamme pulsée). Extrait de
/// `widgets/entrepreneur_toolbox_slide.dart` pour rester sous le budget de
/// lignes d'un widget.
class RocketTakeoffIcon extends StatefulWidget {
  const RocketTakeoffIcon({super.key});

  @override
  State<RocketTakeoffIcon> createState() => _RocketTakeoffIconState();
}

class _RocketTakeoffIconState extends State<RocketTakeoffIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        final dy = (1.0 - t) * 3.0;
        final flameOpacity = 0.35 + (t * 0.55);
        return Transform.translate(
          offset: Offset(0, dy),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.rocket_launch_rounded,
                  size: 19,
                  color: Color(0xFFFF6600),
                ),
                Positioned(
                  bottom: 4,
                  child: Opacity(
                    opacity: flameOpacity,
                    child: Container(
                      width: 7,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFA000),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
