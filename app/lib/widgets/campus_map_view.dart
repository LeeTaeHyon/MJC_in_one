import "dart:math" as math;
import "dart:ui" as ui;

import "package:flutter/material.dart";
import "package:mio_notice/services/campus_map_data.dart";
import "package:mio_notice/services/campus_room_parser.dart";
import "package:mio_notice/theme/app_colors.dart";

class CampusMapView extends StatefulWidget {
  const CampusMapView({
    super.key,
    required this.data,
    required this.selectedBuilding,
    required this.lookupResult,
    required this.currentLocation,
    required this.locationPulse,
    required this.onBuildingTap,
  });

  final CampusMapData data;
  final CampusBuilding? selectedBuilding;
  final CampusLookupResult? lookupResult;
  final Offset? currentLocation;
  final double locationPulse;
  final ValueChanged<CampusBuilding> onBuildingTap;

  @override
  State<CampusMapView> createState() => CampusMapViewState();
}

class CampusMapViewState extends State<CampusMapView> {
  final TransformationController _transformationController =
      TransformationController();
  Size _viewportSize = Size.zero;
  bool _didSetInitialTransform = false;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void focusOn(Offset target, {double scaleMultiplier = 2.2}) {
    if (_viewportSize == Size.zero) return;
    final double fitScale = _fitScale(_viewportSize);
    final double scale = (fitScale * scaleMultiplier).clamp(0.5, 3.2);
    _transformationController.value = _transformFor(
      scale: scale,
      dx: _viewportSize.width / 2 - target.dx * scale,
      dy: _viewportSize.height / 2 - target.dy * scale,
    );
  }

  void _setInitialTransformIfNeeded(Size viewportSize) {
    _viewportSize = viewportSize;
    if (_didSetInitialTransform || viewportSize == Size.zero) return;
    _didSetInitialTransform = true;

    final double scale = _fitScale(viewportSize);
    final Size imageSize = widget.data.imageSize;
    _transformationController.value = _transformFor(
      scale: scale,
      dx: (viewportSize.width - imageSize.width * scale) / 2,
      dy: (viewportSize.height - imageSize.height * scale) / 2,
    );
  }

  Matrix4 _transformFor({
    required double scale,
    required double dx,
    required double dy,
  }) {
    // InteractiveViewer expects a matrix that first scales the child, then
    // translates it in viewport space: p' = T * S * p
    final Matrix4 translation = Matrix4.identity()
      ..setTranslationRaw(dx, dy, 0);
    final Matrix4 scaling = Matrix4.diagonal3Values(scale, scale, 1.0);
    return translation * scaling;
  }

  double _fitScale(Size viewportSize) {
    final Size imageSize = widget.data.imageSize;
    return math.min(
      viewportSize.width / imageSize.width,
      viewportSize.height / imageSize.height,
    );
  }

