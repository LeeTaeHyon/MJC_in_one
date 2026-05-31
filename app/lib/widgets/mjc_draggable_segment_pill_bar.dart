import "package:flutter/material.dart";
import "package:flutter/physics.dart";
import "package:flutter/services.dart";

/// iOS `UISegmentedControl` 스타일: 탭으로 즉시 전환, 가로 드래그로 thumb 이동.
/// thumb 아래 세그먼트 내용은 thumb 중심 거리에 따라 연속적으로 확대됩니다.
class MjcDraggableSegmentPillBar extends StatefulWidget {
  const MjcDraggableSegmentPillBar({
    super.key,
    required this.segmentCount,
    required this.selectedIndex,
    required this.onSelectedIndexChanged,
    required this.segmentBuilder,
    required this.accentColor,
    required this.isDark,
    this.horizontalPadding = 4,
    this.verticalPadding = 4,
    this.thumbScaleDragging = 1.08,
    this.contentScaleDragging = 1.06,
    this.showThumbWhenIdle = true,
  });

  final int segmentCount;
  final int selectedIndex;
  final ValueChanged<int> onSelectedIndexChanged;
  final Widget Function(
    BuildContext context,
    int index,
    bool selected,
    bool interacting,
  ) segmentBuilder;
  final Color accentColor;
  final bool isDark;
  final double horizontalPadding;
  final double verticalPadding;
  final double thumbScaleDragging;
  final double contentScaleDragging;

  /// false면 thumb 없이 아이콘 색만 바뀌고, 손을 뗀 뒤에는 배경이 남지 않습니다.
  /// 드래그하는 동안에만 thumb가 보입니다.
  final bool showThumbWhenIdle;

  @override
  State<MjcDraggableSegmentPillBar> createState() =>
      _MjcDraggableSegmentPillBarState();
}

