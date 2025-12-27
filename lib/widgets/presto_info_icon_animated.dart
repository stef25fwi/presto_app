import 'package:flutter/material.dart';

class PrestoInfoIconAnimated extends StatefulWidget {
  final VoidCallback onTap;
  final bool showBadge;
  final String badgeText;
   final double size;

  const PrestoInfoIconAnimated({
    super.key,
    required this.onTap,
    this.showBadge = true,
    this.badgeText = "Nouveau",
     this.size = 56,
  });

  @override
  State<PrestoInfoIconAnimated> createState() => _PrestoInfoIconAnimatedState();
}

class _PrestoInfoIconAnimatedState extends State<PrestoInfoIconAnimated>
    with TickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;
  late final AnimationController _vibrationController;
  late final Animation<double> _rotation;

  static const Color kBlue = Color(0xFF1A73E8);
  static const Color kOrange = Color(0xFFFF6600);

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scale = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeInOut),
    );

    _opacity = Tween<double>(begin: 0.65, end: 1.0).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeInOut),
    );

    // Animation de vibration (rotation légère)
    _vibrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..repeat(reverse: true);

    _rotation = Tween<double>(begin: -0.02, end: 0.02).animate(
      CurvedAnimation(parent: _vibrationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    _vibrationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedBuilder(
        animation: Listenable.merge([_c, _vibrationController]),
        builder: (_, __) {
          return Opacity(
            opacity: _opacity.value,
            child: Transform.scale(
              scale: _scale.value,
              child: Transform.rotate(
                angle: _rotation.value,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Halo + icône
                    Container(
                       width: widget.size,
                       height: widget.size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          // Halo bleu léger
                          BoxShadow(
                            color: kBlue.withValues(alpha: 0.20),
                            blurRadius: 26,
                            spreadRadius: 2,
                            offset: const Offset(0, 0),
                          ),
                          // Ombre "card"
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: kBlue, width: 3.0), // liseré bleu
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(3.0), // espace pour liseré interne
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.95),
                                width: 2.0,
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.info_rounded,
                                color: kBlue,
                                 size: widget.size * 0.60,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Badge "Nouveau"
                    if (widget.showBadge)
                      Positioned(
                        top: -6,
                        right: -10,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                               horizontal: widget.size * 0.08, vertical: widget.size * 0.04),
                          decoration: BoxDecoration(
                            color: kOrange,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.18),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Text(
                            widget.badgeText,
                            style: TextStyle(
                              color: Colors.white,
                               fontSize: widget.size * 0.10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