  void _handleTapDown(TapDownDetails details) {
    final Matrix4 inverse = Matrix4.inverted(_transformationController.value);
    final Offset scenePoint =
        MatrixUtils.transformPoint(inverse, details.localPosition);

    for (final CampusBuilding building in widget.data.buildings.reversed) {
      if (building.contains(scenePoint)) {
        widget.onBuildingTap(building);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size imageSize = widget.data.imageSize;

    return LayoutBuilder(
      builder: (context, constraints) {
        final Size viewportSize =
            Size(constraints.maxWidth, constraints.maxHeight);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _setInitialTransformIfNeeded(viewportSize);
        });

        return ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFEAF1F8),
              border: Border.all(color: const Color(0xFFE0E6EF)),
            ),
            child: GestureDetector(
              onTapDown: _handleTapDown,
              child: InteractiveViewer(
                transformationController: _transformationController,
                constrained: false,
                minScale: 0.2,
                maxScale: 5,
                boundaryMargin: const EdgeInsets.all(500),
                child: SizedBox(
                  width: imageSize.width,
                  height: imageSize.height,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        widget.data.imageAsset,
                        fit: BoxFit.fill,
                        filterQuality: FilterQuality.medium,
                        errorBuilder: (context, error, stackTrace) {
                          return CustomPaint(
                            painter: _FallbackCampusMapPainter(
                              buildings: widget.data.buildings,
                            ),
                          );
                        },
                      ),
                      CustomPaint(
                        painter: _CampusMapOverlayPainter(
                          buildings: widget.data.buildings,
                          selectedBuilding: widget.selectedBuilding,
                          lookupResult: widget.lookupResult,
                          currentLocation: widget.currentLocation,
                          locationPulse: widget.locationPulse,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CampusMapOverlayPainter extends CustomPainter {
  const _CampusMapOverlayPainter({
    required this.buildings,
    required this.selectedBuilding,
    required this.lookupResult,
    required this.currentLocation,
    required this.locationPulse,
  });

  final List<CampusBuilding> buildings;
  final CampusBuilding? selectedBuilding;
  final CampusLookupResult? lookupResult;
  final Offset? currentLocation;
  final double locationPulse;

  @override
  void paint(Canvas canvas, Size size) {
    for (final CampusBuilding building in buildings) {
      final bool selected = selectedBuilding?.id == building.id;
      _drawBuilding(canvas, building, selected: selected);
    }

    final CampusLookupResult? result = lookupResult;
    if (result != null && result.hasBuilding && !result.isError) {
      _drawLookupChip(canvas, result);
    }

    final Offset? location = currentLocation;
    if (location != null) {
      _drawCurrentLocation(canvas, location);
    }
  }

  void _drawBuilding(
    Canvas canvas,
    CampusBuilding building, {
    required bool selected,
  }) {
    if (building.polygon.length < 3) return;

    final Path path = Path()
      ..moveTo(building.polygon.first.dx, building.polygon.first.dy);
    for (final Offset point in building.polygon.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    path.close();

    final Paint fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = selected
          ? const Color(0xFFFFD54F).withValues(alpha: 0.46)
          : AppColors.primary.withValues(alpha: 0.10);
    canvas.drawPath(path, fillPaint);

    final Paint strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = selected ? 6 : 3
      ..strokeJoin = StrokeJoin.round
      ..color = selected
          ? const Color(0xFFFFA000)
          : AppColors.primary.withValues(alpha: 0.55);
    canvas.drawPath(path, strokePaint);

    _drawLabel(canvas, building, selected: selected);
  }

  void _drawLabel(
    Canvas canvas,
    CampusBuilding building, {
    required bool selected,
  }) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: building.name,
        style: TextStyle(
          color: selected ? const Color(0xFF3E2A00) : Colors.white,
          fontSize: selected ? 30 : 24,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final Offset labelOffset =
        building.labelAnchor - Offset(painter.width / 2, painter.height / 2);
    final RRect background = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        labelOffset.dx - 18,
        labelOffset.dy - 9,
        painter.width + 36,
        painter.height + 18,
      ),
      const Radius.circular(18),
    );

    canvas.drawRRect(
      background,
      Paint()
        ..color = selected
            ? const Color(0xFFFFF8E1).withValues(alpha: 0.92)
            : Colors.black.withValues(alpha: 0.45),
    );
    painter.paint(canvas, labelOffset);
  }

  void _drawLookupChip(Canvas canvas, CampusLookupResult result) {
    final CampusBuilding building = result.building!;
    final String text = result.title;
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final Offset anchor = building.labelAnchor + const Offset(0, -86);
    final Offset chipOffset =
        anchor - Offset(painter.width / 2, painter.height / 2);
    final RRect chip = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        chipOffset.dx - 22,
        chipOffset.dy - 12,
        painter.width + 44,
        painter.height + 24,
      ),
      const Radius.circular(22),
    );
    canvas.drawRRect(chip, Paint()..color = AppColors.primary);
    painter.paint(canvas, chipOffset);
  }

  void _drawCurrentLocation(Canvas canvas, Offset location) {
    final double pulse = 1 + locationPulse * 0.55;
    canvas.drawCircle(
      location,
      34 * pulse,
      Paint()..color = AppColors.secondary.withValues(alpha: 0.16),
    );
    canvas.drawCircle(
      location,
      20,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      location,
      14,
      Paint()..color = AppColors.secondary,
    );
  }

  @override
  bool shouldRepaint(covariant _CampusMapOverlayPainter oldDelegate) {
    return oldDelegate.buildings != buildings ||
        oldDelegate.selectedBuilding != selectedBuilding ||
        oldDelegate.lookupResult != lookupResult ||
        oldDelegate.currentLocation != currentLocation ||
        oldDelegate.locationPulse != locationPulse;
  }
}

class _FallbackCampusMapPainter extends CustomPainter {
  const _FallbackCampusMapPainter({required this.buildings});

  final List<CampusBuilding> buildings;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint background = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(size.width, size.height),
        const [
          Color(0xFFE8F2F7),
          Color(0xFFF7FAEF),
        ],
      );
    canvas.drawRect(Offset.zero & size, background);

    final Paint roadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 44
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(90, size.height * 0.78)
        ..quadraticBezierTo(size.width * 0.45, size.height * 0.60,
            size.width * 0.88, size.height * 0.18),
      roadPaint,
    );

    final Paint guidePaint = Paint()
      ..color = const Color(0xFF9DB7C7).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    for (double x = 0; x < size.width; x += 120) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), guidePaint);
    }
    for (double y = 0; y < size.height; y += 120) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), guidePaint);
    }

    final TextPainter title = TextPainter(
      text: const TextSpan(
        text: "캠퍼스 약도 이미지 준비 중",
        style: TextStyle(
          color: Color(0xFF26465D),
          fontSize: 34,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    title.paint(canvas, Offset((size.width - title.width) / 2, 48));
  }

  @override
  bool shouldRepaint(covariant _FallbackCampusMapPainter oldDelegate) {
    return oldDelegate.buildings != buildings;
  }
}
