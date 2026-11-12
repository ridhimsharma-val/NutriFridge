import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'chillu_animation_controller.dart';

/// Presentation widget for the NutriFridge Chillu mascot.
/// Handles high-fidelity rendering, smooth physics-based animations,
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

  // Animation controllers for various movement styles
  late AnimationController _idleBreathingController;
  late AnimationController _processingFloatController;
  late AnimationController _bounceController;
  late AnimationController _tiltController;

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

    // 1. Idle breathing: subtle, continuous vertical expansion
    _idleBreathingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    // 2. Processing float: gentle hovering oscillation
    _processingFloatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // 3. Bounce: elastic vertical hop for greeting and item added
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // 4. Tilt: curious angle for thinking and confused error
    _tiltController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _syncAnimationsWithState(_controller.state);
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

  @override
  void dispose() {
    _controller.removeListener(_onControllerStateChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    _idleBreathingController.dispose();
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
                children: [
                  // Ground shadow
                  if (widget.showShadow)
                    Positioned(
                      bottom: 2,
                      child: _buildShadow(disableAnimations, state),
                    ),

                  // Mascot character with state-driven transformations
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
      // Reduced-motion: static master PNG
      return Image.asset(
        ChilluMascot.masterAsset,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
      );
    }

    if (isCelebration) {
      // Happy Jump state: uses transparent animated GIF
      return Image.asset(
        ChilluMascot.joyfulJumpAsset,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
        gaplessPlayback: true,
      );
    }

    // Default & expressive states: animated transformations on transparent master PNG
    return AnimatedBuilder(
      animation: Listenable.merge([
        _idleBreathingController,
        _processingFloatController,
        _bounceController,
        _tiltController,
      ]),
      builder: (context, child) {
        double translateY = 0.0;
        double scaleY = 1.0;
        double scaleX = 1.0;
        double rotation = 0.0;

        // 1. Idle breathing effect
        if (state == ChilluState.idle || state == ChilluState.sleepy) {
          final breath = _idleBreathingController.value;
          scaleY = 1.0 + (breath * 0.025);
          scaleX = 1.0 - (breath * 0.015);
          translateY = (1.0 - breath) * 1.5;
        }

        // 2. Processing floating effect
        if (state == ChilluState.processing) {
          final floatVal = _processingFloatController.value;
          // Smooth sinusoidal hover
          translateY = -8.0 * math.sin(floatVal * math.pi);
          scaleY = 1.0 + (floatVal * 0.02);
        }

        // 3. Bounce effect (greeting / itemAdded)
        if (_bounceController.isAnimating) {
          final bVal = _bounceController.value;
          // Parabolic bounce arc
          final hop = 4 * bVal * (1 - bVal);
          translateY = -14.0 * hop;
          if (bVal < 0.2) {
            // Squish before jump
            scaleY = 0.94;
            scaleX = 1.05;
          } else if (bVal < 0.6) {
            // Stretch during flight
            scaleY = 1.06;
            scaleX = 0.96;
          }
        }

        // 4. Tilt effect (thinking / error)
        if (_tiltController.value > 0.0) {
          final tVal = _tiltController.value;
          if (state == ChilluState.error) {
            // Curious confused wobble
            rotation = math.sin(tVal * math.pi * 3) * 0.08;
            translateY = 2.0;
          } else {
            // Subtle thoughtful tilt to the right
            rotation = tVal * 0.08;
          }
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
              child: child,
            ),
          ),
        );
      },
      child: Image.asset(
        ChilluMascot.masterAsset,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildShadow(bool disableAnimations, ChilluState state) {
    if (disableAnimations) {
      return Container(
        width: widget.size * 0.5,
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
