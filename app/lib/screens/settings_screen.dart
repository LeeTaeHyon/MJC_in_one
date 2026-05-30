import "dart:async";

import "package:flutter/material.dart";
import "package:mjc_in_one/home_dashboard_prefs.dart";
import "package:mjc_in_one/lab_prefs.dart";
import "package:mjc_in_one/lecture_reminder_notification_prefs.dart";
import "package:mjc_in_one/main_website_prefs.dart";
import "package:mjc_in_one/notification_sources.dart";
import "package:mjc_in_one/screens/common_webview_screen.dart";
import "package:mjc_in_one/screens/inquiry_screen.dart";
import "package:mjc_in_one/screens/keyword_notification_settings_screen.dart";
import "package:mjc_in_one/screens/open_source_licenses_screen.dart";
import "package:mjc_in_one/screens/phone_permissions_screen.dart";
import "package:mjc_in_one/services/app_cache_service.dart";
import "package:mjc_in_one/services/lecture_reminder_notification_service.dart";
import "package:mjc_in_one/services/legal_consent_service.dart";
import "package:mjc_in_one/services/notice_filter.dart";
import "package:mjc_in_one/services/user_data_repository.dart";
import "package:mjc_in_one/theme/theme_mode_scope.dart";
import "package:mjc_in_one/utils/mjc_snack_bar.dart";
import "package:mjc_in_one/widgets/safe_tooltip.dart";
import "package:mjc_in_one/widgets/scroll_to_top_fab.dart";
import "package:mjc_in_one/widgets/scroll_to_top_scope.dart";
import "package:shared_preferences/shared_preferences.dart";

/// 설정 화면 섹션·카드 항목 제목.
const Color _settingsSectionTitleColor = Color(0xFF374151);
const Color _settingsSectionTitleColorDark = Color(0xFFD1D5DB);

TextStyle _settingsItemTitleStyle(
  BuildContext context, {
  FontWeight? fontWeight,
  double? fontSize,
  double? height,
}) {
  final TextStyle base = (Theme.of(context).listTileTheme.titleTextStyle ??
          Theme.of(context).textTheme.titleMedium!)
      .copyWith(
    fontWeight: fontWeight,
    fontSize: fontSize,
    height: height,
  );
  final Color color = Theme.of(context).brightness == Brightness.light
      ? _settingsSectionTitleColor
      : _settingsSectionTitleColorDark;
  return base.copyWith(color: color);
}

/// 설정 화면 보조 텍스트 (설명·ListTile subtitle 등).
const Color _settingsSubtitleColor = Color(0xFF6B7280);
const Color _settingsSubtitleColorDark = Color(0xFF9CA3AF);

