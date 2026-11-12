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
  late AnimationController _floatingController;
  late AnimationController _leftLeafController;
  late AnimationController _rightLeafController;
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

    // 1. Idle breathing: gentle 1-2% organic body expansion & contraction (3000ms)
    _idleBreathingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    // 2. Subtle body floating: slow, soothing floating cycle (3800ms)
    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    )..repeat();

    // 3. Left leaf sprout: independent organic swaying (2300ms)
    _leftLeafController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2300),
    )..repeat();

    // 4. Right leaf sprout: independent organic swaying with distinct period (2900ms)
    _rightLeafController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2900),
    )..repeat();

    // 5. Blinking controller: quick, natural eyelid close-and-open (140ms)
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );

    // 6. Processing float: continuous hovering oscillation during AI request (1400ms)
    _processingFloatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // 7. Bounce: elastic vertical hop for greeting entrance and item added (520ms)
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );

    // 8. Tilt: curious angle for thinking and confused error (400ms)
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
        if (!_floatingController.isAnimating) {
          _floatingController.repeat();
        }
        if (!_leftLeafController.isAnimating) {
          _leftLeafController.repeat();
        }
        if (!_rightLeafController.isAnimating) {
          _rightLeafController.repeat();
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
        _floatingController.stop();
        if (!_processingFloatController.isAnimating) {
          _processingFloatController.repeat(reverse: true);
        }
        break;

      case ChilluState.recipeFound:
      case ChilluState.mealLogged:
        _processingFloatController.stop();
        _idleBreathingController.stop();
        _floatingController.stop();
        break;

      case ChilluState.sleepy:
        _processingFloatController.stop();
        _tiltController.animateTo(0.2, curve: Curves.easeOut);
        if (!_idleBreathingController.isAnimating) {
          _idleBreathingController.repeat(reverse: true);
        }
        if (!_floatingController.isAnimating) {
          _floatingController.repeat();
        }
        break;
    }
  }

  /// Schedules the next natural eye blink with irregular timing (3.0s to 6.0s).
  void _scheduleNextBlink() {
    _blinkTimer?.cancel();
    if (!mounted) return;

    final nextInterval = 3000 + _random.nextInt(3000);
    _blinkTimer = Timer(Duration(milliseconds: nextInterval), () {
      if (!mounted) return;

      // Only blink in non-celebration states
      if (!_controller.isCelebrationJump) {
        _blinkController.forward(from: 0.0).then((_) {
          if (!mounted) return;
          _blinkController.reverse().then((_) {
            if (!mounted) return;
            // 20% chance of a double-blink (two quick blinks in succession)
            if (_random.nextDouble() < 0.20) {
              Future.delayed(const Duration(milliseconds: 120), () {
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
    _floatingController.dispose();
    _leftLeafController.dispose();
    _rightLeafController.dispose();
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
        _floatingController,
        _leftLeafController,
        _rightLeafController,
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

        // 1. Idle breathing: 1-2% subtle chest expansion & contraction
        if (state == ChilluState.idle || state == ChilluState.sleepy) {
          final breathProgress = Curves.easeInOut.transform(_idleBreathingController.value);
          scaleY = 1.0 + (breathProgress * 0.018); // ~1.8% expansion
          scaleX = 1.0 - (breathProgress * 0.010); // ~1.0% contraction
        }

        // 2. Subtle body floating: slow, soothing floating cycle
        if (state == ChilluState.idle || state == ChilluState.sleepy) {
          final floatVal = _floatingController.value;
          // Smooth sine curve: floats upwards by up to 2.2px
          translateY += -2.2 * math.sin(floatVal * 2 * math.pi);
        }

        // 3. Processing floating effect
        if (state == ChilluState.processing) {
          final floatVal = _processingFloatController.value;
          translateY = -8.0 * math.sin(floatVal * math.pi);
          scaleY = 1.0 + (floatVal * 0.02);
        }

        // 4. Bounce effect (greeting entrance / itemAdded)
        if (_bounceController.isAnimating) {
          final bVal = _bounceController.value;
          final hop = 4 * bVal * (1 - bVal);
          translateY = -15.0 * hop;
          if (bVal < 0.2) {
            scaleY = 0.94;
            scaleX = 1.05;
          } else if (bVal < 0.6) {
            scaleY = 1.06;
            scaleX = 0.96;
          }
        }

        // 5. Tilt effect (thinking / error)
        if (_tiltController.value > 0.0) {
          final tVal = _tiltController.value;
          if (state == ChilluState.error) {
            rotation = math.sin(tVal * math.pi * 3) * 0.08;
            translateY += 2.0;
          } else {
            rotation = tVal * 0.08;
          }
        }

        // 6. Independent leaf sprout sway calculation
        final bool isIdleState = state == ChilluState.idle || state == ChilluState.sleepy || state == ChilluState.thinking;
        final double leftLeafAngle = isIdleState
            ? math.sin(_leftLeafController.value * 2 * math.pi) * 0.020
            : 0.0;
        final double rightLeafAngle = isIdleState
            ? math.sin(_rightLeafController.value * 2 * math.pi) * -0.016
            : 0.0;

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
                    if (!isIdleState)
                      // Non-idle states: full character in one layer
                      Image.asset(
                        ChilluMascot.masterAsset,
                        width: widget.size,
                        height: widget.size,
                        fit: BoxFit.contain,
                      )
                    else ...[
                      // 1. Chillu body layer (below the sprouts, seamless stem connection)
                      ClipRect(
                        clipper: const _BodyClipper(),
                        child: Image.asset(
                          ChilluMascot.masterAsset,
                          width: widget.size,
                          height: widget.size,
                          fit: BoxFit.contain,
                        ),
                      ),

                      // 2. Left leafy sprout (independent organic swaying anchored at stem root)
                      Transform.rotate(
                        angle: leftLeafAngle,
                        alignment: const Alignment(-0.01, -0.51),
                        child: ClipRect(
                          clipper: const _LeftLeafClipper(),
                          child: Image.asset(
                            ChilluMascot.masterAsset,
                            width: widget.size,
                            height: widget.size,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),

                      // 3. Right leafy sprout (independent organic swaying anchored at stem root)
                      Transform.rotate(
                        angle: rightLeafAngle,
                        alignment: const Alignment(-0.01, -0.51),
                        child: ClipRect(
                          clipper: const _RightLeafClipper(),
                          child: Image.asset(
                            ChilluMascot.masterAsset,
                            width: widget.size,
                            height: widget.size,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ],

                    // 4. Natural Eye Blinking Overlay
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
      animation: Listenable.merge([
        _idleBreathingController,
        _floatingController,
        _processingFloatController,
        _bounceController,
      ]),
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
        } else if (state == ChilluState.idle || state == ChilluState.sleepy) {
          final breath = Curves.easeInOut.transform(_idleBreathingController.value);
          final floatVal = _floatingController.value;
          final floatSin = math.sin(floatVal * 2 * math.pi);
          // Gently reacts to breathing and floating
          shadowScale = 1.0 + (breath * 0.03) - (floatSin * 0.03);
          shadowOpacity = 0.11 + (breath * 0.02) - (floatSin * 0.02);
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

/// Clips the body portion of Chillu below the sprout leaves (y >= 23.8% of bounding box).
/// Begins at 23.8% of height to allow a seamless 18px overlap with the leaf stems.
class _BodyClipper extends CustomClipper<Rect> {
  const _BodyClipper();

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(0, size.height * 0.238, size.width, size.height);
  }

  @override
  bool shouldReclip(covariant _BodyClipper oldClipper) => false;
}

/// Clips the left leafy sprout (top 25.2% of height, left 49.8% of width).
class _LeftLeafClipper extends CustomClipper<Rect> {
  const _LeftLeafClipper();

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(0, 0, size.width * 0.498, size.height * 0.252);
  }

  @override
  bool shouldReclip(covariant _LeftLeafClipper oldClipper) => false;
}

/// Clips the right leafy sprout (top 25.2% of height, right 49.2% of width to right edge).
class _RightLeafClipper extends CustomClipper<Rect> {
  const _RightLeafClipper();

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(size.width * 0.492, 0, size.width, size.height * 0.252);
  }

  @override
  bool shouldReclip(covariant _RightLeafClipper oldClipper) => false;
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
