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

    // 11. Attentive Curious Perk-Up: squash, spring pop up, leaf reaction, side glance, alert pose (850ms)
    _attentivePerkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
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
        _tiltController.animateTo(0.0, duration: const Duration(milliseconds: 320), curve: Curves.easeOut);
        _processingFloatController.stop();
        _listeningPulseController.stop();
        _thinkingCycleController.stop();
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
        _tiltController.stop();
        _processingFloatController.stop();
        _listeningPulseController.stop();
        _thinkingCycleController.stop();
        _attentivePerkController.forward(from: 0.0);
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
        _tiltController.animateTo(0.0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        _processingFloatController.stop();
        _thinkingCycleController.stop();
        _attentivePerkController.stop();
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
        _tiltController.animateTo(0.0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        _processingFloatController.stop();
        _listeningPulseController.stop();
        _attentivePerkController.stop();
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

      case ChilluState.greeting:
      case ChilluState.itemAdded:
        _processingFloatController.stop();
        _listeningPulseController.stop();
        _thinkingCycleController.stop();
        _attentivePerkController.stop();
        _bounceController.forward(from: 0.0);
        break;

      case ChilluState.error:
        _processingFloatController.stop();
        _listeningPulseController.stop();
        _thinkingCycleController.stop();
        _attentivePerkController.stop();
        _tiltController.animateTo(1.0, curve: Curves.elasticOut);
        break;

      case ChilluState.processing:
        _idleBreathingController.stop();
        _floatingController.stop();
        _listeningPulseController.stop();
        _thinkingCycleController.stop();
        _attentivePerkController.stop();
        if (!_processingFloatController.isAnimating) {
          _processingFloatController.repeat(reverse: true);
        }
        break;

      case ChilluState.recipeFound:
      case ChilluState.mealLogged:
        _processingFloatController.stop();
        _idleBreathingController.stop();
        _floatingController.stop();
        _listeningPulseController.stop();
        _thinkingCycleController.stop();
        _attentivePerkController.stop();
        break;

      case ChilluState.sleepy:
        _processingFloatController.stop();
        _listeningPulseController.stop();
        _thinkingCycleController.stop();
        _attentivePerkController.stop();
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
        _listeningPulseController,
        _thinkingCycleController,
        _attentivePerkController,
      ]),
      builder: (context, _) {
        double translateY = 0.0;
        double scaleY = 1.0;
        double scaleX = 1.0;
        double rotation = 0.0;

        // 1. Idle & interactive breathing: chest expansion & contraction
        final bool isInteractiveOrIdle = state == ChilluState.idle ||
            state == ChilluState.attentive ||
            state == ChilluState.listening ||
            state == ChilluState.thinking ||
            state == ChilluState.sleepy;

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
            // CURIOUS PERK-UP ATTENTIVE ANIMATION:
            // 1. Quick perk-up with squash & stretch (p: 0.0 -> 0.35)
            // 2. Rebound settling into alert resting pose (p: 0.35 -> 0.70)
            // 3. Playful sideways head tilt during side glance (p: 0.40 -> 0.74)
            // 4. Alert resting pose with subtle micro-breathing (p: 0.74 -> 1.00)
            final p = _attentivePerkController.value;

            final double perkTranslate;
            final double perkScaleY;
            final double perkScaleX;

            if (p < 0.12) {
              // Anticipation squash down
              final sub = p / 0.12;
              perkTranslate = 2.0 * sub;
              perkScaleY = 1.0 - (0.06 * sub);
              perkScaleX = 1.0 + (0.05 * sub);
            } else if (p < 0.35) {
              // Spring stretch pop up
              final sub = (p - 0.12) / 0.23;
              final tEase = Curves.easeOutBack.transform(sub);
              perkTranslate = 2.0 + ((-11.5 - 2.0) * tEase); // pops up to -11.5px
              perkScaleY = 0.94 + ((1.09 - 0.94) * tEase);
              perkScaleX = 1.05 + ((0.93 - 1.05) * tEase);
            } else if (p < 0.65) {
              // Rebound settling
              final sub = (p - 0.35) / 0.30;
              final tEase = Curves.easeInOut.transform(sub);
              perkTranslate = -11.5 + ((-6.0 - -11.5) * tEase);
              perkScaleY = 1.09 + ((1.03 - 1.09) * tEase);
              perkScaleX = 0.93 + ((0.985 - 0.93) * tEase);
            } else {
              // Alert resting pose with micro-breathing
              final breath = Curves.easeInOut.transform(_idleBreathingController.value);
              perkTranslate = -6.0 + (breath * 0.8);
              perkScaleY = 1.03 + (breath * 0.010);
              perkScaleX = 0.985 - (breath * 0.006);
            }

            translateY += perkTranslate;
            scaleY = perkScaleY;
            scaleX = perkScaleX;

            // Short playful head tilt during side glance (p: 0.40 -> 0.74)
            if (p >= 0.40 && p <= 0.74) {
              final sub = (p - 0.40) / 0.34;
              rotation = math.sin(sub * math.pi) * 0.040; // ~2.3 deg playful tilt
            } else {
              rotation = 0.0;
            }
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
            // Curious Perk-Up leaf reaction: staggered spring upward & settle into alert perk
            final p = _attentivePerkController.value;
            final double leftPerk;
            final double rightPerk;

            // Left leaf peaks at p = 0.30
            if (p < 0.30) {
              final sub = (p / 0.30).clamp(0.0, 1.0);
              leftPerk = Curves.easeOutBack.transform(sub) * 0.11; // ~6.3 deg
            } else if (p < 0.58) {
              final sub = ((p - 0.30) / 0.28).clamp(0.0, 1.0);
              leftPerk = Tween<double>(begin: 0.11, end: 0.045).transform(Curves.easeInOut.transform(sub));
            } else {
              leftPerk = 0.045; // Resting alert perk
            }

            // Right leaf slightly delayed, peaks at p = 0.38
            if (p < 0.08) {
              rightPerk = 0.0;
            } else if (p < 0.38) {
              final sub = ((p - 0.08) / 0.30).clamp(0.0, 1.0);
              rightPerk = -Curves.easeOutBack.transform(sub) * 0.10; // ~-5.7 deg
            } else if (p < 0.65) {
              final sub = ((p - 0.38) / 0.27).clamp(0.0, 1.0);
              rightPerk = Tween<double>(begin: -0.10, end: -0.038).transform(Curves.easeInOut.transform(sub));
            } else {
              rightPerk = -0.038; // Resting alert perk
            }

            lAngle += leftPerk;
            rAngle += rightPerk;
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

        // 7. Curious eye expression and side glance during Attentive
        final double eyeWiden;
        final double glanceShift;
        if (state == ChilluState.attentive) {
          final p = _attentivePerkController.value;
          // Widening during spring pop (p: 0.12 -> 0.38)
          if (p >= 0.12 && p <= 0.38) {
            final sub = (p - 0.12) / 0.26;
            eyeWiden = math.sin(sub * math.pi);
          } else {
            eyeWiden = 0.0;
          }
          // Side glance during (p: 0.42 -> 0.74)
          if (p >= 0.42 && p <= 0.74) {
            final sub = (p - 0.42) / 0.32;
            glanceShift = math.sin(sub * math.pi); // 0.0 -> 1.0 -> 0.0
          } else {
            glanceShift = 0.0;
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

                    // 5. Curious Eye Widening and Playful Side Glance Overlay during Attentive perk-up
                    if (eyeWiden > 0.0 || glanceShift > 0.0)
                      CustomPaint(
                        size: Size(widget.size, widget.size),
                        painter: _ChilluCuriousEyesPainter(
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
        } else if (state == ChilluState.attentive) {
          // Attentive: dynamic shadow reacting to squash, spring pop lift, and alert resting pose
          final p = _attentivePerkController.value;
          if (p < 0.12) {
            final sub = p / 0.12;
            shadowScale = 1.0 + (0.05 * sub);
            shadowOpacity = 0.11 + (0.02 * sub);
          } else if (p < 0.35) {
            final sub = (p - 0.12) / 0.23;
            final tEase = Curves.easeOutBack.transform(sub);
            shadowScale = 1.05 - (0.19 * tEase); // down to 0.86
            shadowOpacity = 0.13 - (0.05 * tEase); // down to 0.08
          } else {
            shadowScale = 0.92;
            shadowOpacity = 0.10;
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

/// Renders subtle curious eye widening and playful sideways glance during the Attentive perk-up.
class _ChilluCuriousEyesPainter extends CustomPainter {
  final double widenProgress; // 0.0 to 1.0
  final double glanceProgress; // 0.0 to 1.0 (shifts pupils right towards conversation)

  const _ChilluCuriousEyesPainter({
    required this.widenProgress,
    required this.glanceProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (widenProgress <= 0.0 && glanceProgress <= 0.0) return;

    final eyeWidth = size.width * 0.20;
    final eyeHeight = size.height * 0.23;

    final leftCenter = Offset(size.width * 0.3664, size.height * 0.4781);
    final rightCenter = Offset(size.width * 0.6336, size.height * 0.4781);

    // 1. Playful raised curious eyebrows during eye widening
    if (widenProgress > 0.05) {
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

    // 2. Playful sideways glance (pupils shift right toward conversation)
    if (glanceProgress > 0.05) {
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
  bool shouldRepaint(covariant _ChilluCuriousEyesPainter oldDelegate) {
    return oldDelegate.widenProgress != widenProgress || oldDelegate.glanceProgress != glanceProgress;
  }
}