class _MjcDraggableSegmentPillBarState extends State<MjcDraggableSegmentPillBar>
    with SingleTickerProviderStateMixin {
  static const SpringDescription _emphasisSpringIn = SpringDescription(
    mass: 0.32,
    stiffness: 460,
    damping: 27,
  );
  static const SpringDescription _emphasisSpringOut = SpringDescription(
    mass: 0.38,
    stiffness: 340,
    damping: 22,
  );
  static const Duration _thumbFadeDuration = Duration(milliseconds: 160);
  static const Curve _thumbFadeInCurve = Curves.easeOutCubic;
  static const Curve _thumbFadeOutCurve = Curves.easeInCubic;

  final GlobalKey _trackKey = GlobalKey();

  late final AnimationController _emphasisController;

  bool _dragging = false;
  double? _dragThumbLeft;
  /// 손을 뗀 뒤 페이드아웃 동안 thumb 위치 고정용.
  double? _fadeOutThumbLeft;

  int get _count => widget.segmentCount;

  @override
  void initState() {
    super.initState();
    _emphasisController = AnimationController.unbounded(vsync: this, value: 0);
  }

  @override
  void dispose() {
    _emphasisController.dispose();
    super.dispose();
  }

  int _indexFromThumbLeft(double thumbLeft, double segmentWidth) {
    if (segmentWidth <= 0) return widget.selectedIndex;
    final double center = thumbLeft + segmentWidth / 2;
    return (center / segmentWidth).floor().clamp(0, _count - 1);
  }

  double _thumbLeftForIndex(int index, double segmentWidth) =>
      index * segmentWidth;

  double _clampThumbLeft(double left, double segmentWidth, double trackWidth) {
    final double maxLeft = trackWidth - segmentWidth;
    if (left < 0) return 0;
    if (left > maxLeft) return maxLeft;
    return left;
  }

  double? get _thumbCenterX {
    if (!_dragging || _dragThumbLeft == null) return null;
    final RenderBox? box =
        _trackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final double segmentWidth = box.size.width / _count;
    return _dragThumbLeft! + segmentWidth / 2;
  }

  /// thumb 중심과 세그먼트 중심 거리 → 0..1 (smoothstep).
  double _segmentEmphasis(int index, double segmentWidth) {
    final double? thumbCenter = _thumbCenterX;
    if (thumbCenter == null) return 0;
    final double segmentCenter = (index + 0.5) * segmentWidth;
    final double normalized =
        ((thumbCenter - segmentCenter).abs()) / (segmentWidth * 0.52);
    final double t = (1 - normalized).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  double _contentScaleFor(int index, double segmentWidth) {
    final double boost = widget.contentScaleDragging - 1;
    final double spring = _emphasisController.value;
    if (spring <= 0) return 1;

    if (_dragging && _dragThumbLeft != null) {
      final double proximity = _segmentEmphasis(index, segmentWidth);
      return 1 + boost * proximity * spring;
    }

    if (widget.showThumbWhenIdle) {
      // 드래그 종료 후 spring이 0으로 돌아갈 때 선택 칸만 부드럽게 축소.
      if (index == widget.selectedIndex) {
        return 1 + boost * spring;
      }
    }
    return 1;
  }

  double get _thumbScale =>
      1 + (widget.thumbScaleDragging - 1) * _emphasisController.value;

  double _thumbFillAlpha(bool isDark) {
    final double emphasis = _emphasisController.value.clamp(0.0, 1.0);
    if (emphasis <= 0.001) return 0;
    final double base = isDark ? 0.22 : 0.14;
    final double boost = 0.02 * emphasis;
    if (!widget.showThumbWhenIdle) {
      return (base + boost) * emphasis;
    }
    return base + boost;
  }

  void _fadeEmphasisIn() {
    _emphasisController.stop();
    _emphasisController.animateTo(
      1,
      duration: _thumbFadeDuration,
      curve: _thumbFadeInCurve,
    );
  }

  void _fadeEmphasisOut({VoidCallback? onComplete}) {
    _emphasisController.stop();
    _emphasisController
        .animateTo(
          0,
          duration: _thumbFadeDuration,
          curve: _thumbFadeOutCurve,
        )
        .whenComplete(() {
      if (!mounted) return;
      onComplete?.call();
    });
  }

  void _animateEmphasis({required bool forward}) {
    _emphasisController.stop();
    _emphasisController.animateWith(
      SpringSimulation(
        forward ? _emphasisSpringIn : _emphasisSpringOut,
        _emphasisController.value,
        forward ? 1.0 : 0.0,
        0,
      ),
    );
  }

  void _startDrag(Offset globalPosition, double segmentWidth, double trackWidth) {
    HapticFeedback.selectionClick();
    final RenderBox? box =
        _trackKey.currentContext?.findRenderObject() as RenderBox?;
    final double initialLeft = box == null
        ? _thumbLeftForIndex(widget.selectedIndex, segmentWidth)
        : _clampThumbLeft(
            box.globalToLocal(globalPosition).dx - segmentWidth / 2,
            segmentWidth,
            trackWidth,
          );
    setState(() {
      _dragging = true;
      _dragThumbLeft = initialLeft;
      _fadeOutThumbLeft = null;
    });
    if (widget.showThumbWhenIdle) {
      _animateEmphasis(forward: true);
    } else {
      _fadeEmphasisIn();
    }
  }

  void _moveDrag(Offset globalPosition, double segmentWidth, double trackWidth) {
    final RenderBox? box =
        _trackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final Offset local = box.globalToLocal(globalPosition);
    setState(() {
      _dragThumbLeft = _clampThumbLeft(
        local.dx - segmentWidth / 2,
        segmentWidth,
        trackWidth,
      );
    });
  }

  void _endDrag(double segmentWidth) {
    if (!_dragging) return;
    final double left = _dragThumbLeft ??
        _thumbLeftForIndex(widget.selectedIndex, segmentWidth);
    final int next = _indexFromThumbLeft(left, segmentWidth);
    final double releaseLeft = left;
    setState(() {
      _dragging = false;
      _dragThumbLeft = null;
      if (!widget.showThumbWhenIdle) {
        _fadeOutThumbLeft = releaseLeft;
      }
    });
    if (widget.showThumbWhenIdle) {
      _animateEmphasis(forward: false);
    } else {
      _fadeEmphasisOut(
        onComplete: () {
          if (!mounted) return;
          setState(() => _fadeOutThumbLeft = null);
        },
      );
    }
    if (next != widget.selectedIndex) {
      HapticFeedback.lightImpact();
      widget.onSelectedIndexChanged(next);
    }
  }

  void _cancelDrag() {
    if (!_dragging) return;
    final double? releaseLeft = _dragThumbLeft;
    setState(() {
      _dragging = false;
      _dragThumbLeft = null;
      if (!widget.showThumbWhenIdle && releaseLeft != null) {
        _fadeOutThumbLeft = releaseLeft;
      }
    });
    if (widget.showThumbWhenIdle) {
      _animateEmphasis(forward: false);
    } else {
      _fadeEmphasisOut(
        onComplete: () {
          if (!mounted) return;
          setState(() => _fadeOutThumbLeft = null);
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    assert(_count > 0);
    final Color accent = widget.accentColor;
    final bool isDark = widget.isDark;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: widget.horizontalPadding,
        vertical: widget.verticalPadding,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double trackHeight =
              constraints.maxHeight > 0 ? constraints.maxHeight : 36;
          final BorderRadius trackRadius =
              BorderRadius.circular(trackHeight / 2);
          final double trackWidth = constraints.maxWidth;
          final double segmentWidth = trackWidth / _count;
          final int previewIndex = _dragging && _dragThumbLeft != null
              ? _indexFromThumbLeft(_dragThumbLeft!, segmentWidth)
              : widget.selectedIndex;
          final double targetLeft = _dragging && _dragThumbLeft != null
              ? _dragThumbLeft!
              : (_fadeOutThumbLeft ??
                  _thumbLeftForIndex(widget.selectedIndex, segmentWidth));
          final double thumbFillAlpha = _thumbFillAlpha(isDark);
          final bool showThumb = thumbFillAlpha > 0.001;
          final bool thumbFadingOut =
              !widget.showThumbWhenIdle && _fadeOutThumbLeft != null;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (details) =>
                _startDrag(details.globalPosition, segmentWidth, trackWidth),
            onHorizontalDragUpdate: (details) => _moveDrag(
              details.globalPosition,
              segmentWidth,
              trackWidth,
            ),
            onHorizontalDragEnd: (_) => _endDrag(segmentWidth),
            onHorizontalDragCancel: _cancelDrag,
            child: AnimatedBuilder(
              animation: _emphasisController,
              builder: (context, _) {
                return SizedBox(
                  key: _trackKey,
                  height: trackHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: List<Widget>.generate(_count, (int index) {
                          final bool selected = index == previewIndex;
                          final double contentScale =
                              _contentScaleFor(index, segmentWidth);
                          final bool interacting = contentScale > 1.002;
                          return Expanded(
                            child: Material(
                              type: MaterialType.transparency,
                              child: InkWell(
                                onTap: _dragging
                                    ? null
                                    : () =>
                                        widget.onSelectedIndexChanged(index),
                                borderRadius: trackRadius,
                                splashColor: accent.withValues(alpha: 0.12),
                                highlightColor:
                                    accent.withValues(alpha: 0.06),
                                child: Transform.scale(
                                  scale: contentScale,
                                  alignment: Alignment.center,
                                  filterQuality: FilterQuality.medium,
                                  child: widget.segmentBuilder(
                                    context,
                                    index,
                                    selected,
                                    interacting,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      if (showThumb)
                        AnimatedPositioned(
                          duration: _dragging || thumbFadingOut
                              ? Duration.zero
                              : const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                          left: targetLeft,
                          top: 0,
                          bottom: 0,
                          width: segmentWidth,
                          child: IgnorePointer(
                            child: Transform.scale(
                              scale: _thumbScale,
                              alignment: Alignment.center,
                              filterQuality: FilterQuality.medium,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: thumbFillAlpha),
                                  borderRadius: trackRadius,
                                  boxShadow: _emphasisController.value > 0.01
                                      ? <BoxShadow>[
                                          BoxShadow(
                                            color: accent.withValues(
                                              alpha: (isDark ? 0.28 : 0.16) *
                                                  _emphasisController.value,
                                            ),
                                            blurRadius: 6 +
                                                4 * _emphasisController.value,
                                            offset: Offset(
                                              0,
                                              2 + _emphasisController.value,
                                            ),
                                          ),
                                        ]
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