TextStyle _settingsSubtitleStyle(
  BuildContext context, {
  double? fontSize,
  double? height,
  FontWeight? fontWeight,
}) {
  final TextStyle base = (Theme.of(context).listTileTheme.subtitleTextStyle ??
          Theme.of(context).textTheme.bodyMedium!)
      .copyWith(
    fontSize: fontSize,
    height: height,
    fontWeight: fontWeight,
  );
  final Color color = Theme.of(context).brightness == Brightness.light
      ? _settingsSubtitleColor
      : _settingsSubtitleColorDark;
  return base.copyWith(color: color);
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// 설정 화면 본문·카드 구분용 (참고 UI와 유사한 톤).
  static const Color _pageBackground = Color(0xFFF5F7F9);
  static const Color _cardBorder = Color(0xFFEDEDED);
  bool _allNoticesEnabled = true;
  bool _lectureReminderNotificationEnabled = false;
  List<String> _keywords = [];
  List<String> _enabledSources = List<String>.from(kNotificationSourceIds);
  Set<String> _homeDashboardEnabledSections =
      defaultHomeDashboardEnabledSections().toSet();
  List<String> _homeDashboardSectionOrder = defaultHomeDashboardSectionOrder();
  MainWebsiteNoticeViewMode _mainWebsiteNoticeViewMode =
      MainWebsiteNoticeViewMode.unified;
  final ScrollController _scrollController = ScrollController();
  ScrollToTopCoordinator? _scrollRouteCoordinator;
  bool _registeredScrollRoute = false;

  int _estimatedCacheBytes = 0;
  bool _clearingCache = false;
  bool _labDepartmentNoticesEnabled = false;

  static const Duration _adminHiddenTapResetDelay = Duration(seconds: 2);
  int _adminHiddenTapCount = 0;
  Timer? _adminHiddenTapResetTimer;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _refreshEstimatedCacheSize();
    _scrollController.addListener(_onSettingsScroll);
  }

  Future<void> _refreshEstimatedCacheSize() async {
    try {
      final int bytes = await AppCacheService.estimateCacheBytes();
      if (!mounted) return;
      setState(() => _estimatedCacheBytes = bytes);
    } catch (_) {
      // 표시용 추정치 — 실패 시 0 유지.
    }
  }

  Future<void> _openPrivacyPolicy() async {
    final NavigatorState navigator = Navigator.of(context);
    final String url =
        await LegalConsentService.instance.resolvePrivacyUrl();
    if (!mounted) return;
    navigator.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CommonWebViewScreen(
          url: url,
          title: "개인정보처리방침",
        ),
      ),
    );
  }

  void _onSettingsScroll() {
    if (!mounted) return;
    _scrollRouteCoordinator?.reportRouteScroll(
      _scrollController.offset,
      ScrollFabMetrics.viewportHeightInScrollListener(_scrollController),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_registeredScrollRoute) return;
    final ScrollToTopCoordinator? c = ScrollToTopScope.maybeOf(context);
    if (c != null) {
      _scrollRouteCoordinator = c;
      c.pushRouteHandler(_scrollContentToTop);
      _registeredScrollRoute = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        c.reportRouteScroll(
          _scrollController.offset,
          ScrollFabMetrics.viewportHeightForThreshold(
              _scrollController, context),
        );
      });
    }
  }

  void _scrollContentToTop() {
    if (!_scrollController.hasClients) return;
    for (final position in _scrollController.positions) {
      position.animateTo(
        0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _adminHiddenTapResetTimer?.cancel();
    _scrollController.removeListener(_onSettingsScroll);
    if (_registeredScrollRoute) {
      _scrollRouteCoordinator?.popRouteHandler();
    }
    _scrollController.dispose();
    super.dispose();
  }

  void _onVersionTextTap() {
    _adminHiddenTapResetTimer?.cancel();
    _adminHiddenTapCount++;
    if (_adminHiddenTapCount >= 5) {
      _adminHiddenTapCount = 0;
      Navigator.of(context).pushNamed("/admin");
      return;
    }
    _adminHiddenTapResetTimer = Timer(_adminHiddenTapResetDelay, () {
      _adminHiddenTapCount = 0;
    });
  }

  /// 설정값 로드
  Future<void> _loadSettings() async {
    await LabPrefs.ensureLoaded();
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _labDepartmentNoticesEnabled = LabPrefs.departmentNoticesEnabled.value;
      _allNoticesEnabled = prefs.getBool("allNoticesEnabled") ?? true;
      _lectureReminderNotificationEnabled =
          prefs.getBool(kLectureReminderNotificationEnabledPrefKey) ?? false;
      _keywords = prefs.getStringList("keywords") ?? [];
      final stored = prefs.getStringList(kNotificationSourcesPrefKey);
      if (stored == null || stored.isEmpty) {
        _enabledSources = defaultNotificationSources();
      } else {
        _enabledSources =
            kNotificationSourceIds.where((id) => stored.contains(id)).toList();
        if (_enabledSources.isEmpty) {
          _enabledSources = defaultNotificationSources();
        }
      }

      _homeDashboardEnabledSections = (prefs
                  .getStringList(kHomeDashboardEnabledSectionsPrefKey) ??
              defaultHomeDashboardEnabledSections())
          .toSet();

      _homeDashboardSectionOrder =
          (prefs.getStringList(kHomeDashboardSectionOrderPrefKey) ??
                  defaultHomeDashboardSectionOrder())
              .where(allowedHomeDashboardSectionIds().contains)
              .toList();
      if (_homeDashboardSectionOrder.isEmpty) {
        _homeDashboardSectionOrder = defaultHomeDashboardSectionOrder();
      } else {
        // 누락된 섹션은 뒤에 붙입니다.
        final Set<String> seen = _homeDashboardSectionOrder.toSet();
        for (final s in HomeDashboardSection.values) {
          if (!seen.contains(s.id)) _homeDashboardSectionOrder.add(s.id);
        }
      }

      _mainWebsiteNoticeViewMode = MainWebsitePrefs.decodeViewMode(
        prefs.getString(kMainWebsiteNoticeViewModePrefKey),
      );
    });
  }

  Future<void> _setMainWebsiteNoticeViewMode(
    MainWebsiteNoticeViewMode next,
  ) async {
    if (next == _mainWebsiteNoticeViewMode) return;
    await MainWebsitePrefs.setNoticeViewMode(next);
    try {
      await UserDataRepository.instance.pushSnapshotToCloud();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _mainWebsiteNoticeViewMode = next);
  }

  /// 메인 탭의 [BottomAppBar] 높이와 맞춤. SnackBar가 라우트 아래로 남아도 네비를 가리지 않게 함.
  EdgeInsets _snackBarMargin(BuildContext context) {
    const double mainBottomNavHeight = 10;
    final double safeBottom = MediaQuery.paddingOf(context).bottom;
    return EdgeInsets.fromLTRB(
        16, 0, 16, safeBottom + mainBottomNavHeight + 12);
  }

  /// 전체 알림 스위치 저장
  Future<void> _toggleAllNotices(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("allNoticesEnabled", value);
    try {
      await UserDataRepository.instance.pushSnapshotToCloud();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _allNoticesEnabled = value;
    });
    if (mounted) {
      final bool allOff = !value && _keywords.isEmpty;
      final message = allOff
          ? "알람이 꺼집니다."
          : (value ? "전체 알림이 활성화되었습니다." : "전체 알림이 비활성화되었습니다.");
      showUniqueMjcSnackBar(
        context,
        key: "settings_all_notices_${value ? "on" : "off"}",
        message: message,
        margin: _snackBarMargin(context),
      );
    }
  }

  /// [kNoticeFilterSourceOptions] 라벨(MJC·CTL·MPU) ↔ FCM `source` id.
  String _notificationSourceIdForChip(String chipLabel) {
    switch (chipLabel) {
      case "MJC":
        return "mjc";
      case "CTL":
        return "ctl";
      case "MPU":
        return "mpu";
      default:
        return "";
    }
  }

  List<String> _selectedNotificationSourceChipLabels() {
    return kNoticeFilterSourceOptions
        .where(
          (String label) =>
              _enabledSources.contains(_notificationSourceIdForChip(label)),
        )
        .toList();
  }

  Future<void> _toggleNotificationSourceChip(
      String label, bool selected) async {
    final String id = _notificationSourceIdForChip(label);
    if (id.isEmpty) return;
    await _setSourceEnabled(id, selected);
  }

  Future<void> _setSourceEnabled(String sourceId, bool enabled) async {
    if (!kNotificationSourceIds.contains(sourceId)) return;
    final next = Set<String>.from(_enabledSources);
    if (enabled) {
      next.add(sourceId);
    } else {
      next.remove(sourceId);
    }
    if (next.isEmpty) {
      if (mounted) {
        showUniqueMjcSnackBar(
          context,
          key: "settings_sources_min_one",
          message: "알림 출처는 최소 하나 선택해야 합니다.",
          margin: _snackBarMargin(context),
        );
      }
      return;
    }
    final ordered =
        kNotificationSourceIds.where((id) => next.contains(id)).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(kNotificationSourcesPrefKey, ordered);
    await UserDataRepository.instance.updateSources(ordered);
    if (!mounted) return;
    setState(() => _enabledSources = ordered);
  }

  Future<void> _openKeywordNotificationSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const KeywordNotificationSettingsScreen(),
      ),
    );
    if (!mounted) return;
    await _loadSettings();
  }

  /// 개발자 문의 — Firestore `developer_inquiries` 컬렉션으로 직접 전송됩니다.
  Future<void> _contactDeveloper() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const InquiryScreen()),
    );
  }

  Future<void> _confirmAndClearAppCache() async {
    if (_clearingCache) return;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("캐시 데이터 지우기"),
          content: const Text(
            "식단·셔틀·캠퍼스맵·공지 목록 등 임시 데이터를 삭제합니다.\n\n"
            "다음 사용 시 서버에서 다시 받아옵니다. 알림 설정, 북마크, 시간표, 프로필은 유지됩니다.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text("취소"),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text("지우기"),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    setState(() => _clearingCache = true);
    try {
      await AppCacheService.clearAppCache();
      await _refreshEstimatedCacheSize();
      if (!mounted) return;
      showUniqueMjcSnackBar(
        context,
        key: "settings_cache_cleared",
        message: "캐시 데이터를 삭제했습니다.",
        margin: _snackBarMargin(context),
      );
    } catch (_) {
      if (!mounted) return;
      showUniqueMjcSnackBar(
        context,
        key: "settings_cache_clear_failed",
        message: "캐시 삭제에 실패했습니다. 잠시 후 다시 시도해 주세요.",
        margin: _snackBarMargin(context),
      );
    } finally {
      if (mounted) setState(() => _clearingCache = false);
    }
  }

  Widget _buildNotificationSourceSelector() {
    final Set<String> selected =
        _selectedNotificationSourceChipLabels().toSet();
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<String>(
        expandedInsets: EdgeInsets.zero,
        multiSelectionEnabled: true,
        emptySelectionAllowed: true,
        segments: kNotificationSourceChipLabels
            .map(
              (String label) => ButtonSegment<String>(
                value: label,
                label: Text(
                  notificationSourceDisplayLabel(label),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                icon: Icon(notificationSourceDisplayIcon(label)),
              ),
            )
            .toList(),
        selected: selected,
        onSelectionChanged: (Set<String> next) {
          for (final String label in kNotificationSourceChipLabels) {
            final bool wasSelected = selected.contains(label);
            final bool isSelected = next.contains(label);
            if (wasSelected != isSelected) {
              _toggleNotificationSourceChip(label, isSelected);
              return;
            }
          }
        },
      ),
    );
  }

  Widget _settingsCard({required Widget child}) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool light = Theme.of(context).brightness == Brightness.light;
    return Material(
      color: scheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: light ? _cardBorder : scheme.outline.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _hairlineDivider() {
    final bool light = Theme.of(context).brightness == Brightness.light;
    return Divider(
      height: 1,
      thickness: 1,
      color: light
          ? _cardBorder
          : Theme.of(context).colorScheme.outline.withValues(alpha: 0.35),
    );
  }

  Future<void> _setHomeDashboardSectionEnabled(
    HomeDashboardSection section,
    bool enabled,
  ) async {
    final Set<String> next = {..._homeDashboardEnabledSections};
    if (enabled) {
      next.add(section.id);
    } else {
      next.remove(section.id);
      if (next.isEmpty) {
        if (mounted) {
          showUniqueMjcSnackBar(
            context,
            key: "settings_home_dashboard_sections_min_one",
            message: "홈 대시보드 요소는 최소 하나 선택해야 합니다.",
            margin: _snackBarMargin(context),
          );
        }
        return;
      }
    }

    await saveHomeDashboardEnabledSections(next);
    try {
      await UserDataRepository.instance.pushSnapshotToCloud();
    } catch (_) {
      // 클라우드 동기화 실패는 로컬 저장에 영향 없음 — 무시합니다.
    }
    if (!mounted) return;
    setState(() => _homeDashboardEnabledSections = next);
  }

  Future<void> _setHomeDashboardSectionOrder(List<String> order) async {
    await saveHomeDashboardSectionOrder(order);
    try {
      await UserDataRepository.instance.pushSnapshotToCloud();
    } catch (_) {
      // 클라우드 동기화 실패는 로컬 저장에 영향 없음 — 무시합니다.
    }
    if (!mounted) return;
    setState(() => _homeDashboardSectionOrder = order);
  }

  Future<void> _openHomeDashboardOrderEditor() async {
    final List<String> base = List<String>.from(_homeDashboardSectionOrder);
    final List<String>? result = await showModalBottomSheet<List<String>>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                MediaQuery.paddingOf(ctx).bottom + 12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          "홈 대시보드 순서 편집",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(null),
                        icon: const SafeTooltip(
                          message: "닫기",
                          child: Icon(Icons.close_rounded),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "드래그해서 순서를 바꿀 수 있어요. (꺼진 항목도 순서는 유지됩니다)",
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ReorderableListView.builder(
                      shrinkWrap: true,
                      buildDefaultDragHandles: false,
                      itemCount: base.length,
                      onReorder: (oldIndex, newIndex) {
                        setSheetState(() {
                          if (newIndex > oldIndex) newIndex -= 1;
                          final String item = base.removeAt(oldIndex);
                          base.insert(newIndex, item);
                        });
                      },
                      itemBuilder: (ctx, index) {
                        final String id = base[index];
                        final HomeDashboardSection section =
                            HomeDashboardSection.values.firstWhere(
                          (s) => s.id == id,
                          orElse: () => HomeDashboardSection.quickButtons,
                        );
                        final bool on =
                            _homeDashboardEnabledSections.contains(section.id);
                        return ListTile(
                          key: ValueKey<String>("home_dash_order_$id"),
                          leading: ReorderableDragStartListener(
                            index: index,
                            child: Icon(
                              Icons.drag_handle_rounded,
                              color: Theme.of(ctx)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.45),
                            ),
                          ),
                          title: Opacity(
                            opacity: on ? 1 : 0.55,
                            child: Text(
                              section.label,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          subtitle: on ? null : const Text("현재 숨김"),
                          trailing: Icon(
                            on
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: Theme.of(ctx)
                                .colorScheme
                                .onSurfaceVariant
                                .withValues(alpha: on ? 0.75 : 0.55),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(null),
                          child: const Text("취소"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.of(ctx).pop(base),
                          child: const Text("저장"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result == null) return;
    await _setHomeDashboardSectionOrder(result);
  }

  Widget _buildHomeDashboardSectionVisibilityCard() {
    return _settingsCard(
      child: Column(
        children: [
          ListTile(
            title: Text(
              "홈에 표시할 요소 선택",
              style: _settingsItemTitleStyle(
                context,
                fontWeight: FontWeight.w700,
                fontSize: 15,
                height: 1.25,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                "홈 화면에 표시할 카드/섹션을 선택할 수 있습니다.",
                style: _settingsSubtitleStyle(
                  context,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ),
            trailing: OutlinedButton.icon(
              onPressed: _openHomeDashboardOrderEditor,
              icon: const Icon(Icons.swap_vert_rounded),
              label: const Text("순서 편집"),
              style: Theme.of(context).brightness == Brightness.dark
                  ? OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                    )
                  : null,
            ),
          ),
          _hairlineDivider(),
          ...HomeDashboardSection.values.expand((section) {
            final bool on = _homeDashboardEnabledSections.contains(section.id);
            return [
              SwitchListTile(
                title: Text(section.label),
                value: on,
                onChanged: (value) =>
                    _setHomeDashboardSectionEnabled(section, value),
              ),
              if (section != HomeDashboardSection.values.last)
                _hairlineDivider(),
            ];
          }),
        ],
      ),
    );
  }

  Widget _buildMainWebsiteNoticeViewModeCard() {
    return _settingsCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "본교 공지사항 보기 방식",
              style: _settingsItemTitleStyle(
                context,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "본교 공지사항을 탭으로 나눠 볼지, 한 게시판으로 통합해서 볼지 선택합니다.",
              style: _settingsSubtitleStyle(
                context,
                fontSize: 12,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<MainWebsiteNoticeViewMode>(
                expandedInsets: EdgeInsets.zero,
                segments: const [
                  ButtonSegment<MainWebsiteNoticeViewMode>(
                    value: MainWebsiteNoticeViewMode.tabs,
                    label: Text("탭"),
                    icon: Icon(Icons.tab_rounded),
                  ),
                  ButtonSegment<MainWebsiteNoticeViewMode>(
                    value: MainWebsiteNoticeViewMode.unified,
                    label: Text("통합"),
                    icon: Icon(Icons.view_agenda_outlined),
                  ),
                ],
                selected: {_mainWebsiteNoticeViewMode},
                onSelectionChanged: (s) {
                  final next =
                      s.isEmpty ? MainWebsiteNoticeViewMode.tabs : s.first;
                  _setMainWebsiteNoticeViewMode(next);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeModeController? themeController =
        ThemeModeScope.maybeOf(context);
    final ThemeMode themeMode = themeController?.value ?? ThemeMode.system;
    final bool allNotices = _allNoticesEnabled;
    final bool notificationsAllOff = !allNotices && _keywords.isEmpty;

    final Color scaffoldBg = Theme.of(context).brightness == Brightness.light
        ? _pageBackground
        : Theme.of(context).colorScheme.surfaceContainerLow;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: const Text("설정"),
      ),
      body: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          const _SectionHeader(
            title: "알림",
            icon: Icons.notifications_outlined,
          ),
          _settingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  title: Text(
                    "전체 알람",
                    style: _settingsItemTitleStyle(context),
                  ),
                  subtitle: Text(
                    allNotices
                        ? "모든 공지사항 새글 알림 받기"
                        : "꺼 두면 등록한 키워드가 포함된 공지만 알림을 받습니다.",
                    style: _settingsSubtitleStyle(context),
                  ),
                  value: allNotices,
                  onChanged: _toggleAllNotices,
                ),
                ClipRect(
                  child: AnimatedAlign(
                    alignment: Alignment.topCenter,
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    heightFactor: allNotices ? 1.0 : 0.0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _hairlineDivider(),
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(16, 14, 16, 6),
                          child: Text(
                            "알림 받을 출처",
                            style: _settingsItemTitleStyle(
                              context,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(16, 0, 16, 6),
                          child: Text(
                            "전체 알람에만 적용됩니다. 키워드 알림에는 적용되지 않습니다.",
                            style: _settingsSubtitleStyle(
                              context,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(16, 0, 16, 14),
                          child: _buildNotificationSourceSelector(),
                        ),
                      ],
                    ),
                  ),
                ),
                if (notificationsAllOff) ...[
                  _hairlineDivider(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    child: Row(
                      children: [
                        Icon(
                          Icons.notifications_off_outlined,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.72),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "알람이 꺼집니다.",
                            style: _settingsSubtitleStyle(
                              context,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _settingsCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                    child: Text(
                      "키워드 관리",
                      style: _settingsItemTitleStyle(
                        context,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Text(
                      allNotices
                          ? "전체 알람이 켜져 있으면 키워드와 관계없이 모든 공지를 받습니다."
                          : "키워드가 없으면 알림이 오지 않습니다.",
                      style: _settingsSubtitleStyle(
                        context,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  ListTile(
                    title: Text(
                      "키워드 알림 설정",
                      style: _settingsItemTitleStyle(context),
                    ),
                    subtitle: Text(
                      _keywords.isEmpty
                          ? "현재 등록된 키워드 없음"
                          : "${_keywords.length}개 키워드 감시 중",
                      style: _settingsSubtitleStyle(context),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _openKeywordNotificationSettings,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const _SectionHeader(
            title: "화면",
            icon: Icons.palette_outlined,
          ),
          const SizedBox(height: 10),
          _buildMainWebsiteNoticeViewModeCard(),
          const SizedBox(height: 12),
          _buildHomeDashboardSectionVisibilityCard(),
          const SizedBox(height: 16),
          _settingsCard(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "앱 화면 테마",
                    style: _settingsItemTitleStyle(
                      context,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      expandedInsets: EdgeInsets.zero,
                      segments: const [
                        ButtonSegment<ThemeMode>(
                          value: ThemeMode.light,
                          label: Text("라이트"),
                          icon: Icon(Icons.light_mode_outlined),
                        ),
                        ButtonSegment<ThemeMode>(
                          value: ThemeMode.dark,
                          label: Text("다크"),
                          icon: Icon(Icons.dark_mode_outlined),
                        ),
                        ButtonSegment<ThemeMode>(
                          value: ThemeMode.system,
                          label: Text("자동"),
                          icon: Icon(Icons.settings_suggest_outlined),
                        ),
                      ],
                      selected: {themeMode},
                      onSelectionChanged: (s) {
                        final ThemeMode next =
                            s.isEmpty ? ThemeMode.system : s.first;
                        if (themeController == null) return;
                        themeController.setAndPersist(next);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const _SectionHeader(
            title: "실험실",
            icon: Icons.science_outlined,
          ),
          const SizedBox(height: 10),
          _settingsCard(
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(
                    "학과 공지 (실험)",
                    style: _settingsItemTitleStyle(context),
                  ),
                  subtitle: Text(
                    "비공식 참고용 학과 공지 탭을 표시합니다.\n일부 학과만 글이 있을 수 있습니다.",
                    style: _settingsSubtitleStyle(context),
                  ),
                  value: _labDepartmentNoticesEnabled,
                  onChanged: (bool value) async {
                    final EdgeInsets snackMargin = _snackBarMargin(context);
                    await LabPrefs.setDepartmentNoticesEnabled(value);
                    if (!mounted) return;
                    setState(() => _labDepartmentNoticesEnabled = value);
                    if (value) {
                      showMjcSnackBar(
                        context,
                        message: "공지 탭에 「학과」 메뉴가 표시됩니다.",
                        margin: snackMargin,
                      );
                    }
                  },
                ),
                _hairlineDivider(),
                SwitchListTile(
                  title: Text(
                    "강의 알림 (실험)",
                    style: _settingsItemTitleStyle(context),
                  ),
                  subtitle: Text(
                    "다음 수업까지 남은 시간을 알림 패널에 표시합니다.\n"
                    "기능이 불완전할 수 있습니다.",
                    style: _settingsSubtitleStyle(context),
                  ),
                  value: _lectureReminderNotificationEnabled,
                  onChanged: (bool value) async {
                    final EdgeInsets snackMargin = _snackBarMargin(context);
                    if (value) {
                      final bool granted =
                          await LectureReminderNotificationService.instance
                              .requestPermissions();
                      if (!mounted) return;
                      if (!granted) {
                        showUniqueMjcSnackBar(
                          context,
                          key: "settings_lecture_reminder_permission",
                          message: "알림 권한이 필요합니다. 시스템 설정에서 허용해 주세요.",
                          margin: snackMargin,
                        );
                        return;
                      }
                    }
                    await LectureReminderNotificationService.instance
                        .setEnabled(value);
                    if (!mounted) return;
                    setState(
                        () => _lectureReminderNotificationEnabled = value);
                    showUniqueMjcSnackBar(
                      context,
                      key: "settings_lecture_reminder_${value ? "on" : "off"}",
                      message: value
                          ? "강의 알림이 알림 패널에 표시됩니다."
                          : "강의 알림 패널 표시를 껐습니다.",
                      margin: snackMargin,
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _SectionHeader(
            title: "저장 공간",
            icon: Icons.storage_outlined,
          ),
          const SizedBox(height: 10),
          _settingsCard(
            child: ListTile(
              title: Text(
                "캐시 데이터 지우기",
                style: _settingsItemTitleStyle(context),
              ),
              subtitle: Text(
                _estimatedCacheBytes > 0
                    ? "임시 데이터 약 ${AppCacheService.formatCacheSize(_estimatedCacheBytes)} · "
                        "식단·셔틀·지도 등 다시 받아옵니다"
                    : "식단·셔틀·지도·공지 목록 등 임시 데이터를 삭제합니다",
                style: _settingsSubtitleStyle(context),
              ),
              trailing: _clearingCache
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline_rounded),
              onTap: _clearingCache ? null : _confirmAndClearAppCache,
            ),
          ),
          const SizedBox(height: 16),
          const _SectionHeader(
            title: "앱 정보",
            icon: Icons.info_outline_rounded,
          ),
          _settingsCard(
            child: Column(
              children: [
                ListTile(
                  title: Text(
                    "휴대폰 권한",
                    style: _settingsItemTitleStyle(context),
                  ),
                  subtitle: Text(
                    "알림·위치·배터리 등 권한 상태 확인",
                    style: _settingsSubtitleStyle(context),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const PhonePermissionsScreen(),
                      ),
                    );
                  },
                ),
                _hairlineDivider(),
                ListTile(
                  title: Text(
                    "앱 버전",
                    style: _settingsItemTitleStyle(context),
                  ),
                  trailing: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _onVersionTextTap,
                    child: const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Text("1.0.0 (Alpha)"),
                    ),
                  ),
                ),
                _hairlineDivider(),
                ListTile(
                  title: Text(
                    "개발자에게 문의하기",
                    style: _settingsItemTitleStyle(context),
                  ),
                  subtitle: Text(
                    "불편한 점이나 건의사항을 보내주세요.",
                    style: _settingsSubtitleStyle(context),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _contactDeveloper,
                ),
                _hairlineDivider(),
                ListTile(
                  title: Text(
                    "오픈소스 라이선스",
                    style: _settingsItemTitleStyle(context),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (context) => const OpenSourceLicensesScreen(),
                      ),
                    );
                  },
                ),
                _hairlineDivider(),
                ListTile(
                  title: Text(
                    "개인정보처리방침",
                    style: _settingsItemTitleStyle(context),
                  ),
                  subtitle: Text(
                    "수집 항목과 이용 목적을 확인할 수 있습니다.",
                    style: _settingsSubtitleStyle(context),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _openPrivacyPolicy,
                ),
              ],
            ),
          ),
        ],
        ),
          ),
          const PushedRouteScrollToTopLayer(),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.icon});

  final String title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    final Color accent =
        dark ? _settingsSectionTitleColorDark : _settingsSectionTitleColor;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 0, 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: accent),
            const SizedBox(width: 8),
          ],
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: accent,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}
