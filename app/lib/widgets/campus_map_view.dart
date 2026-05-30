import "package:flutter/material.dart";
import "package:flutter_map/flutter_map.dart";
import "package:latlong2/latlong.dart";
import "package:mjc_in_one/services/campus_map_data.dart";
import "package:mjc_in_one/services/campus_room_parser.dart";
import "package:mjc_in_one/theme/app_colors.dart";

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
  final LatLng? currentLocation;
  final double locationPulse;
  final ValueChanged<CampusBuilding> onBuildingTap;

  @override
  State<CampusMapView> createState() => CampusMapViewState();
}

class CampusMapViewState extends State<CampusMapView> {
  final MapController _mapController = MapController();

  void focusOn(LatLng target, {double zoom = 18.5}) {
    _mapController.move(target, zoom);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<Marker> markers = <Marker>[
      for (final CampusBuilding building in widget.data.buildings)
        _buildingMarker(building),
      if (widget.currentLocation != null)
        Marker(
          point: widget.currentLocation!,
          width: 72,
          height: 72,
          child: _CurrentLocationMarker(pulse: widget.locationPulse),
        ),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          border: Border.all(color: scheme.outline.withValues(alpha: 0.70)),
        ),
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: widget.data.mapCenter,
            initialZoom: 17.5,
            minZoom: 15.0,
            maxZoom: 19.0,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
              userAgentPackageName: "com.myeongji.mio.mioNotice",
            ),
            MarkerLayer(markers: markers),
            RichAttributionWidget(
              attributions: [
                TextSourceAttribution(
                  "OpenStreetMap contributors",
                  onTap: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Marker _buildingMarker(CampusBuilding building) {
    final bool selected = widget.selectedBuilding?.id == building.id;
    final bool searched = widget.lookupResult?.building?.id == building.id &&
        widget.lookupResult?.isError == false;

    return Marker(
      point: building.location,
      width: selected || searched ? 124 : 104,
      height: selected || searched ? 72 : 64,
      alignment: Alignment.center,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onBuildingTap(building),
        child: _BuildingMarker(
          name: building.name,
          selected: selected || searched,
        ),
      ),
    );
  }
}

class _BuildingMarker extends StatelessWidget {
  const _BuildingMarker({
    required this.name,
    required this.selected,
  });

  final String name;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color color = selected ? AppColors.primary : const Color(0xFF374151);
    final double dotSize = selected ? 22 : 18;

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: 0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : scheme.surface,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : scheme.onSurface,
                  fontSize: selected ? 13 : 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
        Container(
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: scheme.surface, width: selected ? 4 : 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.50 : 0.20),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CurrentLocationMarker extends StatelessWidget {
  const _CurrentLocationMarker({required this.pulse});

  final double pulse;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final double size = 42 + pulse * 18;

    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary.withValues(alpha: 0.16),
              ),
              child: const SizedBox.expand(),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.surface,
                border: Border.all(color: AppColors.secondary, width: 3),
              ),
              child: Center(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.secondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
