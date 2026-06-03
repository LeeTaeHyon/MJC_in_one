import "package:flutter/material.dart";
import "package:flutter/scheduler.dart";

/// 원본 해상도 기준 핀치 줌 + 첫 진입 시 화면 contain 맞춤.
///
/// [imageProvider]로 intrinsic 크기를 구한 뒤 [TransformationController]에 초기 행렬 적용.
class MjcZoomableImageViewport extends StatefulWidget {
  const MjcZoomableImageViewport({
    super.key,
    required this.imageProvider,
    required this.child,
    this.onZoomChanged,
    this.onHorizontalSwipeAtEdge,
  });

  final ImageProvider imageProvider;
  final Widget child;

  /// scale > 1 일 때 true (PageView 스와이프 잠금 등에 사용).
  final ValueChanged<bool>? onZoomChanged;
  final ValueChanged<MjcHorizontalSwipeDirection>? onHorizontalSwipeAtEdge;

  @override
  State<MjcZoomableImageViewport> createState() =>
      _MjcZoomableImageViewportState();
}

enum MjcHorizontalSwipeDirection {
  previous,
  next,
}

class _MjcZoomableImageViewportState extends State<MjcZoomableImageViewport> {
  final TransformationController _transformController =
      TransformationController();

  double _viewportWidth = 0;
  double _dragDx = 0;
  bool _edgeSwipeCommitted = false;
  Size? _imageSize;

  /// 갤러리 앱에 가깝게: 끝 여유 넓게, 밀기/플릭 임계 낮게.
  static const double _edgeTolerance = 32;
  static const double _dragThreshold = 38;
  static const double _velocityThreshold = 420;
  bool _sizeResolveStarted = false;
  ImageStream? _imageStream;
  ImageStreamListener? _sizeListener;

  @override
  void initState() {
    super.initState();
    _transformController.addListener(_handleTransformChanged);
  }

  @override
  void dispose() {
    _transformController.removeListener(_handleTransformChanged);
    if (_imageStream != null && _sizeListener != null) {
      _imageStream!.removeListener(_sizeListener!);
    }
    _transformController.dispose();
    super.dispose();
  }

  void _handleTransformChanged() {
    final ValueChanged<bool>? callback = widget.onZoomChanged;
    if (callback == null) return;
    final double scale = _transformController.value.getMaxScaleOnAxis();
    callback(scale > 1.01);
  }

  void _handleInteractionStart(ScaleStartDetails details) {
    _dragDx = 0;
    _edgeSwipeCommitted = false;
  }

  void _handleInteractionUpdate(ScaleUpdateDetails details) {
    if (_transformController.value.getMaxScaleOnAxis() <= 1.01) return;
    _dragDx += details.focalPointDelta.dx;
    _tryCommitEdgeSwipe(useVelocity: false);
  }

  void _handleInteractionEnd(ScaleEndDetails details) {
    if (_edgeSwipeCommitted) return;
    _tryCommitEdgeSwipe(
      useVelocity: true,
      velocityX: details.velocity.pixelsPerSecond.dx,
    );
  }

  void _tryCommitEdgeSwipe({
    required bool useVelocity,
    double velocityX = 0,
  }) {
    final ValueChanged<MjcHorizontalSwipeDirection>? callback =
        widget.onHorizontalSwipeAtEdge;
    if (callback == null || _edgeSwipeCommitted) return;

    final Matrix4 matrix = _transformController.value;
    final double scale = matrix.getMaxScaleOnAxis();
    if (scale <= 1.01 || _viewportWidth <= 0) return;

    final double x = matrix.storage[12];
    final double minX = _viewportWidth * (1 - scale);
    final bool atPreviousEdge = x >= -_edgeTolerance;
    final bool atNextEdge = x <= minX + _edgeTolerance;

    final bool dragPrevious = _dragDx > _dragThreshold;
    final bool dragNext = _dragDx < -_dragThreshold;
    final bool flickPrevious =
        useVelocity && velocityX > _velocityThreshold;
    final bool flickNext = useVelocity && velocityX < -_velocityThreshold;

    if ((dragPrevious || flickPrevious) && atPreviousEdge) {
      _edgeSwipeCommitted = true;
      callback(MjcHorizontalSwipeDirection.previous);
    } else if ((dragNext || flickNext) && atNextEdge) {
      _edgeSwipeCommitted = true;
      callback(MjcHorizontalSwipeDirection.next);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_sizeResolveStarted) {
      _sizeResolveStarted = true;
      _resolveImageSize();
    }
  }

  @override
  void didUpdateWidget(covariant MjcZoomableImageViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageProvider != widget.imageProvider) {
      if (_imageStream != null && _sizeListener != null) {
        _imageStream!.removeListener(_sizeListener!);
      }
      _imageSize = null;
      _sizeResolveStarted = false;
      _transformController.value = Matrix4.identity();
      _resolveImageSize();
    }
  }

  void _resolveImageSize() {
    _sizeResolveStarted = true;
    _imageStream = widget.imageProvider
        .resolve(createLocalImageConfiguration(context));
    _sizeListener = ImageStreamListener((ImageInfo info, bool _) {
      if (!mounted) return;
      _setImageSize(Size(
        info.image.width.toDouble(),
        info.image.height.toDouble(),
      ));
    }, onError: (_, __) {});
    _imageStream!.addListener(_sizeListener!);
  }

  void _setImageSize(Size size) {
    _imageSize = size;
    // ImageStream can complete synchronously from cache. Defer repaint so this
    // widget never marks itself dirty during an ancestor build.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        _viewportWidth = constraints.maxWidth;
        final Size? imageSize = _imageSize;

        return Stack(
          fit: StackFit.expand,
          children: [
            if (imageSize != null)
              InteractiveViewer(
                transformationController: _transformController,
                constrained: true,
                boundaryMargin: EdgeInsets.zero,
                clipBehavior: Clip.hardEdge,
                minScale: 1,
                maxScale: 8,
                onInteractionStart: _handleInteractionStart,
                onInteractionUpdate: _handleInteractionUpdate,
                onInteractionEnd: _handleInteractionEnd,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: imageSize.width,
                      height: imageSize.height,
                      child: widget.child,
                    ),
                  ),
                ),
              )
            else
              const Center(
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
          ],
        );
      },
    );
  }
}
