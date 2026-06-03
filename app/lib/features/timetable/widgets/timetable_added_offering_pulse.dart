import "package:flutter/material.dart";

/// Accent fill overlay for newly added course cards (use inside a [Stack]).
class TimetableAddedOfferingPulseOverlay extends StatefulWidget {
  const TimetableAddedOfferingPulseOverlay({
    super.key,
    required this.active,
    required this.accent,
    required this.borderRadius,
  });

  final bool active;
  final Color accent;
  final BorderRadius borderRadius;

  @override
  State<TimetableAddedOfferingPulseOverlay> createState() =>
      _TimetableAddedOfferingPulseOverlayState();
}

class _TimetableAddedOfferingPulseOverlayState
    extends State<TimetableAddedOfferingPulseOverlay>
    with SingleTickerProviderStateMixin {
  static const Duration _kPulseDuration = Duration(milliseconds: 900);

  AnimationController? _pulseController;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _syncActive();
  }

  @override
  void didUpdateWidget(covariant TimetableAddedOfferingPulseOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      _syncActive();
    }
  }

  void _syncActive() {
    if (widget.active) {
      _visible = true;
      _pulseController ??= AnimationController(
        vsync: this,
        duration: _kPulseDuration,
      );
      _pulseController!
        ..reset()
        ..forward();
      return;
    }
    if (_visible) {
      setState(() => _visible = false);
    }
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible || _pulseController == null) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: IgnorePointer(
        child: ClipRRect(
          borderRadius: widget.borderRadius,
          child: AnimatedBuilder(
            animation: _pulseController!,
            builder: (BuildContext context, Widget? _) {
              final double t = Curves.easeOut.transform(_pulseController!.value);
              final double fill = (1 - t) * 0.18;
              return DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: widget.borderRadius,
                  color: widget.accent.withValues(alpha: fill),
                ),
                child: const SizedBox.expand(),
              );
            },
          ),
        ),
      ),
    );
  }
}
