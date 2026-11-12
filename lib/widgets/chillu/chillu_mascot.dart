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

  /// Optional explicit override for disabling animations (e.g. for static historical message avatars).
  final bool? disableAnimations;

  const ChilluMascot({
    super.key,
    this.controller,
    this.size = 100.0,
    this.onTap,
    this.message,
    this.showShadow = true,
    this.disableAnimations,
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
  late AnimationController _listeningPulseController;
  late AnimationController _thinkingCycleController;
  late AnimationController _attentivePerkController;
  late AnimationController _attentiveLoopController;
  late AnimationController _happyController;
  late AnimationController _excitedController;
  late AnimationController _confusedController;
  late AnimationController _celebrationController;

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

    // 8. Tilt: forward lean for attentive posture and error tilt (350ms)
    _tiltController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    // 9. Listening pulse: rhythmic 1000ms audio bounce & audio-wave pulses
    _listeningPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // 10. Thinking cycle: alternating left-right thoughtful tilt with pauses (2400ms)
    _thinkingCycleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    // 11. Attentive Curious Perk-Up: squash, spring pop up, leaf reaction, side glance, alert pose (750ms)
    _attentivePerkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    // 12. Attentive Continuous Loop: playful spring micro-bounces, body sways, organic leaf swaying, expressive eye movements (3600ms)
    _attentiveLoopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    );

    // 13. Happy reaction: cheerful body bounce (-12px) and smiling eyes (1500ms)
    _happyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // 14. Excited reaction: energetic high jump (-20px) and sparkle eyes (2000ms)
    _excitedController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // 15. Confused reaction: noticeable questioning head tilt and asymmetrical leaf tilt (2200ms)
    _confusedController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    // 16. Celebration reaction: triumphant celebratory leaps, victory squashes, and sparkles (2600ms)
    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
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

  void _stopActiveInteractionControllers() {
    _processingFloatController.stop();
    _listeningPulseController.stop();
    _thinkingCycleController.stop();
    _attentivePerkController.stop();
    _attentiveLoopController.stop();
    _bounceController.stop();
    _tiltController.stop();
    _happyController.stop();
    _excitedController.stop();
    _confusedController.stop();
    _celebrationController.stop();
  }

  void _syncAnimationsWithState(ChilluState state) {
    switch (state) {
      case ChilluState.idle:
        _tiltController.animateTo(0.0, duration: const Duration(milliseconds: 320), curve: Curves.easeOut);
        _processingFloatController.stop();
        _listeningPulseController.stop();
        _thinkingCycleController.stop();
        _attentiveLoopController.stop();
        _happyController.stop();
        _excitedController.stop();
        _confusedController.stop();
        _attentivePerkController.animateTo(0.0, duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
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

      case ChilluState.attentive:
        _stopActiveInteractionControllers();
        _attentivePerkController.forward(from: 0.0);
        if (!_attentiveLoopController.isAnimating) {
          _attentiveLoopController.repeat();
        }
        if (!_idleBreathingController.isAnimating) {
          _idleBreathingController.repeat(reverse: true);
        }
        if (!_leftLeafController.isAnimating) {
          _leftLeafController.repeat();
        }
        if (!_rightLeafController.isAnimating) {
          _rightLeafController.repeat();
        }
        break;

      case ChilluState.listening:
        _stopActiveInteractionControllers();
        if (!_listeningPulseController.isAnimating) {
          _listeningPulseController.repeat();
        }
        if (!_idleBreathingController.isAnimating) {
          _idleBreathingController.repeat(reverse: true);
        }
        if (!_leftLeafController.isAnimating) {
          _leftLeafController.repeat();
        }
        if (!_rightLeafController.isAnimating) {
          _rightLeafController.repeat();
        }
        break;

      case ChilluState.thinking:
        _stopActiveInteractionControllers();
        if (!_thinkingCycleController.isAnimating) {
          _thinkingCycleController.repeat();
        }
        if (!_idleBreathingController.isAnimating) {
          _idleBreathingController.repeat(reverse: true);
        }
        if (!_leftLeafController.isAnimating) {
          _leftLeafController.repeat();
        }
        if (!_rightLeafController.isAnimating) {
          _rightLeafController.repeat();
        }
        break;

      case ChilluState.happy:
        _stopActiveInteractionControllers();
        _happyController.forward(from: 0.0);
        break;

      case ChilluState.excited:
      case ChilluState.recipeFound:
        _stopActiveInteractionControllers();
        _excitedController.forward(from: 0.0);
        break;

      case ChilluState.celebrating:
      case ChilluState.mealLogged:
        _stopActiveInteractionControllers();
        _celebrationController.forward(from: 0.0);
        break;

      case ChilluState.confused:
      case ChilluState.error:
        _stopActiveInteractionControllers();
        _confusedController.forward(from: 0.0);
        break;

      case ChilluState.greeting:
      case ChilluState.itemAdded:
        _stopActiveInteractionControllers();
        _bounceController.forward(from: 0.0);
        break;

      case ChilluState.processing:
        _stopActiveInteractionControllers();
        _idleBreathingController.stop();
        _floatingController.stop();
        if (!_processingFloatController.isAnimating) {
          _processingFloatController.repeat(reverse: true);
        }
        break;

      case ChilluState.sleepy:
        _stopActiveInteractionControllers();
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
    _listeningPulseController.dispose();
    _thinkingCycleController.dispose();
    _attentivePerkController.dispose();
    _attentiveLoopController.dispose();
    _happyController.dispose();
    _excitedController.dispose();
    _confusedController.dispose();
    _celebrationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = widget.disableAnimations ?? (MediaQuery.maybeOf(context)?.disableAnimations ?? false);
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
      // CELEBRATING: Most expressive reaction with doubled celebratory jump amplitude,
      // joyful victory squashes/stretches, exuberant side-to-side triumph sways,
      // and festive victory sparkles!
      return AnimatedBuilder(
        animation: _celebrationController,
        builder: (context, _) {
          final p = _celebrationController.value;
          final double jumpY;
          final double sY;
          final double sX;
          final double rot;

          // 3-stage triumphant jump sequence:
          // 1. Primary huge celebratory leap (0.0 -> 0.42)
          if (p < 0.42) {
            final sub = (p / 0.42).clamp(0.0, 1.0);
            final tEase = 4 * sub * (1 - sub);
            jumpY = -34.0 * tEase; // Doubled triumphant leap!
            sY = 1.0 + (tEase * 0.16); // Upward victory stretch
            sX = 1.0 - (tEase * 0.08);
            rot = math.sin(sub * 2 * math.pi) * 0.085;
          }
          // 2. Secondary joyous victory bounce (0.42 -> 0.74)
          else if (p < 0.74) {
            final sub = ((p - 0.42) / 0.32).clamp(0.0, 1.0);
            final tEase = 4 * sub * (1 - sub);
            jumpY = -18.0 * tEase; // Doubled secondary bounce
            sY = 1.0 + (tEase * 0.10);
            sX = 1.0 - (tEase * 0.05);
            rot = -math.sin(sub * 2 * math.pi) * 0.075;
          }
          // 3. Satisfying follow-through finish with soft landing cushion (0.74 -> 1.0)
          else {
            final sub = ((p - 0.74) / 0.26).clamp(0.0, 1.0);
            if (sub < 0.40) {
              final sub3 = sub / 0.40;
              final tEase = 4 * sub3 * (1 - sub3);
              jumpY = -7.0 * tEase;
              sY = 1.0 + (tEase * 0.04);
              sX = 1.0 - (tEase * 0.02);
            } else {
              // Elastic settling cushion to resting pose
              final settleSub = ((sub - 0.40) / 0.60).clamp(0.0, 1.0);
              final settleSin = math.sin(settleSub * math.pi);
              jumpY = 1.2 * settleSin;
              sY = 1.0 - (settleSin * 0.04);
              sX = 1.0 + (settleSin * 0.03);
            }
            rot = 0.0;
          }

          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Celebratory victory sparkle burst
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _ChilluCelebrationSparklesPainter(progress: p),
              ),
              Transform.translate(
                offset: Offset(0, jumpY),
                child: Transform.rotate(
                  angle: rot,
                  alignment: Alignment.bottomCenter,
                  child: Transform.scale(
                    scaleX: sX,
                    scaleY: sY,
                    alignment: Alignment.bottomCenter,
                    child: Image.asset(
                      ChilluMascot.joyfulJumpAsset,
                      width: widget.size,
                      height: widget.size,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
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
        _listeningPulseController,
        _thinkingCycleController,
        _attentivePerkController,
        _attentiveLoopController,
        _happyController,
        _excitedController,
        _confusedController,
      ]),
      builder: (context, _) {
        double translateY = 0.0;
        double translateX = 0.0;
        double scaleY = 1.0;
        double scaleX = 1.0;
        double rotation = 0.0;

        // 1. Idle & interactive breathing: chest expansion & contraction
        final bool isInteractiveOrIdle = state == ChilluState.idle ||
            state == ChilluState.attentive ||
            state == ChilluState.listening ||
            state == ChilluState.thinking ||
            state == ChilluState.sleepy ||
            state == ChilluState.happy ||
            state == ChilluState.excited ||
            state == ChilluState.recipeFound ||
            state == ChilluState.confused ||
            state == ChilluState.error;

        if (isInteractiveOrIdle) {
          final breathProgress = Curves.easeInOut.transform(_idleBreathingController.value);
          scaleY = 1.0 + (breathProgress * 0.018); // ~1.8% expansion
          scaleX = 1.0 - (breathProgress * 0.010); // ~1.0% contraction
        }

        // 2. Body floating & noticeable state-specific postures
        if (isInteractiveOrIdle) {
          final floatVal = _floatingController.value;
          final floatSin = math.sin(floatVal * 2 * math.pi);

          if (state == ChilluState.idle || state == ChilluState.sleepy) {
            translateY += -2.0 * floatSin;
          } else if (state == ChilluState.attentive) {
            // ATTENTIVE:
            // 1. Initial Curious Perk-Up entrance (p: 0.0 -> 1.0 via _attentivePerkController)
            // 2. Continuous Attentive Animation Loop (loopVal: 0.0 -> 1.0 via _attentiveLoopController)
            final p = _attentivePerkController.value;
            final loopVal = _attentiveLoopController.value;
            final loopBlend = Curves.easeIn.transform(p); // 0.0 at entrance, 1.0 when settled into loop

            // Entrance Perk-Up trajectory:
            final double entranceTranslate;
            final double entranceScaleY;
            final double entranceScaleX;
            final double entranceRot;

            if (p < 0.12) {
              final sub = p / 0.12;
              entranceTranslate = 2.0 * sub;
              entranceScaleY = 1.0 - (0.06 * sub);
              entranceScaleX = 1.0 + (0.05 * sub);
              entranceRot = 0.0;
            } else if (p < 0.35) {
              final sub = (p - 0.12) / 0.23;
              final tEase = Curves.easeOutBack.transform(sub);
              entranceTranslate = 2.0 + ((-11.5 - 2.0) * tEase);
              entranceScaleY = 0.94 + ((1.09 - 0.94) * tEase);
              entranceScaleX = 1.05 + ((0.93 - 1.05) * tEase);
              entranceRot = 0.0;
            } else if (p < 0.70) {
              final sub = (p - 0.35) / 0.35;
              final tEase = Curves.easeInOut.transform(sub);
              entranceTranslate = -11.5 + ((-6.0 - -11.5) * tEase);
              entranceScaleY = 1.09 + ((1.03 - 1.09) * tEase);
              entranceScaleX = 0.93 + ((0.985 - 0.93) * tEase);
              entranceRot = math.sin(sub * math.pi) * 0.040; // Playful entrance tilt
            } else {
              entranceTranslate = -6.0;
              entranceScaleY = 1.03;
              entranceScaleX = 0.985;
              entranceRot = 0.0;
            }

            // Continuous Attentive Loop dynamics:
            // 1. Playful spring-like micro-bounces (period 1200ms -> 6*pi)
            final double springPhase = math.sin(loopVal * 6 * math.pi);
            final double loopTranslate = -6.0 - (springPhase.abs() * 2.4);
            final double loopScaleY = 1.03 + (springPhase * 0.024);
            final double loopScaleX = 0.985 - (springPhase * 0.014);

            // 2. Gentle alternating body tilt & posture shifts (period 1800ms -> 4*pi)
            final double bodyTilt = math.sin(loopVal * 4 * math.pi) * 0.038;
            final double postureShift = math.sin(loopVal * 2 * math.pi) * 0.016;
            final double loopRot = bodyTilt + postureShift;

            // Seamless blend from entrance perk into continuous loop:
            translateY += Tween<double>(begin: entranceTranslate, end: loopTranslate).transform(loopBlend);
            scaleY = Tween<double>(begin: entranceScaleY, end: loopScaleY).transform(loopBlend);
            scaleX = Tween<double>(begin: entranceScaleX, end: loopScaleX).transform(loopBlend);
            rotation = Tween<double>(begin: entranceRot, end: loopRot).transform(loopBlend);
          } else if (state == ChilluState.happy) {
            // HAPPY (2x Intensity): Cheerful body bounce (-24px), warm squash & stretch, joyful sway, and soft settling cushion
            final p = _happyController.value;
            final double bounce;
            final double sY;
            final double sX;
            if (p < 0.42) {
              final sub = (p / 0.42).clamp(0.0, 1.0);
              final tEase = 4 * sub * (1 - sub);
              bounce = -24.0 * tEase; // Doubled from -12.0
              sY = 1.0 + (tEase * 0.12); // Doubled squash/stretch from 0.06
              sX = 1.0 - (tEase * 0.06);
            } else if (p < 0.72) {
              final sub = ((p - 0.42) / 0.30).clamp(0.0, 1.0);
              final tEase = 4 * sub * (1 - sub);
              bounce = -8.0 * tEase; // Doubled from -4.0
              sY = 1.0 + (tEase * 0.05);
              sX = 1.0 - (tEase * 0.03);
            } else {
              // Stronger, satisfying settling cushion
              final sub = ((p - 0.72) / 0.28).clamp(0.0, 1.0);
              final settleSin = math.sin(sub * math.pi);
              bounce = 1.8 * settleSin;
              sY = 1.0 - (settleSin * 0.035);
              sX = 1.0 + (settleSin * 0.025);
            }
            translateY += bounce;
            scaleY = sY;
            scaleX = sX;
            rotation = math.sin(p * 2 * math.pi) * 0.070; // Doubled from 0.035
          } else if (state == ChilluState.excited || state == ChilluState.recipeFound) {
            // EXCITED (2x Intensity): Visibly stronger & highly energetic!
            // High energetic upward jump (-38px) with lively secondary hop (-18px),
            // pronounced squash-and-stretch, and energetic body sway
            final p = _excitedController.value;
            final double jump;
            final double sY;
            final double sX;
            if (p < 0.44) {
              final sub = (p / 0.44).clamp(0.0, 1.0);
              final tEase = 4 * sub * (1 - sub);
              jump = -38.0 * tEase; // Doubled from -20.0
              sY = 1.0 + (tEase * 0.18); // Doubled from 0.10
              sX = 1.0 - (tEase * 0.09);
            } else if (p < 0.74) {
              final sub = ((p - 0.44) / 0.30).clamp(0.0, 1.0);
              final tEase = 4 * sub * (1 - sub);
              jump = -18.0 * tEase; // Doubled from -9.0
              sY = 1.0 + (tEase * 0.09);
              sX = 1.0 - (tEase * 0.045);
            } else {
              // Elastic settling cushion
              final sub = ((p - 0.74) / 0.26).clamp(0.0, 1.0);
              final settleSin = math.sin(sub * math.pi);
              jump = 2.0 * settleSin;
              sY = 1.0 - (settleSin * 0.045);
              sX = 1.0 + (settleSin * 0.035);
            }
            translateY += jump;
            scaleY = sY;
            scaleX = sX;
            rotation = math.sin(p * 4 * math.pi) * 0.110; // Doubled from 0.055
          } else if (state == ChilluState.confused || state == ChilluState.error) {
            // CONFUSED (2x Intensity): Noticeable questioning sideways head tilt (~16.0 deg / +0.28 rad),
            // clearly visible lateral lean, curious puzzled body sway, inquisitive questioning posture
            final p = _confusedController.value;
            final double tilt;
            final double sway;
            final double lateralLean;
            if (p < 0.30) {
              final sub = (p / 0.30).clamp(0.0, 1.0);
              tilt = Curves.easeOutBack.transform(sub) * 0.28; // Doubled from 0.15 (+16 deg)
              sway = 0.0;
              lateralLean = Curves.easeOut.transform(sub) * 3.5;
            } else if (p < 0.75) {
              final sub = (p - 0.30) / 0.45;
              tilt = 0.28;
              sway = math.sin(sub * 3 * math.pi) * 0.070; // Doubled from 0.035
              lateralLean = 3.5 + (math.sin(sub * 2 * math.pi) * 2.5);
            } else {
              final sub = ((p - 0.75) / 0.25).clamp(0.0, 1.0);
              tilt = Tween<double>(begin: 0.28, end: 0.0).transform(Curves.easeInOut.transform(sub));
              sway = 0.0;
              lateralLean = Tween<double>(begin: 3.5, end: 0.0).transform(Curves.easeInOut.transform(sub));
            }
            rotation = tilt + sway;
            translateX += lateralLean;
            translateY += 2.0;
          } else if (state == ChilluState.listening) {
            // Listening: rhythmic body bounce (1000ms cycle), visible breathing/pulsing (4.2% scale),
            // attentive side ear tilt (~-4.3 deg)
            final pulseVal = _listeningPulseController.value;
            final bounceHop = math.sin(pulseVal * math.pi);
            translateY += -7.5 * bounceHop; // 7.5px visible bounce
            final pulseScale = math.sin(pulseVal * 2 * math.pi);
            scaleY += pulseScale * 0.042; // visible 4.2% pulse
            scaleX -= pulseScale * 0.020;
            rotation = -0.075 + (bounceHop * 0.025); // ~-4.3 deg listening ear tilt
          } else if (state == ChilluState.thinking) {
            // Thinking: body tilts alternating between left and right with natural pauses (2400ms cycle),
            // upward floating (-8.5px), and contemplative eyelid gaze
            final cycle = _thinkingCycleController.value;
            final double thinkAngle;
            if (cycle < 0.35) {
              // 0.0 -> 0.35: smooth swing to left (-6.3 deg / -0.110 rad)
              final t = Curves.easeInOut.transform(cycle / 0.35);
              thinkAngle = Tween<double>(begin: 0.110, end: -0.110).transform(t);
            } else if (cycle < 0.50) {
              // 0.35 -> 0.50: pause on left
              thinkAngle = -0.110;
            } else if (cycle < 0.85) {
              // 0.50 -> 0.85: smooth swing to right (+6.3 deg / +0.110 rad)
              final t = Curves.easeInOut.transform((cycle - 0.50) / 0.35);
              thinkAngle = Tween<double>(begin: -0.110, end: 0.110).transform(t);
            } else {
              // 0.85 -> 1.00: pause on right
              thinkAngle = 0.110;
            }
            rotation = thinkAngle;
            final thinkFloat = math.sin(cycle * 2 * math.pi);
            translateY += -8.5 + (thinkFloat * 1.5);
            scaleY += 0.020 + (thinkFloat * 0.012);
          }
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

        // 5. Tilt effect (error / generic tilt)
        if (_tiltController.value > 0.0 && state != ChilluState.attentive && state != ChilluState.listening && state != ChilluState.thinking) {
          final tVal = _tiltController.value;
          if (state == ChilluState.error) {
            rotation = math.sin(tVal * math.pi * 3) * 0.08;
            translateY += 2.0;
          } else {
            rotation = tVal * 0.08;
          }
        }

        // 6. Independent leaf sprout sway calculation
        final bool isLayeredState = isInteractiveOrIdle;
        final double leftLeafAngle;
        final double rightLeafAngle;
        if (isLayeredState) {
          final lVal = _leftLeafController.value;
          final rVal = _rightLeafController.value;
          double lAngle = math.sin(lVal * 2 * math.pi) * 0.020;
          double rAngle = math.sin(rVal * 2 * math.pi) * -0.016;

          if (state == ChilluState.attentive) {
            final p = _attentivePerkController.value;
            final loopVal = _attentiveLoopController.value;
            final loopBlend = Curves.easeIn.transform(p);

            // Entrance leaf reaction:
            final double entLeft;
            final double entRight;

            // Left leaf peaks at p = 0.30
            if (p < 0.30) {
              final sub = (p / 0.30).clamp(0.0, 1.0);
              entLeft = Curves.easeOutBack.transform(sub) * 0.11; // ~6.3 deg
            } else if (p < 0.60) {
              final sub = ((p - 0.30) / 0.30).clamp(0.0, 1.0);
              entLeft = Tween<double>(begin: 0.11, end: 0.045).transform(Curves.easeInOut.transform(sub));
            } else {
              entLeft = 0.045; // Resting alert perk
            }

            // Right leaf slightly delayed, peaks at p = 0.38
            if (p < 0.08) {
              entRight = 0.0;
            } else if (p < 0.38) {
              final sub = ((p - 0.08) / 0.30).clamp(0.0, 1.0);
              entRight = -Curves.easeOutBack.transform(sub) * 0.10; // ~-5.7 deg
            } else if (p < 0.65) {
              final sub = ((p - 0.38) / 0.27).clamp(0.0, 1.0);
              entRight = Tween<double>(begin: -0.10, end: -0.038).transform(Curves.easeInOut.transform(sub));
            } else {
              entRight = -0.038; // Resting alert perk
            }

            // Continuous loop leaf swaying (different independent periods & phase offsets):
            // Left sprout sway (frequency: 5*pi) + spring coupling
            final double loopLeft = 0.045 + (math.sin(loopVal * 5 * math.pi) * 0.034) + (math.sin(loopVal * 6 * math.pi) * 0.012);
            // Right sprout sway (frequency: 3.5*pi + 1.2 offset) - spring coupling
            final double loopRight = -0.038 + (math.sin(loopVal * 3.5 * math.pi + 1.2) * 0.030) - (math.sin(loopVal * 6 * math.pi) * 0.012);

            lAngle += Tween<double>(begin: entLeft, end: loopLeft).transform(loopBlend);
            rAngle += Tween<double>(begin: entRight, end: loopRight).transform(loopBlend);
          } else if (state == ChilluState.happy) {
            // Happy (2x Intensity): both leaves perk up cheerfully and sway with doubled spring
            final p = _happyController.value;
            final bounceSway = math.sin(p * math.pi);
            lAngle += 0.130 * bounceSway; // Doubled from 0.065
            rAngle -= 0.110 * bounceSway; // Doubled from 0.055
          } else if (state == ChilluState.excited || state == ChilluState.recipeFound) {
            // Excited (2x Intensity): both leaves bounce independently with lively energetic flutter
            final p = _excitedController.value;
            final flutter = math.sin(p * 7 * math.pi);
            lAngle += 0.220 + (flutter * 0.090); // Doubled from 0.11 + 0.045
            rAngle -= 0.200 - (flutter * 0.090); // Doubled from 0.10 - 0.045
          } else if (state == ChilluState.confused || state == ChilluState.error) {
            // Confused (2x Intensity): Asymmetrical leaf tilt! Left leaf perks up high, right leaf droops puzzled
            final p = _confusedController.value;
            final progress = (p < 0.30)
                ? Curves.easeOut.transform(p / 0.30)
                : (p > 0.75)
                    ? (1.0 - Curves.easeInOut.transform((p - 0.75) / 0.25))
                    : 1.0;
            lAngle += 0.180 * progress;  // Doubled from 0.080 (~10.3 deg perk up)
            rAngle -= 0.240 * progress;  // Doubled from 0.120 (~-13.8 deg droop down)
          } else if (state == ChilluState.listening) {
            // Leaves respond dynamically to rhythmic bounce
            final bouncePhase = math.sin(_listeningPulseController.value * 2 * math.pi);
            lAngle += bouncePhase * 0.050; // ~2.9 deg responsive leaf wave
            rAngle -= bouncePhase * 0.042;
          } else if (state == ChilluState.thinking) {
            // Leaves rustle gently matching the body tilt direction
            final cycle = _thinkingCycleController.value;
            final thinkSway = math.sin(cycle * 2 * math.pi);
            lAngle += (rotation * 0.35) + (thinkSway * 0.025);
            rAngle += (rotation * 0.35) - (thinkSway * 0.020);
          }
          leftLeafAngle = lAngle;
          rightLeafAngle = rAngle;
        } else {
          leftLeafAngle = 0.0;
          rightLeafAngle = 0.0;
        }

        // 7. Emotional Eye Expressions (Happy, Excited, Confused, Attentive)
        final double happyEyeProgress = state == ChilluState.happy
            ? math.sin(_happyController.value * math.pi)
            : 0.0;
        final double excitedEyeProgress = (state == ChilluState.excited || state == ChilluState.recipeFound)
            ? math.sin(_excitedController.value * math.pi)
            : 0.0;
        final double confusedEyeProgress = (state == ChilluState.confused || state == ChilluState.error)
            ? ((_confusedController.value < 0.30)
                ? (_confusedController.value / 0.30)
                : (_confusedController.value > 0.75)
                    ? (1.0 - ((_confusedController.value - 0.75) / 0.25))
                    : 1.0)
            : 0.0;

        // Curious eye expression and side glance during Attentive
        final double eyeWiden;
        final double glanceShift;
        if (state == ChilluState.attentive) {
          final p = _attentivePerkController.value;
          final loopVal = _attentiveLoopController.value;

          if (p < 0.95) {
            // Entrance expression:
            // Widening during spring pop (p: 0.12 -> 0.38)
            if (p >= 0.12 && p <= 0.38) {
              final sub = (p - 0.12) / 0.26;
              eyeWiden = math.sin(sub * math.pi);
            } else {
              eyeWiden = 0.0;
            }
            // Entrance side glance (p: 0.42 -> 0.74)
            if (p >= 0.42 && p <= 0.74) {
              final sub = (p - 0.42) / 0.32;
              glanceShift = math.sin(sub * math.pi); // 0.0 -> 1.0 -> 0.0
            } else {
              glanceShift = 0.0;
            }
          } else {
            // Continuous loop occasional expressive eye movements:
            // 1. Inquisitive side glance toward chat (loopVal: 0.15 -> 0.28)
            if (loopVal >= 0.15 && loopVal <= 0.28) {
              final sub = (loopVal - 0.15) / 0.13;
              glanceShift = math.sin(sub * math.pi) * 0.85;
            } else {
              glanceShift = 0.0;
            }

            // 2. Alert curious eyebrow lift / eye widening (loopVal: 0.62 -> 0.75)
            if (loopVal >= 0.62 && loopVal <= 0.75) {
              final sub = (loopVal - 0.62) / 0.13;
              eyeWiden = math.sin(sub * math.pi) * 0.80;
            } else {
              eyeWiden = 0.0;
            }
          }
        } else {
          eyeWiden = 0.0;
          glanceShift = 0.0;
        }

        // 8. Eye blinking & pensive gaze focus
        final double gazeEyelid;
        if (state == ChilluState.thinking) {
          final cycle = _thinkingCycleController.value;
          gazeEyelid = (0.16 + (math.sin(cycle * 2 * math.pi) * 0.03)).clamp(0.0, 0.22);
        } else {
          gazeEyelid = 0.0;
        }
        final double effectiveBlinkProgress = math.max(_blinkController.value, gazeEyelid);

        return Transform.translate(
          offset: Offset(translateX, translateY),
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
                    // Subtle audio-wave pulse indicator during listening state
                    if (state == ChilluState.listening)
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _ChilluAudioWavePainter(
                            progress: _listeningPulseController.value,
                          ),
                        ),
                      ),

                    if (!isLayeredState)
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

                    // 4. Natural Eye Blinking & Pensive Gaze Overlay
                    if (effectiveBlinkProgress > 0.0)
                      CustomPaint(
                        size: Size(widget.size, widget.size),
                        painter: _ChilluEyeBlinkPainter(
                          blinkProgress: effectiveBlinkProgress,
                        ),
                      ),

                    // 5. Emotional Eyes & Gaze Overlay (Happy, Excited, Confused, and Attentive)
                    if (happyEyeProgress > 0.0 ||
                        excitedEyeProgress > 0.0 ||
                        confusedEyeProgress > 0.0 ||
                        eyeWiden > 0.0 ||
                        glanceShift > 0.0)
                      CustomPaint(
                        size: Size(widget.size, widget.size),
                        painter: _ChilluEmotionalEyesPainter(
                          happyProgress: happyEyeProgress,
                          excitedProgress: excitedEyeProgress,
                          confusedProgress: confusedEyeProgress,
                          widenProgress: eyeWiden,
                          glanceProgress: glanceShift,
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
        _tiltController,
        _listeningPulseController,
        _thinkingCycleController,
        _attentivePerkController,
        _attentiveLoopController,
        _happyController,
        _excitedController,
        _confusedController,
        _celebrationController,
      ]),
      builder: (context, _) {
        double shadowScale = 1.0;
        double shadowOpacity = 0.12;

        if (state == ChilluState.processing) {
          final fVal = _processingFloatController.value;
          shadowScale = 0.85 + (0.15 * (1.0 - fVal));
          shadowOpacity = 0.08 + (0.04 * (1.0 - fVal));
        } else if ((state == ChilluState.celebrating || state == ChilluState.mealLogged) && _celebrationController.isAnimating) {
          final cVal = _celebrationController.value;
          double hop = 0.0;
          if (cVal < 0.42) {
            final sub = (cVal / 0.42).clamp(0.0, 1.0);
            hop = 4 * sub * (1 - sub);
          } else if (cVal < 0.74) {
            final sub = ((cVal - 0.42) / 0.32).clamp(0.0, 1.0);
            hop = 4 * sub * (1 - sub) * 0.65;
          }
          shadowScale = (1.0 - (0.45 * hop)).clamp(0.40, 1.0);
          shadowOpacity = (0.12 - (0.08 * hop)).clamp(0.03, 0.12);
        } else if (state == ChilluState.happy && _happyController.isAnimating) {
          final hVal = _happyController.value;
          final hop = 4 * hVal * (1 - hVal);
          shadowScale = (1.0 - (0.32 * hop)).clamp(0.55, 1.0);
          shadowOpacity = (0.12 - (0.06 * hop)).clamp(0.04, 0.12);
        } else if ((state == ChilluState.excited || state == ChilluState.recipeFound) && _excitedController.isAnimating) {
          final eVal = _excitedController.value;
          final jumpPhase = (eVal / 0.74).clamp(0.0, 1.0);
          final hop = 4 * jumpPhase * (1 - jumpPhase);
          shadowScale = (1.0 - (0.45 * hop)).clamp(0.40, 1.0);
          shadowOpacity = (0.12 - (0.09 * hop)).clamp(0.03, 0.12);
        } else if ((state == ChilluState.confused || state == ChilluState.error) && _confusedController.isAnimating) {
          shadowScale = 0.94;
          shadowOpacity = 0.10;
        } else if (_bounceController.isAnimating) {
          final bVal = _bounceController.value;
          final hop = 4 * bVal * (1 - bVal);
          shadowScale = 1.0 - (0.35 * hop);
          shadowOpacity = 0.12 - (0.06 * hop);
        } else if (state == ChilluState.attentive) {
          // Attentive: dynamic shadow reacting to entrance pop and continuous loop spring bounces
          final p = _attentivePerkController.value;
          final loopVal = _attentiveLoopController.value;
          if (p < 0.35) {
            final sub = (p / 0.35).clamp(0.0, 1.0);
            shadowScale = 1.0 - (0.14 * Curves.easeOutBack.transform(sub));
            shadowOpacity = 0.11 - (0.03 * Curves.easeOutBack.transform(sub));
          } else {
            // Tracks continuous loop spring bounce
            final springPhase = math.sin(loopVal * 6 * math.pi).abs();
            shadowScale = 0.92 - (0.05 * springPhase);
            shadowOpacity = 0.10 - (0.02 * springPhase);
          }
        } else if (state == ChilluState.listening) {
          // Listening: rhythmic bounce ~7.5px with _listeningPulseController
          final listenPulse = math.sin(_listeningPulseController.value * math.pi);
          shadowScale = 0.94 - (0.12 * listenPulse);
          shadowOpacity = 0.11 - (0.04 * listenPulse);
        } else if (state == ChilluState.thinking) {
          // Thinking: elevated contemplative float ~8.5px
          final thinkVal = _thinkingCycleController.value;
          final thinkFloat = (math.sin(thinkVal * 2 * math.pi) + 1.0) * 0.5;
          shadowScale = 0.88 - (0.05 * thinkFloat);
          shadowOpacity = 0.09 - (0.02 * thinkFloat);
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
      case ChilluState.attentive:
        return 'attentive and focused';
      case ChilluState.listening:
        return 'listening to your voice';
      case ChilluState.greeting:
        return 'waving hello';
      case ChilluState.thinking:
        return 'thinking';
      case ChilluState.processing:
        return 'searching for recipes';
      case ChilluState.happy:
        return 'happy and cheerful';
      case ChilluState.excited:
        return 'excited, delicious ideas found!';
      case ChilluState.celebrating:
        return 'celebrating!';
      case ChilluState.confused:
        return 'curious and puzzled';
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

/// Renders subtle concentric audio-wave pulses around Chillu during voice listening.
class _ChilluAudioWavePainter extends CustomPainter {
  final double progress;

  const _ChilluAudioWavePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress < 0.0 || progress > 1.0) return;

    final center = Offset(size.width * 0.50, size.height * 0.54);
    final baseRadius = size.width * 0.44;
    final maxExpansion = size.width * 0.18;

    // Two expanding pulse rings offset by 0.5 phase
    for (int i = 0; i < 2; i++) {
      final ringProgress = (progress + (i * 0.5)) % 1.0;
      final currentRadius = baseRadius + (ringProgress * maxExpansion);
      // Soft fade from 0.28 to 0.0 as the wave radiates outward
      final opacity = ((1.0 - ringProgress) * 0.28).clamp(0.0, 1.0);

      final wavePaint = Paint()
        ..color = const Color(0xFF53C79C).withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.8, size.width * 0.022);

      canvas.drawCircle(center, currentRadius, wavePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ChilluAudioWavePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Renders dynamic emotional eye expressions (Happy smiling arcs, Excited sparkles,
/// Confused quizzical brows, and Attentive widening/glance).
class _ChilluEmotionalEyesPainter extends CustomPainter {
  final double happyProgress; // 0.0 to 1.0 (smiling curved eye creases)
  final double excitedProgress; // 0.0 to 1.0 (enlarged star sparkle catchlights & high lifted brows)
  final double confusedProgress; // 0.0 to 1.0 (asymmetrical quizzical cocked eyebrows & curious gaze)
  final double widenProgress; // 0.0 to 1.0 (alert attentive widening)
  final double glanceProgress; // 0.0 to 1.0 (attentive sideways glance)

  const _ChilluEmotionalEyesPainter({
    this.happyProgress = 0.0,
    this.excitedProgress = 0.0,
    this.confusedProgress = 0.0,
    this.widenProgress = 0.0,
    this.glanceProgress = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (happyProgress <= 0.0 &&
        excitedProgress <= 0.0 &&
        confusedProgress <= 0.0 &&
        widenProgress <= 0.0 &&
        glanceProgress <= 0.0) {
      return;
    }

    final eyeWidth = size.width * 0.20;
    final eyeHeight = size.height * 0.23;

    final leftCenter = Offset(size.width * 0.3664, size.height * 0.4781);
    final rightCenter = Offset(size.width * 0.6336, size.height * 0.4781);

    // 1. HAPPY: Warm smiling eye crescents (^ ^) with cheerful lifted brows and rosy cheek warmth
    if (happyProgress > 0.0) {
      final happyAlpha = happyProgress.clamp(0.0, 1.0);
      final mintFur = Paint()
        ..color = const Color(0xFF53C79C).withValues(alpha: happyAlpha)
        ..style = PaintingStyle.fill;

      final smileLashPaint = Paint()
        ..color = const Color(0xFF1B4332).withValues(alpha: happyAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2.4, eyeWidth * 0.14)
        ..strokeCap = StrokeCap.round;

      final blushPaint = Paint()
        ..color = const Color(0xFFFF8B94).withValues(alpha: happyAlpha * 0.38)
        ..style = PaintingStyle.fill;

      for (final center in [leftCenter, rightCenter]) {
        final eyeRect = Rect.fromCenter(center: center, width: eyeWidth, height: eyeHeight);
        canvas.save();
        canvas.clipPath(Path()..addOval(eyeRect));

        // Soft mint fill concealing the open eye
        canvas.drawOval(eyeRect, mintFur);

        // Cheerful curved smiling arc (^)
        final smilePath = Path();
        final start = Offset(center.dx - (eyeWidth * 0.38), center.dy + (eyeHeight * 0.08));
        final peak = Offset(center.dx, center.dy - (eyeHeight * 0.22));
        final end = Offset(center.dx + (eyeWidth * 0.38), center.dy + (eyeHeight * 0.08));
        smilePath.moveTo(start.dx, start.dy);
        smilePath.quadraticBezierTo(peak.dx, peak.dy, end.dx, end.dy);
        canvas.drawPath(smilePath, smileLashPaint);

        canvas.restore();

        // Rosy cheek glow
        canvas.drawCircle(Offset(center.dx, center.dy + (eyeHeight * 0.58)), eyeWidth * 0.28, blushPaint);

        // Cheerful lifted eyebrows (raised higher with 2x intensity)
        final browPath = Path();
        final bStart = Offset(center.dx - (eyeWidth * 0.34), center.dy - (eyeHeight * 0.64) - (eyeHeight * 0.18 * happyAlpha));
        final bPeak = Offset(center.dx, center.dy - (eyeHeight * 0.82) - (eyeHeight * 0.22 * happyAlpha));
        final bEnd = Offset(center.dx + (eyeWidth * 0.34), center.dy - (eyeHeight * 0.64) - (eyeHeight * 0.18 * happyAlpha));
        browPath.moveTo(bStart.dx, bStart.dy);
        browPath.quadraticBezierTo(bPeak.dx, bPeak.dy, bEnd.dx, bEnd.dy);
        canvas.drawPath(browPath, smileLashPaint);
      }
    }

    // 2. EXCITED: Highly energetic gleaming eyes, doubled sparkle catchlights, and lifted brows
    if (excitedProgress > 0.0) {
      final excitedAlpha = excitedProgress.clamp(0.0, 1.0);
      final browPaint = Paint()
        ..color = const Color(0xFF1B4332).withValues(alpha: excitedAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2.0, size.width * 0.024)
        ..strokeCap = StrokeCap.round;

      final sparklePaint = Paint()
        ..color = Colors.white.withValues(alpha: excitedAlpha * 0.95)
        ..style = PaintingStyle.fill;

      final shimmerPaint = Paint()
        ..color = const Color(0xFFE8F5E9).withValues(alpha: excitedAlpha * 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.8, size.width * 0.018)
        ..strokeCap = StrokeCap.round;

      for (final center in [leftCenter, rightCenter]) {
        // High enthusiastic eyebrows (doubled lift from 0.18 to 0.32)
        final browLift = eyeHeight * 0.32 * excitedAlpha;
        final browPath = Path();
        final start = Offset(center.dx - (eyeWidth * 0.34), center.dy - (eyeHeight * 0.62) - browLift);
        final peak = Offset(center.dx, center.dy - (eyeHeight * 0.82) - browLift);
        final end = Offset(center.dx + (eyeWidth * 0.34), center.dy - (eyeHeight * 0.62) - browLift);
        browPath.moveTo(start.dx, start.dy);
        browPath.quadraticBezierTo(peak.dx, peak.dy, end.dx, end.dy);
        canvas.drawPath(browPath, browPaint);

        // Enlarged gleam catchlights (bright sparkle burst in the upper pupil)
        final c1 = Offset(center.dx - (eyeWidth * 0.08), center.dy - (eyeHeight * 0.10));
        final starRadius = eyeWidth * 0.22; // Doubled gleam radius
        canvas.drawCircle(c1, starRadius, sparklePaint);

        // 4-point sparkle cross shimmer with doubled reach
        canvas.drawLine(Offset(c1.dx - (starRadius * 2.2), c1.dy), Offset(c1.dx + (starRadius * 2.2), c1.dy), shimmerPaint);
        canvas.drawLine(Offset(c1.dx, c1.dy - (starRadius * 2.2)), Offset(c1.dx, c1.dy + (starRadius * 2.2)), shimmerPaint);

        // Secondary playful glint
        canvas.drawCircle(
          Offset(center.dx + (eyeWidth * 0.16), center.dy + (eyeHeight * 0.14)),
          eyeWidth * 0.10,
          sparklePaint,
        );
        // Tertiary sparkle
        canvas.drawCircle(
          Offset(center.dx - (eyeWidth * 0.12), center.dy + (eyeHeight * 0.16)),
          eyeWidth * 0.06,
          sparklePaint,
        );
      }
    }

    // 3. CONFUSED: Asymmetrical quizzical eyebrows (left cocked high in curiosity, right furrowed flat) & questioning gaze
    if (confusedProgress > 0.0) {
      final confAlpha = confusedProgress.clamp(0.0, 1.0);
      final browPaint = Paint()
        ..color = const Color(0xFF1B4332).withValues(alpha: confAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2.0, size.width * 0.024)
        ..strokeCap = StrokeCap.round;

      // Questioning gaze: pupils drift inquisitively towards the upper-side
      final pupilShiftX = eyeWidth * 0.10 * confAlpha;
      final pupilShiftY = -eyeHeight * 0.08 * confAlpha;
      final pupilPaint = Paint()
        ..color = Colors.black.withValues(alpha: confAlpha * 0.90)
        ..style = PaintingStyle.fill;

      for (final center in [leftCenter, rightCenter]) {
        final eyeRect = Rect.fromCenter(center: center, width: eyeWidth, height: eyeHeight);
        canvas.save();
        canvas.clipPath(Path()..addOval(eyeRect));

        final shifted = Offset(center.dx + pupilShiftX, center.dy + pupilShiftY);
        canvas.drawCircle(shifted, eyeWidth * 0.30, pupilPaint);

        final irisPaint = Paint()
          ..color = const Color(0xFF00C9A7).withValues(alpha: confAlpha * 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.4, eyeWidth * 0.12);
        canvas.drawArc(
          Rect.fromCircle(center: shifted, radius: eyeWidth * 0.30),
          -math.pi * 0.4,
          math.pi * 0.8,
          false,
          irisPaint,
        );

        final clPaint = Paint()
          ..color = Colors.white.withValues(alpha: confAlpha * 0.9)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(shifted.dx - (eyeWidth * 0.08), shifted.dy - (eyeHeight * 0.10)), eyeWidth * 0.10, clPaint);

        canvas.restore();
      }

      // Left Eyebrow: Inquisitively cocked high up (doubled lift from 0.22 to 0.40)
      final leftLift = eyeHeight * 0.40 * confAlpha;
      final leftBrowPath = Path();
      final lStart = Offset(leftCenter.dx - (eyeWidth * 0.32), leftCenter.dy - (eyeHeight * 0.58) - leftLift);
      final lPeak = Offset(leftCenter.dx - (eyeWidth * 0.05), leftCenter.dy - (eyeHeight * 0.94) - leftLift);
      final lEnd = Offset(leftCenter.dx + (eyeWidth * 0.34), leftCenter.dy - (eyeHeight * 0.54) - (leftLift * 0.4));
      leftBrowPath.moveTo(lStart.dx, lStart.dy);
      leftBrowPath.quadraticBezierTo(lPeak.dx, lPeak.dy, lEnd.dx, lEnd.dy);
      canvas.drawPath(leftBrowPath, browPaint);

      // Right Eyebrow: Puzzled, lowered flat/slightly angled down (doubled drop from 0.06 to 0.12)
      final rightDrop = eyeHeight * 0.12 * confAlpha;
      final rightBrowPath = Path();
      final rStart = Offset(rightCenter.dx - (eyeWidth * 0.34), rightCenter.dy - (eyeHeight * 0.54) + rightDrop);
      final rPeak = Offset(rightCenter.dx, rightCenter.dy - (eyeHeight * 0.62) + rightDrop);
      final rEnd = Offset(rightCenter.dx + (eyeWidth * 0.32), rightCenter.dy - (eyeHeight * 0.66) + rightDrop);
      rightBrowPath.moveTo(rStart.dx, rStart.dy);
      rightBrowPath.quadraticBezierTo(rPeak.dx, rPeak.dy, rEnd.dx, rEnd.dy);
      canvas.drawPath(rightBrowPath, browPaint);
    }

    // 4. ATTENTIVE: Raised curious eyebrows during entrance perk-up
    if (widenProgress > 0.05 && happyProgress <= 0.0 && excitedProgress <= 0.0 && confusedProgress <= 0.0) {
      final browPaint = Paint()
        ..color = const Color(0xFF1B4332).withValues(alpha: (widenProgress * 0.85).clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.8, size.width * 0.022)
        ..strokeCap = StrokeCap.round;

      final browLift = eyeHeight * 0.12 * widenProgress;

      for (final center in [leftCenter, rightCenter]) {
        final browPath = Path();
        final start = Offset(center.dx - (eyeWidth * 0.32), center.dy - (eyeHeight * 0.60) - browLift);
        final peak = Offset(center.dx, center.dy - (eyeHeight * 0.72) - browLift);
        final end = Offset(center.dx + (eyeWidth * 0.32), center.dy - (eyeHeight * 0.60) - browLift);
        browPath.moveTo(start.dx, start.dy);
        browPath.quadraticBezierTo(peak.dx, peak.dy, end.dx, end.dy);
        canvas.drawPath(browPath, browPaint);
      }
    }

    // 5. ATTENTIVE: Playful sideways glance (pupils shift right toward conversation)
    if (glanceProgress > 0.05 && happyProgress <= 0.0) {
      final shiftX = eyeWidth * 0.13 * glanceProgress;
      final glanceAlpha = (glanceProgress * 0.95).clamp(0.0, 1.0);

      for (final center in [leftCenter, rightCenter]) {
        final eyeRect = Rect.fromCenter(center: center, width: eyeWidth, height: eyeHeight);
        canvas.save();
        canvas.clipPath(Path()..addOval(eyeRect));

        // Dark pupil shifted right
        final shiftedCenter = Offset(center.dx + shiftX, center.dy);
        final pupilPaint = Paint()
          ..color = Colors.black.withValues(alpha: glanceAlpha)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(shiftedCenter, eyeWidth * 0.32, pupilPaint);

        // Teal iris arc ring on right edge of shifted pupil
        final irisPaint = Paint()
          ..color = const Color(0xFF00C9A7).withValues(alpha: glanceAlpha * 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.4, eyeWidth * 0.12);
        canvas.drawArc(
          Rect.fromCircle(center: shiftedCenter, radius: eyeWidth * 0.32),
          -math.pi * 0.35,
          math.pi * 0.70,
          false,
          irisPaint,
        );

        // Glossy catchlights
        final catchlightPaint = Paint()
          ..color = Colors.white.withValues(alpha: glanceAlpha * 0.9)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
          Offset(shiftedCenter.dx - (eyeWidth * 0.10), shiftedCenter.dy - (eyeHeight * 0.12)),
          eyeWidth * 0.11,
          catchlightPaint,
        );
        canvas.drawCircle(
          Offset(shiftedCenter.dx + (eyeWidth * 0.12), shiftedCenter.dy + (eyeHeight * 0.12)),
          eyeWidth * 0.06,
          catchlightPaint,
        );

        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ChilluEmotionalEyesPainter oldDelegate) {
    return oldDelegate.happyProgress != happyProgress ||
        oldDelegate.excitedProgress != excitedProgress ||
        oldDelegate.confusedProgress != confusedProgress ||
        oldDelegate.widenProgress != widenProgress ||
        oldDelegate.glanceProgress != glanceProgress;
  }
}

/// Renders festive celebratory sparkle bursts around Chillu during the celebration jump.
class _ChilluCelebrationSparklesPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0

  const _ChilluCelebrationSparklesPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;

    final center = Offset(size.width * 0.5, size.height * 0.45);
    final baseRadius = size.width * 0.48;

    // Sparkle burst phases: burst 1 (p: 0.06 -> 0.46), burst 2 (p: 0.44 -> 0.84)
    final double burst1 = (progress >= 0.06 && progress <= 0.46)
        ? math.sin(((progress - 0.06) / 0.40) * math.pi)
        : 0.0;
    final double burst2 = (progress >= 0.44 && progress <= 0.84)
        ? math.sin(((progress - 0.44) / 0.40) * math.pi)
        : 0.0;

    final goldPaint = Paint()..style = PaintingStyle.fill;
    final mintPaint = Paint()..style = PaintingStyle.fill;
    final shimmerPaint = Paint()..style = PaintingStyle.fill;

    // Angles for sparkle stars around upper hemisphere
    final angles = [
      -math.pi * 0.85,
      -math.pi * 0.65,
      -math.pi * 0.45,
      -math.pi * 0.25,
      -math.pi * 0.10,
      -math.pi * 0.95,
      -math.pi * 0.50,
      -math.pi * 0.15,
    ];

    for (int i = 0; i < angles.length; i++) {
      final angle = angles[i];
      final isBurst1 = i < 4;
      final alpha = isBurst1 ? burst1 : burst2;
      if (alpha <= 0.01) continue;

      final dist = baseRadius * (0.85 + (0.25 * (1.0 - alpha)));
      final pos = Offset(center.dx + math.cos(angle) * dist, center.dy + math.sin(angle) * dist);
      final radius = math.max(1.8, size.width * (0.035 + (0.015 * (i % 2)))) * alpha;

      final paint = (i % 3 == 0)
          ? (goldPaint..color = const Color(0xFFFFD166).withValues(alpha: alpha * 0.9))
          : (i % 3 == 1)
              ? (mintPaint..color = const Color(0xFF06D6A0).withValues(alpha: alpha * 0.85))
              : (shimmerPaint..color = Colors.white.withValues(alpha: alpha * 0.95));

      // Draw 4-point star sparkle
      final starPath = Path();
      starPath.moveTo(pos.dx, pos.dy - (radius * 1.6));
      starPath.quadraticBezierTo(pos.dx, pos.dy, pos.dx + (radius * 1.6), pos.dy);
      starPath.quadraticBezierTo(pos.dx, pos.dy, pos.dx, pos.dy + (radius * 1.6));
      starPath.quadraticBezierTo(pos.dx, pos.dy, pos.dx - (radius * 1.6), pos.dy);
      starPath.quadraticBezierTo(pos.dx, pos.dy, pos.dx, pos.dy - (radius * 1.6));
      canvas.drawPath(starPath, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ChilluCelebrationSparklesPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
