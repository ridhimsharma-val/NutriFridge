import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'chillu_animation_controller.dart';

/// Presentation widget for the NutriFridge Chillu mascot.
/// Handles high-fidelity rendering, organic idle animations (breathing,
/// irregular eye blinking, independent sprout sway, subtle body bobbing),
/// state transitions, reduced-motion accessibility, and celebration GIFs.
class ChilluMascot extends StatefulWidget {
  /// The animation controller driving Chillu's interaction state.
  final ChilluAnimationController? controller;

  /// Display size of the mascot (width and height bounding box).
  final double size;

  /// Optional tap handler for playful interactions.
  final VoidCallback? onTap;

  /// Optional speech bubble or label text to render next to / above Chillu.
  final String? message;

  /// Whether to render a soft ambient ground shadow beneath Chillu.
  final bool showShadow;

  /// Path to master transparent character PNG.
  static const String masterAsset = 'assets/mascot/chillu/chillu_master.png';

  /// Path to joyful jump celebration animated GIF.
  static const String joyfulJumpAsset = 'assets/mascot/chillu/chillu_joyful_jump.gif';

  const ChilluMascot({
    super.key,
    this.controller,
    this.size = 100.0,
    this.onTap,
    this.message,
    this.showShadow = true,
  });

  @override
  State<ChilluMascot> createState() => _ChilluMascotState();
}

class _ChilluMascotState extends State<ChilluMascot> with TickerProviderStateMixin {
  late ChilluAnimationController _controller;
  bool _ownsController = false;

  // Animation controllers for idle lifecycle & expressions
  late AnimationController _idleBreathingController;
  late AnimationController _leafSwayController;
  late AnimationController _blinkController;
  late AnimationController _processingFloatController;
  late AnimationController _bounceController;
  late AnimationController _tiltController;

