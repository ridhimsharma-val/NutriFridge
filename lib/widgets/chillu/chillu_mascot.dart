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

  /// Optional long-press handler (e.g. for developer debug shortcuts).
  final VoidCallback? onLongPress;

  const ChilluMascot({
    super.key,
    this.controller,
    this.size = 100.0,
    this.onTap,
    this.onLongPress,
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
  late AnimationController _sleepyTransitionController;
  late AnimationController _sleepyLoopController;
  late AnimationController _wakeUpController;

  ChilluState _previousState = ChilluState.idle;
  Timer? _blinkTimer;
  Timer? _doubleBlinkTimer;
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
    _previousState = _controller.state;
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

    // 17. Sleepy entrance: bending, lowering, rotating 85° horizontally, settling bounce (2400ms)
    _sleepyTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    // 18. Sleepy continuous idle: horizontal sleep breathing (4400ms) & floating Z's
    _sleepyLoopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4400),
    );

    // 19. Wake-up reaction: 4-stage jump (eyes open, crouch, 22px leap arc, landing cushion) (1000ms)
    _wakeUpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          debugPrint('[Chillu] Mascot wake-up animation finished, completing state transition');
          _controller.completeWakeUp();
        }
      });

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
      _previousState = _controller.state;
      _controller.addListener(_onControllerStateChanged);
      _syncAnimationsWithState(_controller.state);
    }
  }

  void _onControllerStateChanged() {
    if (!mounted) return;
    final newState = _controller.state;
    final isWakingUp = _controller.isWakingUp;

    if (isWakingUp) {
      if (!_wakeUpController.isAnimating) {
        debugPrint('[Chillu] Mascot received wake-up signal: starting 1000ms upward stretch & bounce');
        _wakeUpController.forward(from: 0.0);
      }
      return;
    } else if (_previousState == ChilluState.sleepy && newState != ChilluState.sleepy) {
      if (!_wakeUpController.isAnimating) {
        debugPrint('[Chillu] Mascot transition out of sleepy: playing wake-up animation');
        _wakeUpController.forward(from: 0.0);
      }
    }
    _previousState = newState;
    _syncAnimationsWithState(newState);
    setState(() {});
  }

  void _stopActiveInteractionControllers() {
    _processingFloatController.stop();
    _listeningPulseController.stop();
    _thinkingCycleController.stop();
    _attentivePerkController.stop();
    _attentiveLoopController.stop();
    _bounceController.stop();
    _bounceController.reset();
    _tiltController.stop();
    _happyController.stop();
    _happyController.reset();
    _excitedController.stop();
    _excitedController.reset();
    _confusedController.stop();
    _confusedController.reset();
    _celebrationController.stop();
    _celebrationController.reset();
    _sleepyTransitionController.stop();
    _sleepyLoopController.stop();
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
        _happyController.reset();
        _excitedController.stop();
        _excitedController.reset();
        _confusedController.stop();
        _confusedController.reset();
        _celebrationController.stop();
        _celebrationController.reset();
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
        if (!_controller.isWakingUp) {
          _wakeUpController.stop();
          _wakeUpController.reset();
          _stopActiveInteractionControllers();
          _sleepyTransitionController.forward(from: 0.0);
          if (!_sleepyLoopController.isAnimating) {
            _sleepyLoopController.repeat();
          }
          if (!_leftLeafController.isAnimating) {
            _leftLeafController.repeat();
          }
          if (!_rightLeafController.isAnimating) {
            _rightLeafController.repeat();
          }
        }
        break;
    }
  }

  /// Schedules the next natural eye blink with irregular timing (3.0s to 6.0s for idle, 4.5s to 7.5s for sleepy).
  void _scheduleNextBlink() {
    _blinkTimer?.cancel();
    _doubleBlinkTimer?.cancel();
    if (!mounted) return;

    final isSleepy = _controller.state == ChilluState.sleepy;
    final nextInterval = isSleepy ? (4500 + _random.nextInt(3000)) : (3000 + _random.nextInt(3000));
    _blinkTimer = Timer(Duration(milliseconds: nextInterval), () {
      if (!mounted) return;

      // Only blink in non-celebration states
      if (!_controller.isCelebrationJump) {
        final blinkDuration = isSleepy
            ? const Duration(milliseconds: 280)
            : const Duration(milliseconds: 140);
        _blinkController.duration = blinkDuration;

        _blinkController.forward(from: 0.0).then((_) {
          if (!mounted) return;
          _blinkController.reverse().then((_) {
            if (!mounted) return;
            // 20% chance of a double-blink in normal idle (never in sleepy)
            if (!isSleepy && _random.nextDouble() < 0.20) {
              _doubleBlinkTimer?.cancel();
              _doubleBlinkTimer = Timer(const Duration(milliseconds: 120), () {
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
    _doubleBlinkTimer?.cancel();
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
    _sleepyTransitionController.dispose();
    _sleepyLoopController.dispose();
    _wakeUpController.dispose();
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
        onLongPress: widget.onLongPress,
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

          final double sizeScale = (widget.size / 100.0).clamp(0.65, 1.25);

          // 3-stage triumphant jump sequence (3x Intensity Upgrade):
          // 1. Primary huge celebratory leap (0.0 -> 0.42)
          if (p < 0.42) {
            final sub = (p / 0.42).clamp(0.0, 1.0);
            final tEase = 4 * sub * (1 - sub);
            jumpY = -95.0 * sizeScale * tEase; // 3x celebratory leap!
            sY = 1.0 + (tEase * 0.42); // Upward victory stretch 42%
            sX = 1.0 - (tEase * 0.20);
            rot = math.sin(sub * 2 * math.pi) * 0.25; // Exuberant victory sway (~14 deg)
          }
          // 2. Secondary joyous victory bounce (0.42 -> 0.74)
          else if (p < 0.74) {
            final sub = ((p - 0.42) / 0.32).clamp(0.0, 1.0);
            final tEase = 4 * sub * (1 - sub);
            jumpY = -48.0 * sizeScale * tEase; // 3x secondary bounce!
            sY = 1.0 + (tEase * 0.25);
            sX = 1.0 - (tEase * 0.12);
            rot = -math.sin(sub * 2 * math.pi) * 0.20;
          }
          // 3. Satisfying follow-through finish with soft landing cushion (0.74 -> 1.0)
          else {
            final sub = ((p - 0.74) / 0.26).clamp(0.0, 1.0);
            if (sub < 0.45) {
              final sub3 = sub / 0.45;
              final tEase = 4 * sub3 * (1 - sub3);
              jumpY = -20.0 * sizeScale * tEase;
              sY = 1.0 + (tEase * 0.12);
              sX = 1.0 - (tEase * 0.06);
            } else {
              // Elastic settling cushion to resting pose
              final settleSub = ((sub - 0.45) / 0.55).clamp(0.0, 1.0);
              final settleSin = math.sin(settleSub * math.pi);
              jumpY = 3.5 * settleSin;
              sY = 1.0 - (settleSin * 0.10);
              sX = 1.0 + (settleSin * 0.08);
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
        _sleepyTransitionController,
        _sleepyLoopController,
        _wakeUpController,
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

          final double sizeScale = (widget.size / 100.0).clamp(0.46, 1.25);

          if (state == ChilluState.idle) {
            translateY += -2.0 * floatSin;
          } else if (state == ChilluState.sleepy) {
            // SLEEPY (Full Lying-Down Sleeping Pose v3):
            // Chillu physically lies down sideways on its side (rotates ~85° / 1.484 rad onto the bottom surface)
            if (!_wakeUpController.isAnimating) {
              final p = _sleepyTransitionController.isAnimating ? _sleepyTransitionController.value : 1.0;
              final loopVal = _sleepyLoopController.value;

              if (p < 0.25) {
                // Stage 1: Slowly bends, lowers body, moves sideways
                final sub = p / 0.25;
                final tEase = Curves.easeInOut.transform(sub);
                translateY += 5.0 * sizeScale * tEase;
                translateX += 3.0 * sizeScale * tEase;
                rotation = 0.26 * tEase; // ~15° tilt
                scaleY = 1.0 - (0.04 * tEase);
                scaleX = 1.0 + (0.04 * tEase);
              } else if (p < 0.75) {
                // Stage 2: Rotates into horizontal sleeping position (~85°) and settles onto bottom surface
                final sub = (p - 0.25) / 0.50;
                final rotEase = Curves.easeInOutCubic.transform(sub);
                rotation = Tween<double>(begin: 0.26, end: 1.484).transform(rotEase); // ~85°
                translateY += Tween<double>(begin: 5.0, end: 12.0).transform(rotEase) * sizeScale;
                translateX += Tween<double>(begin: 3.0, end: -2.0).transform(rotEase) * sizeScale;
                scaleY = Tween<double>(begin: 0.96, end: 0.98).transform(rotEase);
                scaleX = Tween<double>(begin: 1.04, end: 1.02).transform(rotEase);
              } else if (p < 1.0) {
                // Stage 3: Subtle final settling cushion bounce onto bottom surface
                final sub = (p - 0.75) / 0.25;
                final bounceSin = math.sin(sub * math.pi);
                rotation = 1.484;
                translateY += (12.0 + (2.5 * bounceSin)) * sizeScale;
                translateX += -2.0 * sizeScale;
                scaleY = 0.98 - (0.04 * bounceSin);
                scaleX = 1.02 + (0.04 * bounceSin);
              } else {
                // Sleeping Idle: stays horizontally asleep with gentle chest breathing & peaceful dream shifts
                final breath = (math.sin(loopVal * 2 * math.pi) + 1.0) * 0.5;
                final dreamShift = math.sin(loopVal * 4 * math.pi) * 0.012;
                rotation = 1.484 + dreamShift;
                translateY += (12.0 - (breath * 1.5)) * sizeScale;
                translateX += -2.0 * sizeScale;
                scaleX = 1.02 + (breath * 0.025);
                scaleY = 0.98 - (breath * 0.015);
              }
            }
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
            // HAPPY (3x Intensity Upgrade): Big cheerful body bounce, dynamic squash & stretch, joyful body sway, and elastic landing cushion
            final double sizeScale = (widget.size / 100.0).clamp(0.65, 1.25);
            final p = _happyController.value;
            final double bounce;
            final double sY;
            final double sX;
            if (p < 0.42) {
              final sub = (p / 0.42).clamp(0.0, 1.0);
              final tEase = 4 * sub * (1 - sub);
              bounce = -65.0 * sizeScale * tEase; // 3x from -24.0 (big joyful bounce)
              sY = 1.0 + (tEase * 0.32); // 3x squash/stretch from 0.12
              sX = 1.0 - (tEase * 0.16);
            } else if (p < 0.72) {
              final sub = ((p - 0.42) / 0.30).clamp(0.0, 1.0);
              final tEase = 4 * sub * (1 - sub);
              bounce = -22.0 * sizeScale * tEase; // 3x from -8.0
              sY = 1.0 + (tEase * 0.14);
              sX = 1.0 - (tEase * 0.07);
            } else {
              // Stronger, satisfying settling cushion
              final sub = ((p - 0.72) / 0.28).clamp(0.0, 1.0);
              final settleSin = math.sin(sub * math.pi);
              bounce = 4.5 * settleSin;
              sY = 1.0 - (settleSin * 0.09);
              sX = 1.0 + (settleSin * 0.07);
            }
            translateY += bounce;
            scaleY = sY;
            scaleX = sX;
            rotation = math.sin(p * 2 * math.pi) * 0.20; // 3x from 0.070 (~11.5 deg cheerful sway!)
          } else if (state == ChilluState.excited || state == ChilluState.recipeFound) {
            // EXCITED (3x Intensity Upgrade): Visibly dramatic high jump, explosive secondary hop,
            // powerful squash-and-stretch, energetic body sway, and impact landing
            final double sizeScale = (widget.size / 100.0).clamp(0.65, 1.25);
            final p = _excitedController.value;
            final double jump;
            final double sY;
            final double sX;
            if (p < 0.44) {
              final sub = (p / 0.44).clamp(0.0, 1.0);
              final tEase = 4 * sub * (1 - sub);
              jump = -105.0 * sizeScale * tEase; // 3x from -38.0 (huge energetic jump!)
              sY = 1.0 + (tEase * 0.45); // 45% vertical stretch on takeoff/peak
              sX = 1.0 - (tEase * 0.22);
            } else if (p < 0.74) {
              final sub = ((p - 0.44) / 0.30).clamp(0.0, 1.0);
              final tEase = 4 * sub * (1 - sub);
              jump = -48.0 * sizeScale * tEase; // 3x secondary hop from -18.0
              sY = 1.0 + (tEase * 0.24);
              sX = 1.0 - (tEase * 0.12);
            } else {
              // Energetic tertiary settling hop & impact cushion
              final sub = ((p - 0.74) / 0.26).clamp(0.0, 1.0);
              if (sub < 0.45) {
                final sub3 = sub / 0.45;
                final tEase = 4 * sub3 * (1 - sub3);
                jump = -16.0 * sizeScale * tEase;
                sY = 1.0 + (tEase * 0.10);
                sX = 1.0 - (tEase * 0.05);
              } else {
                final settleSub = ((sub - 0.45) / 0.55).clamp(0.0, 1.0);
                final settleSin = math.sin(settleSub * math.pi);
                jump = 5.0 * settleSin;
                sY = 1.0 - (settleSin * 0.12);
                sX = 1.0 + (settleSin * 0.10);
              }
            }
            translateY += jump;
            scaleY = sY;
            scaleX = sX;
            rotation = math.sin(p * 4 * math.pi) * 0.30; // 3x from 0.110 (~17.2 deg energetic sway!)
          } else if (state == ChilluState.confused || state == ChilluState.error) {
            // CONFUSED (3x Intensity Upgrade): Adorable dramatic head tilt (~30 deg / +0.52 rad),
            // prominent lateral questioning lean (up to 16px), pronounced puzzled body sway
            final double sizeScale = (widget.size / 100.0).clamp(0.65, 1.25);
            final p = _confusedController.value;
            final double tilt;
            final double sway;
            final double lateralLean;
            if (p < 0.30) {
              final sub = (p / 0.30).clamp(0.0, 1.0);
              tilt = Curves.easeOutBack.transform(sub) * 0.52; // 3x from 0.28 (~30 deg head tilt!)
              sway = 0.0;
              lateralLean = Curves.easeOut.transform(sub) * 10.0 * sizeScale;
            } else if (p < 0.75) {
              final sub = (p - 0.30) / 0.45;
              tilt = 0.52;
              sway = math.sin(sub * 3 * math.pi) * 0.20; // 3x from 0.070 (~11.5 deg puzzled rocking)
              lateralLean = (10.0 + (math.sin(sub * 2 * math.pi) * 7.0)) * sizeScale;
            } else {
              final sub = ((p - 0.75) / 0.25).clamp(0.0, 1.0);
              // Settles gently into a persistent inquisitive tilt while in confused error state
              tilt = Tween<double>(begin: 0.52, end: 0.28).transform(Curves.easeInOut.transform(sub));
              sway = math.sin(sub * math.pi) * 0.05;
              lateralLean = Tween<double>(begin: 10.0 * sizeScale, end: 5.5 * sizeScale).transform(Curves.easeInOut.transform(sub));
            }
            rotation = tilt + sway;
            translateX += lateralLean;
            translateY += 3.0;
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

        // 6. Wake-Up Jump: 4 distinct stages (Stage 1 wake up -> Stage 2 crouch -> Stage 3 22px leap & 0° rotate -> Stage 4 landing cushion)
        if (_wakeUpController.isAnimating) {
          final double sizeScale = (widget.size / 100.0).clamp(0.46, 1.25);
          final w = _wakeUpController.value;

          if (w < 0.20) {
            // Stage 1: Wake up - eyes open, reacts as if just woken up, leaves begin lifting, body still lying down
            rotation = 1.484;
            translateY += 12.0 * sizeScale;
            translateX += -2.0 * sizeScale;
            scaleX = 1.02;
            scaleY = 0.98;
          } else if (w < 0.35) {
            // Stage 2: Prepare to jump - anticipatory squash, body compresses into ground
            final sub = ((w - 0.20) / 0.15).clamp(0.0, 1.0);
            final crouchSin = math.sin(sub * math.pi);
            rotation = 1.484 - (0.08 * crouchSin);
            translateY += (12.0 + (3.5 * crouchSin)) * sizeScale;
            translateX += -2.0 * sizeScale;
            scaleX = 1.02 + (0.14 * crouchSin);
            scaleY = 0.98 - (0.12 * crouchSin);
          } else if (w < 0.72) {
            // Stage 3: THE JUMP - clearly noticeable upward jump (18-24px, tuned to 22px), smooth rotation back to 0°
            final sub = ((w - 0.35) / 0.37).clamp(0.0, 1.0);
            final arcSin = math.sin(sub * math.pi);
            final rotEase = Curves.easeInOutCubic.transform(sub);
            rotation = Tween<double>(begin: 1.484, end: 0.0).transform(rotEase);
            final jumpY = Tween<double>(begin: 12.0 * sizeScale, end: 0.0).transform(sub) - (22.0 * sizeScale * arcSin);
            translateY += jumpY;
            translateX += Tween<double>(begin: -2.0 * sizeScale, end: 0.0).transform(sub);
            scaleY = 1.0 + (0.18 * arcSin);
            scaleX = 1.0 - (0.10 * arcSin);
          } else if (w < 0.88) {
            // Stage 4A: Landing impact cushion squash
            final sub = ((w - 0.72) / 0.16).clamp(0.0, 1.0);
            final cushionSin = math.sin(sub * math.pi);
            rotation = 0.0;
            translateY += 4.5 * sizeScale * cushionSin;
            scaleY = 1.0 - (0.14 * cushionSin);
            scaleX = 1.0 + (0.12 * cushionSin);
          } else {
            // Stage 4B: Secondary settling bounce & smooth restore of upright standing posture
            final sub = ((w - 0.88) / 0.12).clamp(0.0, 1.0);
            final settleSin = math.sin(sub * math.pi);
            rotation = 0.0;
            translateY += -2.5 * sizeScale * settleSin;
            scaleY = 1.0 + (0.04 * settleSin);
            scaleX = 1.0 - (0.03 * settleSin);
          }
        }

        // 7. Independent leaf sprout sway calculation
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
            // Happy (3x Intensity Upgrade): both leaves perk up cheerfully and sway with 3x spring
            final p = _happyController.value;
            final bounceSway = math.sin(p * math.pi);
            final springBack = math.sin(p * 3 * math.pi) * 0.12;
            lAngle += (0.380 * bounceSway) + springBack; // 3x from 0.130 (~22 deg!)
            rAngle -= (0.330 * bounceSway) + springBack; // 3x from 0.110 (~-19 deg!)
          } else if (state == ChilluState.excited || state == ChilluState.recipeFound) {
            // Excited (3x Intensity Upgrade): both leaves bounce independently with wild energetic flutter
            final p = _excitedController.value;
            final flutter = math.sin(p * 8 * math.pi);
            lAngle += 0.550 + (flutter * 0.250); // 3x from 0.220 + 0.090 (~31.5 deg perk + 14 deg flutter!)
            rAngle -= 0.500 - (flutter * 0.250); // 3x from 0.200 - 0.090 (~-28.6 deg perk + 14 deg flutter!)
          } else if (state == ChilluState.confused || state == ChilluState.error) {
            // Confused (3x Intensity Upgrade): Massive independent leaf reaction!
            // Left leaf perks straight up in curiosity (+30 deg), right leaf droops down over face (-35.5 deg)
            final p = _confusedController.value;
            final progress = (p < 0.30)
                ? Curves.easeOut.transform(p / 0.30)
                : (p > 0.75)
                    ? Tween<double>(begin: 1.0, end: 0.50).transform(Curves.easeInOut.transform((p - 0.75) / 0.25))
                    : 1.0;
            lAngle += 0.520 * progress;  // 3x from 0.180 (~30 deg straight up!)
            rAngle -= 0.620 * progress;  // 3x from 0.240 (~-35.5 deg droop low!)
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
          } else if (state == ChilluState.sleepy && !_wakeUpController.isAnimating) {
            // Sleepy: both leafy sprouts fall sideways naturally with the body
            final p = _sleepyTransitionController.isAnimating ? _sleepyTransitionController.value : 1.0;
            final droopFactor = Curves.easeInOut.transform(p.clamp(0.0, 1.0));
            final loopVal = _sleepyLoopController.value;
            final loopRustleL = math.sin(loopVal * 2 * math.pi) * 0.025;
            final loopRustleR = math.sin(loopVal * 2 * math.pi + 1.2) * -0.025;

            // Sprout leaves droop naturally sideways with gravity as body lies horizontal
            lAngle += (-0.220 * droopFactor) + loopRustleL;
            rAngle += (0.180 * droopFactor) + loopRustleR;
          }

          // Wake-Up Reaction: 4-stage leaf kinematics
          if (_wakeUpController.isAnimating) {
            final w = _wakeUpController.value;
            if (w < 0.20) {
              // Stage 1: leaves begin lifting from sleep droop
              final sub = (w / 0.20).clamp(0.0, 1.0);
              lAngle += Tween<double>(begin: -0.220, end: 0.0).transform(sub);
              rAngle += Tween<double>(begin: 0.180, end: 0.0).transform(sub);
            } else if (w < 0.35) {
              // Stage 2: preparing to jump, leaves coil slightly
              final sub = ((w - 0.20) / 0.15).clamp(0.0, 1.0);
              final coil = math.sin(sub * math.pi) * 0.10;
              lAngle += -coil;
              rAngle += coil;
            } else if (w < 0.72) {
              // Stage 3: jump whip with elastic spring-back overshoot (+0.35 rad)
              final sub = ((w - 0.35) / 0.37).clamp(0.0, 1.0);
              final whip = math.sin(sub * math.pi) * 0.35;
              lAngle += whip;
              rAngle -= whip;
            } else {
              // Stage 4: landing cushion and natural leaf settling
              final sub = ((w - 0.72) / 0.28).clamp(0.0, 1.0);
              final settle = math.sin(sub * 2 * math.pi) * 0.12 * (1.0 - sub);
              lAngle += settle;
              rAngle -= settle;
            }
          }

          leftLeafAngle = lAngle;
          rightLeafAngle = rAngle;
        } else {
          leftLeafAngle = 0.0;
          rightLeafAngle = 0.0;
        }

        // 8. Emotional Eye Expressions (Happy, Excited, Confused, Attentive)
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
                    ? Tween<double>(begin: 1.0, end: 0.60).transform((_confusedController.value - 0.75) / 0.25)
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

        // Yawn reaction progress during sleepy entrance transition
        final double yawnProgress;
        if (state == ChilluState.sleepy && _sleepyTransitionController.isAnimating) {
          final p = _sleepyTransitionController.value;
          if (p >= 0.35 && p <= 0.75) {
            yawnProgress = math.sin(((p - 0.35) / 0.40) * math.pi);
          } else {
            yawnProgress = 0.0;
          }
        } else {
          yawnProgress = 0.0;
        }

        // 9. Eye blinking, pensive gaze focus, and sleepy half-closed eyes
        final double gazeEyelid;
        if (state == ChilluState.thinking) {
          final cycle = _thinkingCycleController.value;
          gazeEyelid = (0.16 + (math.sin(cycle * 2 * math.pi) * 0.03)).clamp(0.0, 0.22);
        } else {
          gazeEyelid = 0.0;
        }

        // Calculate sleepy 100% eye closure
        double sleepyEyelid = 0.0;
        if (state == ChilluState.sleepy && !_wakeUpController.isAnimating) {
          final p = _sleepyTransitionController.value;
          if (_sleepyTransitionController.isAnimating) {
            // Eyelids close completely into peaceful sleep (0.0 -> 1.0)
            sleepyEyelid = Curves.easeInOut.transform((p / 0.30).clamp(0.0, 1.0));
          } else {
            sleepyEyelid = 1.0; // 100% closed during sleep
          }
        }

        // Natural wake-up eye opening during Stage 1 (0.0 to 0.18)
        if (_wakeUpController.isAnimating) {
          final w = _wakeUpController.value;
          if (w < 0.18) {
            final openProgress = (w / 0.18).clamp(0.0, 1.0);
            sleepyEyelid = 1.0 - Curves.easeOut.transform(openProgress);
          } else {
            sleepyEyelid = 0.0;
          }
        }

        final double baseLid = math.max(gazeEyelid, sleepyEyelid);
        final double effectiveBlinkProgress = (state == ChilluState.sleepy && !_wakeUpController.isAnimating)
            ? 1.0
            : math.max(_blinkController.value, baseLid);

        // Calculate sleepy expression progress (soft sleeping eyebrows and warm cheek blush)
        final double sleepyProgress;
        if (state == ChilluState.sleepy && !_wakeUpController.isAnimating) {
          final p = _sleepyTransitionController.isAnimating ? _sleepyTransitionController.value : 1.0;
          sleepyProgress = Curves.easeInOut.transform(p.clamp(0.0, 1.0));
        } else {
          sleepyProgress = 0.0;
        }

        // Floating Z symbols opacity (fades in once lying down, vanishes on wake-up)
        final double zOpacity;
        if (state == ChilluState.sleepy && !_wakeUpController.isAnimating) {
          final p = _sleepyTransitionController.isAnimating ? _sleepyTransitionController.value : 1.0;
          zOpacity = ((p - 0.40) / 0.60).clamp(0.0, 1.0);
        } else {
          zOpacity = 0.0;
        }

        final Alignment rotationAlignment = (state == ChilluState.sleepy || _wakeUpController.isAnimating)
            ? const Alignment(0.0, 0.35)
            : Alignment.bottomCenter;

        return Transform.translate(
          offset: Offset(translateX, translateY),
          child: Transform.rotate(
            angle: rotation,
            alignment: rotationAlignment,
            child: Transform.scale(
              scaleX: scaleX,
              scaleY: scaleY,
              alignment: rotationAlignment,
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

                    // 5. Emotional Eyes, Gaze, Sleepy Eyebrows & Yawn Overlay (Happy, Excited, Confused, Attentive, Sleepy)
                    if (happyEyeProgress > 0.0 ||
                        excitedEyeProgress > 0.0 ||
                        confusedEyeProgress > 0.0 ||
                        eyeWiden > 0.0 ||
                        glanceShift > 0.0 ||
                        yawnProgress > 0.0 ||
                        sleepyProgress > 0.0)
                      CustomPaint(
                        size: Size(widget.size, widget.size),
                        painter: _ChilluEmotionalEyesPainter(
                          happyProgress: happyEyeProgress,
                          excitedProgress: excitedEyeProgress,
                          confusedProgress: confusedEyeProgress,
                          widenProgress: eyeWiden,
                          glanceProgress: glanceShift,
                          yawnProgress: yawnProgress,
                          sleepyProgress: sleepyProgress,
                        ),
                      ),

                    // 6. Floating 'Z' symbols while Chillu is lying down asleep
                    if (zOpacity > 0.0)
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _ChilluSleepingZPainter(
                            progress: _sleepyLoopController.value,
                            opacity: zOpacity,
                          ),
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
        _sleepyTransitionController,
        _sleepyLoopController,
        _wakeUpController,
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
            hop = 4 * sub * (1 - sub) * 0.75;
          }
          shadowScale = (1.0 - (0.65 * hop)).clamp(0.20, 1.0);
          shadowOpacity = (0.12 - (0.10 * hop)).clamp(0.02, 0.12);
        } else if (state == ChilluState.happy && _happyController.isAnimating) {
          final hVal = _happyController.value;
          final hop = 4 * hVal * (1 - hVal);
          shadowScale = (1.0 - (0.48 * hop)).clamp(0.35, 1.0);
          shadowOpacity = (0.12 - (0.07 * hop)).clamp(0.03, 0.12);
        } else if ((state == ChilluState.excited || state == ChilluState.recipeFound) && _excitedController.isAnimating) {
          final eVal = _excitedController.value;
          final jumpPhase = (eVal / 0.74).clamp(0.0, 1.0);
          final hop = 4 * jumpPhase * (1 - jumpPhase);
          shadowScale = (1.0 - (0.60 * hop)).clamp(0.25, 1.0);
          shadowOpacity = (0.12 - (0.09 * hop)).clamp(0.02, 0.12);
        } else if ((state == ChilluState.confused || state == ChilluState.error) && _confusedController.isAnimating) {
          shadowScale = 0.92;
          shadowOpacity = 0.09;
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
        } else if (state == ChilluState.idle) {
          final breath = Curves.easeInOut.transform(_idleBreathingController.value);
          final floatVal = _floatingController.value;
          final floatSin = math.sin(floatVal * 2 * math.pi);
          shadowScale = 1.0 + (breath * 0.03) - (floatSin * 0.03);
          shadowOpacity = 0.11 + (breath * 0.02) - (floatSin * 0.02);
        } else if (state == ChilluState.sleepy) {
          if (!_wakeUpController.isAnimating) {
            // Lying down shadow: wider horizontally (1.55x) to support horizontal body
            final p = _sleepyTransitionController.isAnimating ? _sleepyTransitionController.value : 1.0;
            final t = Curves.easeInOut.transform(p.clamp(0.0, 1.0));
            shadowScale = Tween<double>(begin: 1.0, end: 1.55).transform(t);
            shadowOpacity = Tween<double>(begin: 0.11, end: 0.13).transform(t);
          }
        }

        // React to 4-stage wake-up reaction on ground shadow
        if (_wakeUpController.isAnimating) {
          final w = _wakeUpController.value;
          if (w < 0.20) {
            // Stage 1: lying down shadow
            shadowScale = 1.55;
            shadowOpacity = 0.13;
          } else if (w < 0.35) {
            // Stage 2: crouch press into floor - shadow expands
            final sub = ((w - 0.20) / 0.15).clamp(0.0, 1.0);
            final crouch = math.sin(sub * math.pi);
            shadowScale = 1.55 + (0.15 * crouch);
            shadowOpacity = 0.13 + (0.02 * crouch);
          } else if (w < 0.72) {
            // Stage 3: THE JUMP - shadow contracts to 0.45 and fades to 0.03 as Chillu leaps 22px high!
            final sub = ((w - 0.35) / 0.37).clamp(0.0, 1.0);
            final jumpSin = math.sin(sub * math.pi);
            shadowScale = Tween<double>(begin: 1.55, end: 1.0).transform(sub) - (0.55 * jumpSin);
            shadowOpacity = Tween<double>(begin: 0.13, end: 0.11).transform(sub) - (0.08 * jumpSin);
          } else if (w < 0.88) {
            // Stage 4A: landing impact cushion - shadow expands
            final sub = ((w - 0.72) / 0.16).clamp(0.0, 1.0);
            final impactSin = math.sin(sub * math.pi);
            shadowScale = 1.0 + (0.22 * impactSin);
            shadowOpacity = 0.11 + (0.03 * impactSin);
          } else {
            // Stage 4B: secondary settle to normal standing shadow
            final sub = ((w - 0.88) / 0.12).clamp(0.0, 1.0);
            final settleSin = math.sin(sub * math.pi);
            shadowScale = 1.0 - (0.05 * settleSin);
            shadowOpacity = 0.11;
          }
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
    if (_controller.isWakingUp) {
      return 'waking up with a jump';
    }
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
        return 'lying down asleep';
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
/// Confused quizzical brows, Attentive widening/glance, and Sleepy relaxed brows, blush & yawn).
class _ChilluEmotionalEyesPainter extends CustomPainter {
  final double happyProgress; // 0.0 to 1.0 (smiling curved eye creases)
  final double excitedProgress; // 0.0 to 1.0 (enlarged star sparkle catchlights & high lifted brows)
  final double confusedProgress; // 0.0 to 1.0 (asymmetrical quizzical cocked eyebrows & curious gaze)
  final double widenProgress; // 0.0 to 1.0 (alert attentive widening)
  final double glanceProgress; // 0.0 to 1.0 (attentive sideways glance)
  final double yawnProgress; // 0.0 to 1.0 (clearly visible yawn mouth and pink tongue)
  final double sleepyProgress; // 0.0 to 1.0 (relaxed sleepy eyebrows and warm cheek blush)

  const _ChilluEmotionalEyesPainter({
    this.happyProgress = 0.0,
    this.excitedProgress = 0.0,
    this.confusedProgress = 0.0,
    this.widenProgress = 0.0,
    this.glanceProgress = 0.0,
    this.yawnProgress = 0.0,
    this.sleepyProgress = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (happyProgress <= 0.0 &&
        excitedProgress <= 0.0 &&
        confusedProgress <= 0.0 &&
        widenProgress <= 0.0 &&
        glanceProgress <= 0.0 &&
        yawnProgress <= 0.0 &&
        sleepyProgress <= 0.0) {
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

        // Cheerful curved smiling arc (^) with deep smiling curve
        final smilePath = Path();
        final start = Offset(center.dx - (eyeWidth * 0.40), center.dy + (eyeHeight * 0.10));
        final peak = Offset(center.dx, center.dy - (eyeHeight * 0.28));
        final end = Offset(center.dx + (eyeWidth * 0.40), center.dy + (eyeHeight * 0.10));
        smilePath.moveTo(start.dx, start.dy);
        smilePath.quadraticBezierTo(peak.dx, peak.dy, end.dx, end.dy);
        canvas.drawPath(smilePath, smileLashPaint);

        canvas.restore();

        // Rosy cheek glow
        canvas.drawCircle(Offset(center.dx, center.dy + (eyeHeight * 0.58)), eyeWidth * 0.36, blushPaint);

        // Cheerful lifted eyebrows (raised high with 3x intensity)
        final browPath = Path();
        final bStart = Offset(center.dx - (eyeWidth * 0.36), center.dy - (eyeHeight * 0.64) - (eyeHeight * 0.30 * happyAlpha));
        final bPeak = Offset(center.dx, center.dy - (eyeHeight * 0.88) - (eyeHeight * 0.35 * happyAlpha));
        final bEnd = Offset(center.dx + (eyeWidth * 0.36), center.dy - (eyeHeight * 0.64) - (eyeHeight * 0.30 * happyAlpha));
        browPath.moveTo(bStart.dx, bStart.dy);
        browPath.quadraticBezierTo(bPeak.dx, bPeak.dy, bEnd.dx, bEnd.dy);
        canvas.drawPath(browPath, smileLashPaint);
      }
    }

    // 2. EXCITED (3x Intensity Upgrade): Highly energetic gleaming eyes, massive sparkle catchlights, and lifted brows
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
        // High enthusiastic eyebrows (lifted high with 3x intensity)
        final browLift = eyeHeight * 0.55 * excitedAlpha;
        final browPath = Path();
        final start = Offset(center.dx - (eyeWidth * 0.36), center.dy - (eyeHeight * 0.62) - browLift);
        final peak = Offset(center.dx, center.dy - (eyeHeight * 0.96) - browLift);
        final end = Offset(center.dx + (eyeWidth * 0.36), center.dy - (eyeHeight * 0.62) - browLift);
        browPath.moveTo(start.dx, start.dy);
        browPath.quadraticBezierTo(peak.dx, peak.dy, end.dx, end.dy);
        canvas.drawPath(browPath, browPaint);

        // Huge gleaming catchlights (bright sparkle burst in the upper pupil)
        final c1 = Offset(center.dx - (eyeWidth * 0.08), center.dy - (eyeHeight * 0.10));
        final starRadius = eyeWidth * 0.30; // 3x gleam radius
        canvas.drawCircle(c1, starRadius, sparklePaint);

        // 4-point sparkle cross shimmer with expansive reach
        canvas.drawLine(Offset(c1.dx - (starRadius * 2.6), c1.dy), Offset(c1.dx + (starRadius * 2.6), c1.dy), shimmerPaint);
        canvas.drawLine(Offset(c1.dx, c1.dy - (starRadius * 2.6)), Offset(c1.dx, c1.dy + (starRadius * 2.6)), shimmerPaint);

        // Dual lively secondary sparkles
        canvas.drawCircle(
          Offset(center.dx + (eyeWidth * 0.18), center.dy + (eyeHeight * 0.15)),
          eyeWidth * 0.12,
          sparklePaint,
        );
        canvas.drawCircle(
          Offset(center.dx - (eyeWidth * 0.14), center.dy + (eyeHeight * 0.18)),
          eyeWidth * 0.08,
          sparklePaint,
        );
      }
    }

    // 3. CONFUSED (3x Intensity Upgrade): Asymmetrical quizzical eyebrows & prominent questioning gaze
    if (confusedProgress > 0.0) {
      final confAlpha = confusedProgress.clamp(0.0, 1.0);
      final browPaint = Paint()
        ..color = const Color(0xFF1B4332).withValues(alpha: confAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2.4, size.width * 0.026)
        ..strokeCap = StrokeCap.round;

      // Questioning gaze: pupils drift inquisitively towards the upper-side
      final pupilShiftX = eyeWidth * 0.18 * confAlpha;
      final pupilShiftY = -eyeHeight * 0.14 * confAlpha;
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

      // Left Eyebrow: Inquisitively cocked high up (3x lift to 0.65)
      final leftLift = eyeHeight * 0.65 * confAlpha;
      final leftBrowPath = Path();
      final lStart = Offset(leftCenter.dx - (eyeWidth * 0.32), leftCenter.dy - (eyeHeight * 0.58) - leftLift);
      final lPeak = Offset(leftCenter.dx - (eyeWidth * 0.05), leftCenter.dy - (eyeHeight * 1.05) - leftLift);
      final lEnd = Offset(leftCenter.dx + (eyeWidth * 0.34), leftCenter.dy - (eyeHeight * 0.54) - (leftLift * 0.4));
      leftBrowPath.moveTo(lStart.dx, lStart.dy);
      leftBrowPath.quadraticBezierTo(lPeak.dx, lPeak.dy, lEnd.dx, lEnd.dy);
      canvas.drawPath(leftBrowPath, browPaint);

      // Right Eyebrow: Puzzled, lowered flat/angled down (3x drop to 0.22)
      final rightDrop = eyeHeight * 0.22 * confAlpha;
      final rightBrowPath = Path();
      final rStart = Offset(rightCenter.dx - (eyeWidth * 0.34), rightCenter.dy - (eyeHeight * 0.54) + rightDrop);
      final rPeak = Offset(rightCenter.dx, rightCenter.dy - (eyeHeight * 0.64) + rightDrop);
      final rEnd = Offset(rightCenter.dx + (eyeWidth * 0.32), rightCenter.dy - (eyeHeight * 0.70) + rightDrop);
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

    // 6. SLEEPY: Relaxed drooping eyebrows, cozy cheek blush & clearly visible yawn reaction
    if (sleepyProgress > 0.0) {
      final sleepyAlpha = sleepyProgress.clamp(0.0, 1.0);

      // Relaxed, sleepy eyebrows (resting gently above the drooped eyelids)
      final browPaint = Paint()
        ..color = const Color(0xFF1B4332).withValues(alpha: sleepyAlpha * 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.8, size.width * 0.022)
        ..strokeCap = StrokeCap.round;

      // Soft cozy cheek blush
      final blushPaint = Paint()
        ..color = const Color(0xFFFF8B94).withValues(alpha: sleepyAlpha * 0.32)
        ..style = PaintingStyle.fill;

      for (final center in [leftCenter, rightCenter]) {
        canvas.drawCircle(
          Offset(center.dx, center.dy + (eyeHeight * 0.55)),
          eyeWidth * 0.34,
          blushPaint,
        );
      }

      // Left eyebrow: gently sloping downward towards the outer edge
      final leftBrow = Path();
      final lStart = Offset(leftCenter.dx - (eyeWidth * 0.34), leftCenter.dy - (eyeHeight * 0.56));
      final lPeak = Offset(leftCenter.dx, leftCenter.dy - (eyeHeight * 0.68));
      final lEnd = Offset(leftCenter.dx + (eyeWidth * 0.34), leftCenter.dy - (eyeHeight * 0.64));
      leftBrow.moveTo(lStart.dx, lStart.dy);
      leftBrow.quadraticBezierTo(lPeak.dx, lPeak.dy, lEnd.dx, lEnd.dy);
      canvas.drawPath(leftBrow, browPaint);

      // Right eyebrow: mirrored relaxed angle
      final rightBrow = Path();
      final rStart = Offset(rightCenter.dx - (eyeWidth * 0.34), rightCenter.dy - (eyeHeight * 0.64));
      final rPeak = Offset(rightCenter.dx, rightCenter.dy - (eyeHeight * 0.68));
      final rEnd = Offset(rightCenter.dx + (eyeWidth * 0.34), rightCenter.dy - (eyeHeight * 0.56));
      rightBrow.moveTo(rStart.dx, rStart.dy);
      rightBrow.quadraticBezierTo(rPeak.dx, rPeak.dy, rEnd.dx, rEnd.dy);
      canvas.drawPath(rightBrow, browPaint);
    }

    // Clearly visible open yawn mouth & cute pink tongue during entrance yawn
    if (yawnProgress > 0.0) {
      final yawnAlpha = yawnProgress.clamp(0.0, 1.0);
      final mouthCenter = Offset(size.width * 0.50, size.height * 0.570);
      // Noticeably sized open yawn mouth: ~20px on 110px hero, clamped to min 10px on 46px avatar
      final mouthWidth = math.max(10.0, size.width * 0.18) * yawnAlpha;
      final mouthHeight = math.max(9.0, size.height * 0.16) * yawnAlpha;

      final mouthPaint = Paint()
        ..color = const Color(0xFF1B4332).withValues(alpha: yawnAlpha * 0.95)
        ..style = PaintingStyle.fill;

      final mouthRect = Rect.fromCenter(
        center: mouthCenter,
        width: mouthWidth,
        height: mouthHeight,
      );

      canvas.save();
      canvas.clipPath(Path()..addOval(mouthRect));
      canvas.drawOval(mouthRect, mouthPaint);

      // Cute pink tongue at the bottom curve of the open yawn mouth
      final tonguePaint = Paint()
        ..color = const Color(0xFFFF8B94).withValues(alpha: yawnAlpha * 0.95)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(mouthCenter.dx, mouthCenter.dy + (mouthHeight * 0.28)),
        mouthWidth * 0.42,
        tonguePaint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ChilluEmotionalEyesPainter oldDelegate) {
    return oldDelegate.happyProgress != happyProgress ||
        oldDelegate.excitedProgress != excitedProgress ||
        oldDelegate.confusedProgress != confusedProgress ||
        oldDelegate.widenProgress != widenProgress ||
        oldDelegate.glanceProgress != glanceProgress ||
        oldDelegate.yawnProgress != yawnProgress ||
        oldDelegate.sleepyProgress != sleepyProgress;
  }
}

/// Renders festive celebratory sparkle bursts around Chillu during the celebration jump.
class _ChilluCelebrationSparklesPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0

  const _ChilluCelebrationSparklesPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;

    final center = Offset(size.width * 0.5, size.height * 0.42);
    final baseRadius = size.width * 0.58;

    // Sparkle burst phases (3x Intensity Upgrade): burst 1 (p: 0.05 -> 0.46), burst 2 (p: 0.42 -> 0.86)
    final double burst1 = (progress >= 0.05 && progress <= 0.46)
        ? math.sin(((progress - 0.05) / 0.41) * math.pi)
        : 0.0;
    final double burst2 = (progress >= 0.42 && progress <= 0.86)
        ? math.sin(((progress - 0.42) / 0.44) * math.pi)
        : 0.0;

    final goldPaint = Paint()..style = PaintingStyle.fill;
    final mintPaint = Paint()..style = PaintingStyle.fill;
    final shimmerPaint = Paint()..style = PaintingStyle.fill;

    // 12 festive victory star positions
    final angles = [
      -math.pi * 0.88,
      -math.pi * 0.72,
      -math.pi * 0.54,
      -math.pi * 0.36,
      -math.pi * 0.18,
      -math.pi * 0.04,
      -math.pi * 0.96,
      -math.pi * 0.80,
      -math.pi * 0.62,
      -math.pi * 0.44,
      -math.pi * 0.26,
      -math.pi * 0.12,
    ];

    for (int i = 0; i < angles.length; i++) {
      final angle = angles[i];
      final isBurst1 = i < 6;
      final alpha = isBurst1 ? burst1 : burst2;
      if (alpha <= 0.01) continue;

      final dist = baseRadius * (0.80 + (0.35 * (1.0 - alpha)));
      final pos = Offset(center.dx + math.cos(angle) * dist, center.dy + math.sin(angle) * dist);
      final radius = math.max(3.2, size.width * (0.075 + (0.035 * (i % 2)))) * alpha;

      final paint = (i % 3 == 0)
          ? (goldPaint..color = const Color(0xFFFFD166).withValues(alpha: alpha * 0.95))
          : (i % 3 == 1)
              ? (mintPaint..color = const Color(0xFF06D6A0).withValues(alpha: alpha * 0.90))
              : (shimmerPaint..color = Colors.white.withValues(alpha: alpha * 0.98));

      // Draw dynamic 4-point star sparkle
      final starPath = Path();
      starPath.moveTo(pos.dx, pos.dy - (radius * 1.8));
      starPath.quadraticBezierTo(pos.dx, pos.dy, pos.dx + (radius * 1.8), pos.dy);
      starPath.quadraticBezierTo(pos.dx, pos.dy, pos.dx, pos.dy + (radius * 1.8));
      starPath.quadraticBezierTo(pos.dx, pos.dy, pos.dx - (radius * 1.8), pos.dy);
      starPath.quadraticBezierTo(pos.dx, pos.dy, pos.dx, pos.dy - (radius * 1.8));
      canvas.drawPath(starPath, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ChilluCelebrationSparklesPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Renders 3 delicate floating 'Z' symbols drifting upward-right above Chillu while lying down asleep.
class _ChilluSleepingZPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0 driving the float cycle
  final double opacity;  // 0.0 to 1.0 (smooth fade in/out)

  const _ChilluSleepingZPainter({
    required this.progress,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0.01) return;

    // 3 floating Z symbols of increasing size drifting above Chillu's head
    final zSpecs = [
      // (baseOffsetX, baseOffsetY, driftX, driftY, fontSize, phase)
      (0.66, 0.44, 0.05, -0.16, math.max(8.0, size.width * 0.09), 0.0),
      (0.72, 0.35, 0.07, -0.18, math.max(10.0, size.width * 0.12), 0.33),
      (0.78, 0.25, 0.09, -0.20, math.max(12.0, size.width * 0.15), 0.66),
    ];

    for (final spec in zSpecs) {
      final bx = spec.$1;
      final by = spec.$2;
      final dx = spec.$3;
      final dy = spec.$4;
      final fontSize = spec.$5;
      final phase = spec.$6;

      final t = (progress + phase) % 1.0;
      final alpha = (math.sin(t * math.pi) * opacity).clamp(0.0, 1.0);
      if (alpha <= 0.02) continue;

      final posX = (bx + (dx * t)) * size.width;
      final posY = (by + (dy * t)) * size.height;

      final textSpan = TextSpan(
        text: 'Z',
        style: TextStyle(
          color: const Color(0xFF2D6A4F).withValues(alpha: alpha * 0.85),
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(posX - (textPainter.width / 2), posY - (textPainter.height / 2)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ChilluSleepingZPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.opacity != opacity;
  }
}
