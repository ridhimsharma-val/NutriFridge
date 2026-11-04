import 'package:flutter/material.dart';

/// Smooth numeric quantity text with restrained number interpolation (250–350ms).
/// Animates smoothly between old and new stock values after inventory updates
/// without layout jumps, flashing, or excessive bouncing.
class AnimatedQuantityText extends StatefulWidget {
  final num value;
  final String unit;
  final TextStyle style;
  final String prefix;
  final String suffix;
  final Duration duration;

  const AnimatedQuantityText({
    super.key,
    required this.value,
    this.unit = '',
    required this.style,
    this.prefix = '',
    this.suffix = '',
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  State<AnimatedQuantityText> createState() => _AnimatedQuantityTextState();
}

class _AnimatedQuantityTextState extends State<AnimatedQuantityText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _fromValue = 0;
  double _toValue = 0;

  @override
  void initState() {
    super.initState();
    _fromValue = widget.value.toDouble();
    _toValue = widget.value.toDouble();

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _animation = Tween<double>(begin: _fromValue, end: _toValue).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didUpdateWidget(covariant AnimatedQuantityText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _fromValue = _animation.value;
      _toValue = widget.value.toDouble();

      final bool disableAnimations =
          MediaQuery.maybeOf(context)?.disableAnimations ?? false;

      _controller.stop();
      if (disableAnimations) {
        _controller.value = 1.0;
        _fromValue = _toValue;
        _animation = Tween<double>(begin: _toValue, end: _toValue).animate(_controller);
      } else {
        _controller.duration = widget.duration;
        _animation = Tween<double>(begin: _fromValue, end: _toValue).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
        );
        _controller.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static String formatAmount(num val, String unit) {
    String numberStr;
    if (val is int || val == val.roundToDouble()) {
      numberStr = val.toInt().toString();
    } else {
      numberStr = val.toStringAsFixed(1);
    }
    final cleanUnit = unit.trim();
    if (cleanUnit.isEmpty) return numberStr;
    return '$numberStr $cleanUnit';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final currentVal = _animation.value;
        final bool isTargetInt =
            widget.value is int || widget.value == widget.value.roundToDouble();

        final num displayVal;
        if (isTargetInt) {
          displayVal = currentVal.round();
        } else {
          displayVal = num.parse(currentVal.toStringAsFixed(1));
        }

        final formatted = formatAmount(displayVal, widget.unit);
        return Text(
          '${widget.prefix}$formatted${widget.suffix}',
          style: widget.style,
        );
      },
    );
  }
}