  Timer? _blinkTimer;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = ChilluAnimationController();
      _ownsController = true;
    }
    _controller.addListener(_onControllerStateChanged);

    // 1. Idle breathing: gentle, organic body expansion and contraction (2600ms)
    _idleBreathingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    // 2. Leaf sprout movement: independent gentle sway (2100ms)
    // Different period from breathing creates lifelike, desynchronized organic motion
    _leafSwayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2100),
    )..repeat(reverse: true);

    // 3. Blinking controller: quick, natural eyelid close-and-open (160ms)
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );

    // 4. Processing float: continuous hovering oscillation during AI request
    _processingFloatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // 5. Bounce: elastic vertical hop for greeting and item added
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // 6. Tilt: curious angle for thinking and confused error
    _tiltController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _syncAnimationsWithState(_controller.state);
    _scheduleNextBlink();
  }

  @override
  void didUpdateWidget(covariant ChilluMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onControllerStateChanged);
      if (_ownsController) {
        _controller.dispose();
        _ownsController = false;
      }
      if (widget.controller != null) {
        _controller = widget.controller!;
      } else {
        _controller = ChilluAnimationController();
        _ownsController = true;
      }
      _controller.addListener(_onControllerStateChanged);
      _syncAnimationsWithState(_controller.state);
    }
  }

  void _onControllerStateChanged() {
    if (!mounted) return;
    _syncAnimationsWithState(_controller.state);
    setState(() {});
  }

  void _syncAnimationsWithState(ChilluState state) {
    switch (state) {
      case ChilluState.idle:
        _tiltController.animateTo(0.0, curve: Curves.easeOut);
        _processingFloatController.stop();
        if (!_idleBreathingController.isAnimating) {
          _idleBreathingController.repeat(reverse: true);
        }
        if (!_leafSwayController.isAnimating) {
          _leafSwayController.repeat(reverse: true);
        }
        break;

      case ChilluState.greeting:
      case ChilluState.itemAdded:
        _processingFloatController.stop();
        _bounceController.forward(from: 0.0);
        break;

      case ChilluState.thinking:
        _processingFloatController.stop();
        _tiltController.animateTo(0.5, curve: Curves.easeInOut);
        break;

      case ChilluState.error:
        _processingFloatController.stop();
        _tiltController.animateTo(1.0, curve: Curves.elasticOut);
        break;

      case ChilluState.processing:
        _idleBreathingController.stop();
        if (!_processingFloatController.isAnimating) {
          _processingFloatController.repeat(reverse: true);
        }
        break;

      case ChilluState.recipeFound:
      case ChilluState.mealLogged:
        _processingFloatController.stop();
        _idleBreathingController.stop();
        break;

      case ChilluState.sleepy:
        _processingFloatController.stop();
        _tiltController.animateTo(0.2, curve: Curves.easeOut);
        if (!_idleBreathingController.isAnimating) {
          _idleBreathingController.repeat(reverse: true);
        }
        break;
    }
  }

  /// Schedules the next natural eye blink with irregular timing (3.2s to 5.6s).
  void _scheduleNextBlink() {
    _blinkTimer?.cancel();
    if (!mounted) return;

    final nextInterval = 3200 + _random.nextInt(2400);
    _blinkTimer = Timer(Duration(milliseconds: nextInterval), () {
      if (!mounted) return;

      // Only blink in non-celebration states
      if (!_controller.isCelebrationJump) {
        _blinkController.forward(from: 0.0).then((_) {
          if (!mounted) return;
          _blinkController.reverse().then((_) {
            if (!mounted) return;
            // 25% chance of a double-blink (two quick blinks in succession)
            if (_random.nextDouble() < 0.25) {
              Future.delayed(const Duration(milliseconds: 110), () {
                if (!mounted) return;
                _blinkController.forward(from: 0.0).then((_) {
                  if (mounted) _blinkController.reverse();
                });
              });
            }
          });
        });
      }
      _scheduleNextBlink();
    });
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _controller.removeListener(_onControllerStateChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    _idleBreathingController.dispose();
    _leafSwayController.dispose();
    _blinkController.dispose();
    _processingFloatController.dispose();
    _bounceController.dispose();
    _tiltController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final state = _controller.state;
    final isCelebration = _controller.isCelebrationJump;

    return Semantics(
      label: 'Chillu mascot, currently ${_stateDescription(state)}',
      image: true,
      child: GestureDetector(
        onTap: widget.onTap ?? () => _controller.greet(),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.message != null && widget.message!.trim().isNotEmpty) ...[
              _buildSpeechBubble(widget.message!),
              const SizedBox(height: 6),
            ],
            SizedBox(
              width: widget.size,
              height: widget.size,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Ground shadow
                  if (widget.showShadow)
                    Positioned(
                      bottom: 2,
                      child: _buildShadow(disableAnimations, state),
                    ),

                  // Mascot character with smooth layered transformations
                  _buildAnimatedCharacter(disableAnimations, isCelebration, state),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedCharacter(bool disableAnimations, bool isCelebration, ChilluState state) {
    if (disableAnimations) {
      // Reduced-motion accessibility: static master PNG directly
      return Image.asset(
        ChilluMascot.masterAsset,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
      );
    }

    if (isCelebration) {
      // Happy Jump celebration: uses transparent animated GIF
      return Image.asset(
        ChilluMascot.joyfulJumpAsset,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
        gaplessPlayback: true,
      );
    }

    // Default & expressive states: animated composite with breathing, sprout sway, and blinking
    return AnimatedBuilder(
      animation: Listenable.merge([
        _idleBreathingController,
        _leafSwayController,
        _blinkController,
        _processingFloatController,
        _bounceController,
        _tiltController,
      ]),
      builder: (context, _) {
        double translateY = 0.0;
        double scaleY = 1.0;
        double scaleX = 1.0;
        double rotation = 0.0;

        // 1. Idle breathing & subtle body bobbing
        if (state == ChilluState.idle || state == ChilluState.sleepy) {
          final breath = _idleBreathingController.value;
          // Organic sine expansion
          scaleY = 1.0 + (breath * 0.022);
          scaleX = 1.0 - (breath * 0.014);
          // Very subtle body bobbing (sub-pixel floating rhythm)
          translateY = -2.0 * math.sin(breath * math.pi);
        }

        // 2. Processing floating effect
        if (state == ChilluState.processing) {
          final floatVal = _processingFloatController.value;
          translateY = -8.0 * math.sin(floatVal * math.pi);
          scaleY = 1.0 + (floatVal * 0.02);
        }

        // 3. Bounce effect (greeting / itemAdded)
        if (_bounceController.isAnimating) {
          final bVal = _bounceController.value;
          final hop = 4 * bVal * (1 - bVal);
          translateY = -14.0 * hop;
          if (bVal < 0.2) {
            scaleY = 0.94;
            scaleX = 1.05;
          } else if (bVal < 0.6) {
            scaleY = 1.06;
            scaleX = 0.96;
          }
        }

        // 4. Tilt effect (thinking / error)
        if (_tiltController.value > 0.0) {
          final tVal = _tiltController.value;
          if (state == ChilluState.error) {
            rotation = math.sin(tVal * math.pi * 3) * 0.08;
            translateY = 2.0;
          } else {
            rotation = tVal * 0.08;
          }
        }

        // 5. Independent sprout leaf sway calculation (anchored at stem root)
        double leafAngle = 0.0;
        if (state == ChilluState.idle || state == ChilluState.thinking || state == ChilluState.sleepy) {
          final lVal = _leafSwayController.value;
          // Smooth sinusoidal rustle (-1.6 deg to +1.6 deg)
          leafAngle = math.sin(lVal * math.pi) * 0.028;
        }

        return Transform.translate(
          offset: Offset(0, translateY),
          child: Transform.rotate(
            angle: rotation,
            alignment: Alignment.bottomCenter,
            child: Transform.scale(
              scaleX: scaleX,
              scaleY: scaleY,
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                width: widget.size,
                height: widget.size,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // Main body and master character
                    Image.asset(
                      ChilluMascot.masterAsset,
                      width: widget.size,
                      height: widget.size,
                      fit: BoxFit.contain,
                    ),

                    // Layered Sprout Leaves with independent gentle sway
                    if (leafAngle.abs() > 0.001)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: widget.size * 0.28,
                        child: ClipRect(
                          clipper: _SproutClipper(),
                          child: Transform.rotate(
                            angle: leafAngle,
                            alignment: const Alignment(0.0, 1.0), // Anchor at stem connection
                            child: Image.asset(
                              ChilluMascot.masterAsset,
                              width: widget.size,
                              height: widget.size,
                              fit: BoxFit.contain,
                              alignment: Alignment.topCenter,
                            ),
                          ),
                        ),
                      ),

                    // Natural Eye Blinking Overlay
                    if (_blinkController.value > 0.0)
                      CustomPaint(
                        size: Size(widget.size, widget.size),
                        painter: _ChilluEyeBlinkPainter(
                          blinkProgress: _blinkController.value,
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

  Widget _buildShadow(bool disableAnimations, ChilluState state) {
    if (disableAnimations) {
      return Container(
        width: widget.size * 0.55,
        height: 6,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
      );
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_idleBreathingController, _processingFloatController, _bounceController]),
      builder: (context, _) {
        double shadowScale = 1.0;
        double shadowOpacity = 0.12;

        if (state == ChilluState.processing) {
          final fVal = _processingFloatController.value;
          shadowScale = 0.85 + (0.15 * (1.0 - fVal));
          shadowOpacity = 0.08 + (0.04 * (1.0 - fVal));
        } else if (_bounceController.isAnimating) {
          final bVal = _bounceController.value;
          final hop = 4 * bVal * (1 - bVal);
          shadowScale = 1.0 - (0.35 * hop);
          shadowOpacity = 0.12 - (0.06 * hop);
        } else if (state == ChilluState.idle) {
          final breath = _idleBreathingController.value;
          shadowScale = 1.0 + (breath * 0.05);
          shadowOpacity = 0.11 + (breath * 0.03);
        }

        return Container(
          width: widget.size * 0.55 * shadowScale,
          height: 7 * shadowScale,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: shadowOpacity.clamp(0.04, 0.15)),
            borderRadius: BorderRadius.all(Radius.elliptical(widget.size * 0.5, 6)),
          ),
        );
      },
    );
  }

  Widget _buildSpeechBubble(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      constraints: BoxConstraints(maxWidth: widget.size * 2.2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B4332).withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF52B788).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1B4332),
          height: 1.2,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  String _stateDescription(ChilluState s) {
    switch (s) {
      case ChilluState.idle:
        return 'happy and waiting';
      case ChilluState.greeting:
        return 'waving hello';
      case ChilluState.thinking:
        return 'thinking';
      case ChilluState.processing:
        return 'searching for recipes';
      case ChilluState.recipeFound:
        return 'excited, recipe found!';
      case ChilluState.itemAdded:
        return 'celebrating added groceries';
      case ChilluState.mealLogged:
        return 'cheering, meal logged!';
      case ChilluState.error:
        return 'confused';
      case ChilluState.sleepy:
        return 'sleepy';
    }
  }
}

/// Custom clipper isolating the two top sprout leaves (top 28% of character bounding box).
class _SproutClipper extends CustomClipper<Rect> {
  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, size.width, size.height);
  }

  @override
  bool shouldReclip(covariant CustomClipper<Rect> oldClipper) => false;
}

/// Custom painter for natural eye blinking over Chillu's exact facial geometry.
class _ChilluEyeBlinkPainter extends CustomPainter {
  final double blinkProgress;

  _ChilluEyeBlinkPainter({required this.blinkProgress});

  @override
  void paint(Canvas canvas, Size size) {
    if (blinkProgress <= 0.0) return;

    // Chillu eye geometry normalized to character canvas
    // Left eye center: (0.3664 * width, 0.4781 * height)
    // Right eye center: (0.6336 * width, 0.4781 * height)
    final eyeWidth = size.width * 0.20;
    final eyeHeight = size.height * 0.23;

    final leftCenter = Offset(size.width * 0.3664, size.height * 0.4781);
    final rightCenter = Offset(size.width * 0.6336, size.height * 0.4781);

    // Eyelid skin tone matching Chillu's mint fur
    final eyelidPaint = Paint()
      ..color = const Color(0xFF53C79C)
      ..style = PaintingStyle.fill;

    // Eyelash/crease line paint matching facial features
    final lashPaint = Paint()
      ..color = const Color(0xFF1B4332)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.6, size.width * 0.02)
      ..strokeCap = StrokeCap.round;

    _paintSingleEye(canvas, leftCenter, eyeWidth, eyeHeight, eyelidPaint, lashPaint);
    _paintSingleEye(canvas, rightCenter, eyeWidth, eyeHeight, eyelidPaint, lashPaint);
  }

  void _paintSingleEye(
    Canvas canvas,
    Offset center,
    double width,
    double height,
    Paint eyelidPaint,
    Paint lashPaint,
  ) {
    final eyeRect = Rect.fromCenter(
      center: center,
      width: width,
      height: height,
    );

    canvas.save();
    // Clip to the exact oval eye opening
    final clipPath = Path()..addOval(eyeRect);
    canvas.clipPath(clipPath);

    // Drop eyelid down according to blink progress
    final lidBottom = eyeRect.top + (eyeRect.height * blinkProgress);
    final lidRect = Rect.fromLTRB(
      eyeRect.left - 2,
      eyeRect.top - 2,
      eyeRect.right + 2,
      lidBottom,
    );
    canvas.drawRect(lidRect, eyelidPaint);

    // When fully/mostly closed, draw the friendly curved eye crease
    if (blinkProgress >= 0.6) {
      final creaseProgress = ((blinkProgress - 0.6) / 0.4).clamp(0.0, 1.0);
      final lashPath = Path();
      final start = Offset(eyeRect.left + (width * 0.12), center.dy + (height * 0.05));
      final control = Offset(center.dx, center.dy + (height * 0.22));
      final end = Offset(eyeRect.right - (width * 0.12), center.dy + (height * 0.05));

      lashPath.moveTo(start.dx, start.dy);
      lashPath.quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);

      final animatedLashPaint = Paint()
        ..color = Color(0xFF1B4332).withValues(alpha: creaseProgress)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.6, width * 0.09)
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(lashPath, animatedLashPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ChilluEyeBlinkPainter oldDelegate) {
    return oldDelegate.blinkProgress != blinkProgress;
  }
}
