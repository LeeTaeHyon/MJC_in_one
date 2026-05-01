import "dart:async";

import "package:flutter/material.dart";
import "package:geolocator/geolocator.dart";
import "package:latlong2/latlong.dart";
import "package:mio_notice/services/campus_map_data.dart";
import "package:mio_notice/services/campus_room_parser.dart";
import "package:mio_notice/theme/app_colors.dart";
import "package:mio_notice/widgets/campus_map_view.dart";

class CampusMapScreen extends StatefulWidget {
  const CampusMapScreen({super.key});

  @override
  State<CampusMapScreen> createState() => _CampusMapScreenState();
}

class _CampusMapScreenState extends State<CampusMapScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<CampusMapViewState> _mapKey = GlobalKey<CampusMapViewState>();
  final TextEditingController _searchController = TextEditingController();
  late final Future<CampusMapData> _dataFuture = CampusMapData.load();
  late final AnimationController _pulseController;

  CampusLookupResult? _lookupResult;
  CampusBuilding? _selectedBuilding;
  LatLng? _currentLocation;
  String _locationStatus = "현재 위치를 확인하는 중입니다.";
  bool _loadingLocation = false;
  bool _mockLocationEnabled = false;
  String _mockLocationLabel = "";

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _dataFuture.then((CampusMapData data) => _loadCurrentLocation(data));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentLocation(CampusMapData data) async {
    if (_loadingLocation) return;
    setState(() {
      _loadingLocation = true;
      _locationStatus = "현재 위치를 확인하는 중입니다.";
    });

    try {
      if (_mockLocationEnabled) {
        setState(() {
          _loadingLocation = false;
          _locationStatus = "모의 위치($_mockLocationLabel)를 표시 중입니다.";
        });
        return;
      }
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _currentLocation = null;
          _locationStatus = "기기의 위치 서비스가 꺼져 있습니다.";
          _loadingLocation = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        setState(() {
          _currentLocation = null;
          _locationStatus = "위치 권한이 허용되지 않아 현재 위치를 표시할 수 없습니다.";
          _loadingLocation = false;
        });
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _currentLocation = null;
          _locationStatus = "위치 권한이 영구 거부되어 설정에서 권한을 허용해야 합니다.";
          _loadingLocation = false;
        });
        return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      final LatLng location = LatLng(
        position.latitude,
        position.longitude,
      );

      setState(() {
        _currentLocation = location;
        _locationStatus = "현재 위치를 지도에 표시했습니다.";
        _loadingLocation = false;
      });
    } on TimeoutException {
      setState(() {
        _currentLocation = null;
        _locationStatus = "현재 위치 확인 시간이 초과되었습니다.";
        _loadingLocation = false;
      });
    } catch (_) {
      setState(() {
        _currentLocation = null;
        _locationStatus = "현재 위치를 가져오지 못했습니다.";
        _loadingLocation = false;
      });
    }
  }

  void _submitSearch(CampusMapData data, String query) {
    final CampusLookupResult result = CampusRoomParser(data).resolve(query);
    setState(() {
      _lookupResult = result;
      _selectedBuilding = result.building;
    });

    final CampusBuilding? building = result.building;
    if (building != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapKey.currentState?.focusOn(building.location);
      });
    }
  }

  void _selectBuilding(CampusBuilding building) {
    setState(() {
      _selectedBuilding = building;
      _lookupResult = CampusLookupResult.alias(
        CampusAlias(
          query: building.name,
          building: building,
          floor: null,
          message: "${building.name} 건물입니다. ${building.description}",
        ),
      );
    });
    _showBuildingSheet(building);
  }

  void _setMockLocation({
    required LatLng location,
    required String label,
    CampusBuilding? focusBuilding,
  }) {
    setState(() {
      _mockLocationEnabled = true;
      _mockLocationLabel = label;
      _currentLocation = location;
      _locationStatus = "모의 위치($label)를 표시 중입니다.";
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapKey.currentState?.focusOn(focusBuilding?.location ?? location);
    });
  }

  Future<void> _showMockLocationSheet(CampusMapData data) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "집에서 테스트용 위치",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  "GPS 대신 지도 위의 임의 위치를 '현재 위치'로 표시합니다.",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final CampusBuilding b in data.buildings)
                      ActionChip(
                        label: Text(b.name),
                        onPressed: () {
                          Navigator.pop(context);
                          _setMockLocation(
                            location: b.location,
                            label: b.name,
                            focusBuilding: b,
                          );
                        },
                      ),
                    ActionChip(
                      label: const Text("캠퍼스 중앙"),
                      onPressed: () {
                        Navigator.pop(context);
                        _setMockLocation(
                          location: data.mapCenter,
                          label: "캠퍼스 중앙",
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_mockLocationEnabled) ...[
                  FilledButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      setState(() {
                        _mockLocationEnabled = false;
                        _mockLocationLabel = "";
                        _locationStatus = "모의 위치를 해제했습니다. GPS를 다시 확인합니다.";
                      });
                      await _loadCurrentLocation(data);
                    },
                    icon: const Icon(Icons.gps_fixed_rounded),
                    label: const Text("모의 위치 해제하고 GPS로 돌아가기"),
                  ),
                ] else ...[
                  FilledButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _loadCurrentLocation(data);
                    },
                    icon: const Icon(Icons.my_location_rounded),
                    label: const Text("지금 GPS로 위치 확인"),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showBuildingSheet(CampusBuilding building) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.apartment_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          building.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          "약칭 ${building.prefixes.join(", ")} · ${building.floors}층",
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                building.description.isEmpty
                    ? "${building.name} 건물로 이동하세요."
                    : building.description,
                style: const TextStyle(fontSize: 15, height: 1.45),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _mapKey.currentState?.focusOn(building.location);
                },
                icon: const Icon(Icons.center_focus_strong_rounded),
                label: const Text("약도에서 크게 보기"),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("캠퍼스 약도"),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Colors.white,
        actions: [
          FutureBuilder<CampusMapData>(
            future: _dataFuture,
            builder: (context, snapshot) {
              final CampusMapData? data = snapshot.data;
              return IconButton(
                tooltip: "집에서 테스트용 위치",
                onPressed:
                    data == null ? null : () => _showMockLocationSheet(data),
                icon: const Icon(Icons.tune_rounded),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<CampusMapData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const _ErrorState(message: "캠퍼스 약도 데이터를 불러오지 못했습니다.");
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final CampusMapData data = snapshot.data!;
          return AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return SizedBox.expand(
                child: Stack(
                  children: [
                    Positioned.fill(
                      top: 166,
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: CampusMapView(
                        key: _mapKey,
                        data: data,
                        selectedBuilding: _selectedBuilding,
                        lookupResult: _lookupResult,
                        currentLocation: _currentLocation,
                        locationPulse: _pulseController.value,
                        onBuildingTap: _selectBuilding,
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: _TopControls(
                        controller: _searchController,
                        lookupResult: _lookupResult,
                        locationStatus: _locationStatus,
                        loadingLocation: _loadingLocation,
                        onSubmitted: (query) => _submitSearch(data, query),
                        onLocate: () => _loadCurrentLocation(data),
                        onMockLocation: () => _showMockLocationSheet(data),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _TopControls extends StatelessWidget {
  const _TopControls({
    required this.controller,
    required this.lookupResult,
    required this.locationStatus,
    required this.loadingLocation,
    required this.onSubmitted,
    required this.onLocate,
    required this.onMockLocation,
  });

  final TextEditingController controller;
  final CampusLookupResult? lookupResult;
  final String locationStatus;
  final bool loadingLocation;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onLocate;
  final VoidCallback onMockLocation;

  @override
  Widget build(BuildContext context) {
    final CampusLookupResult? result = lookupResult;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: scheme.surface,
              elevation: 3,
              shadowColor: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
              borderRadius: BorderRadius.circular(18),
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.search,
                onSubmitted: onSubmitted,
                decoration: InputDecoration(
                  hintText: "위치를 모르는 강의실 검색",
                  hintStyle: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    tooltip: "검색",
                    icon: const Icon(Icons.arrow_forward_rounded),
                    onPressed: () => onSubmitted(controller.text),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _StatusCard(
              result: result,
              locationStatus: locationStatus,
              loadingLocation: loadingLocation,
              onLocate: onLocate,
              onMockLocation: onMockLocation,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.result,
    required this.locationStatus,
    required this.loadingLocation,
    required this.onLocate,
    required this.onMockLocation,
  });

  final CampusLookupResult? result;
  final String locationStatus;
  final bool loadingLocation;
  final VoidCallback onLocate;
  final VoidCallback onMockLocation;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool hasSearch = result != null && !result!.isEmpty;
    final bool isError = result?.isError == true;
    final String title = hasSearch
        ? (isError ? "검색 결과 없음" : result!.title)
        : "건물을 누르거나 호실을 검색하세요";
    final String subtitle =
        hasSearch ? result!.guidance : "예: 공512 → 공학관 5층 12호 안내";

    return Material(
      color: scheme.surface,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 13, 10, 13),
        child: Row(
          children: [
            Icon(
              isError ? Icons.info_outline_rounded : Icons.location_on_outlined,
              color: isError ? Colors.orange.shade700 : AppColors.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle.isEmpty ? locationStatus : subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    locationStatus,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.82),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: "테스트 위치 선택",
                  onPressed: onMockLocation,
                  icon: const Icon(Icons.tune_rounded),
                ),
                IconButton(
                  tooltip: "현재 위치 새로고침",
                  onPressed: loadingLocation ? null : onLocate,
                  icon: loadingLocation
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
