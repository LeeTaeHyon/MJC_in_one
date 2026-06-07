import "dart:async";

import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:mjc_in_one/features/timetable/screens/timetable_main_screen.dart";
import "package:mjc_in_one/screens/home_dashboard_screen.dart";
import "package:mjc_in_one/screens/my_page_screen.dart";
import "package:mjc_in_one/lab_prefs.dart";
import "package:mjc_in_one/screens/notices_sub_tab_utils.dart";
import "package:mjc_in_one/screens/notices_tab_screen.dart";
import "package:mjc_in_one/screens/profile_setup_screen.dart";
import "package:mjc_in_one/services/auth_service.dart";
import "package:mjc_in_one/services/connectivity_service.dart";
import "package:mjc_in_one/services/user_data_repository.dart";
import "package:mjc_in_one/debug/app_debug_flags.dart";
import "package:mjc_in_one/debug/scroll_fab_debug.dart";
import "package:mjc_in_one/utils/bookmark_added_feedback.dart";
import "package:mjc_in_one/widgets/main_navigation_scope.dart";
import "package:mjc_in_one/widgets/mjc_directional_screen_transition.dart";
import "package:mjc_in_one/widgets/mjc_draggable_segment_pill_bar.dart";
import "package:mjc_in_one/widgets/scroll_to_top_fab.dart";
import "package:mjc_in_one/widgets/scroll_to_top_scope.dart";
import "package:mjc_in_one/theme/app_theme.dart";
import "package:shared_preferences/shared_preferences.dart";

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  static const Duration _navSwapDuration = Duration(milliseconds: 280);
  static const Curve _navSwapCurve = Curves.easeInOutCubic;
  static const Offset _navHiddenSlideOffset = Offset(0, 1);

  static const double _bottomNavContentLiftFactor = 0.02;
  static const double _noticeSubNavHeight = 44;
  static const double _noticeSubNavBottomGap = 8;
  static const double _noticeSubNavFabGap = 16;
  static const double _floatingNavBackSize = 36;

  static const List<_BottomNavItem> _bottomNavItems = <_BottomNavItem>[
    _BottomNavItem(
      index: MainNavTabIndex.home,
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: "홈",
    ),
    _BottomNavItem(
      index: MainNavTabIndex.notices,
      icon: Icons.campaign_outlined,
      selectedIcon: Icons.campaign_rounded,
      label: "공지",
    ),
    _BottomNavItem(
      index: MainNavTabIndex.timetable,
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month_rounded,
      label: "시간표",
    ),
    _BottomNavItem(
      index: MainNavTabIndex.mypage,
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      label: "마이페이지",
    ),
  ];

  MjcComponentTokens get _components =>
      Theme.of(context).extension<MjcComponentTokens>()!;

  int _index = 0;
  /// 탭 전환 슬라이드 방향: +1 = 오른쪽→왼쪽(인덱스 증가), -1 = 왼쪽→오른쪽.
  int _tabSlideDirection = 1;
  int _myPageBookmarkTabIndex = 0;
  int _myPageNavigateEpoch = 0;
  bool _noticeSubNavVisible = true;
  Timer? _noticeSubNavRevealTimer;
  final List<int> _tabHistory = <int>[];
  final ValueNotifier<NoticesSubTab> _noticeSubTab =
      ValueNotifier<NoticesSubTab>(NoticesSubTab.main);
  StreamSubscription<User?>? _authHydrateSubscription;
  bool _initialAuthEventHandled = false;

  // ── 오프라인 배너 ──────────────────────────────────────────────────────────
  static const double _offlineBannerHeight = 38.0;
  static const Duration _onlineFeedbackDuration = Duration(milliseconds: 1500);

  /// 배너 가시성 (오프라인이거나 온라인 피드백 표시 중)
  bool _bannerVisible = false;
  /// true = 온라인(초록), false = 오프라인(회색)
  bool _bannerIsOnline = false;
  Timer? _onlineFeedbackTimer;

  void _onLabDepartmentNoticesChanged() {
    if (!LabPrefs.departmentNoticesEnabled.value &&
        _noticeSubTab.value == NoticesSubTab.dept) {
      _noticeSubTab.value = NoticesSubTab.main;
    }
  }

  void _handleNoticeSubTabChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    LabPrefs.departmentNoticesEnabled
        .addListener(_onLabDepartmentNoticesChanged);
    _noticeSubTab.addListener(_handleNoticeSubTabChanged);
    _authHydrateSubscription =
        AuthService.instance.authStateChanges().listen((User? user) async {
      // 첫 이벤트는 앱 재실행 시 기존 세션 복원이므로 프로필 입력을 띄우지 않는다.
      if (!_initialAuthEventHandled) {
        _initialAuthEventHandled = true;
        if (user == null) return;
        try {
          await UserDataRepository.instance.hydrateFromCloudOnLogin(user);
        } catch (e, st) {
          debugPrint("hydrateFromCloudOnLogin: $e\n$st");
        }
        return;
      }

      if (user == null) return;
      try {
        await UserDataRepository.instance.hydrateFromCloudOnLogin(user);
        if (!mounted) return;
        await ProfileSetupScreen.maybePush(Navigator.of(context));
      } catch (e, st) {
        debugPrint("hydrateFromCloudOnLogin: $e\n$st");
      }
    });
    _syncScrollCoordinatorTab();

    // 오프라인 배너: 연결 감시 시작 후 ValueNotifier 구독
    ConnectivityService.instance.start().then((_) {
      if (!mounted) return;
      // 최초 상태 반영
      _handleConnectivityChange(ConnectivityService.instance.isOnline);
    });
    ConnectivityService.instance.isOnlineNotifier
        .addListener(_onConnectivityNotifierChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkTestBuildWarning();
    });
  }

  Future<void> _checkTestBuildWarning() async {
    final bool showTestBuildDialog = AppDevFeatures.startupTestBuildWarning;
    final bool showInquiryOverlay = AppDevFeatures.startupInquiryFocusOverlay;
    if (!showTestBuildDialog && !showInquiryOverlay) return;

    final prefs = await SharedPreferences.getInstance();
    final bool shown = prefs.getBool("test_build_warning_shown") ?? false;
    if (!shown) {
      if (!mounted) return;

      if (showTestBuildDialog) {
        // 1. 테스트 빌드 안내 팝업 표시
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            final scheme = Theme.of(ctx).colorScheme;
            return PopScope(
              canPop: false,
              child: Dialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.science_rounded,
                          size: 48, color: scheme.primary),
                      const SizedBox(height: 16),
                      const Text(
                        "테스트 빌드 안내",
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "본 앱은 테스트 빌드이며, 오류나 오탈자가 발생할 수 있고 서비스 이용이 원활하지 않을 수 있습니다.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.4,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                          },
                          child: const Text("이해했습니다",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }

      await prefs.setBool("test_build_warning_shown", true);

      if (!mounted) return;

      if (!showInquiryOverlay) return;

      // 2. 팝업이 닫힌 후 배경 딤(Dim) 처리와 함께 피드백 버튼 포커싱 오버레이 표시
      final overlay = Overlay.maybeOf(context, rootOverlay: true);
      if (overlay == null) return;
      bool isRemoved = false;
      OverlayEntry? entry;

      void removeEntry() {
        if (!isRemoved) {
          isRemoved = true;
          entry?.remove();
        }
      }

      entry = OverlayEntry(
        builder: (context) {
          final safeBottom = MediaQuery.paddingOf(context).bottom;
          return Stack(
            fit: StackFit.expand,
            children: [
              // 배경을 어둡게 처리하여 main.dart의 Positioned 버튼을 돋보이게 함
              GestureDetector(
                onTap: removeEntry,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.75),
                ),
              ),
              // 포커싱 설명 풍선
              Positioned(
                left: 16,
                bottom: safeBottom + 145, // 90(버튼 띄움) + 40(버튼 크기) + 15(여백)
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "피드백이 필요하신가요?",
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "문의사항은 어디서나\n해당 버튼을 눌러 가능합니다.",
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer
                                .withValues(alpha: 0.9),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.south_west_rounded,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20),
                            const SizedBox(width: 8),
                            Text(
                              "아래의 버튼을 눌러보세요",
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
      overlay.insert(entry);

      // 6초 뒤 자동 제거
      Future.delayed(const Duration(seconds: 6), removeEntry);
    }
  }

  Widget _buildMainTab(int index) {
    switch (index) {
      case MainNavTabIndex.home:
        return HomeDashboardScreen(
          onNavigate: _onMenuItemClick,
        );
      case MainNavTabIndex.notices:
        return NoticesTabScreen(subTabNotifier: _noticeSubTab);
      case MainNavTabIndex.timetable:
        return const TimetableMainScreen();
      case MainNavTabIndex.mypage:
        return MyPageScreen(
          embedded: true,
          initialBookmarkTabIndex: _myPageBookmarkTabIndex,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  /// [build] 안에서 호출하면 맨 위로 FAB가 빌드 중 재빌드되어 예외가 나므로, 프레임 끝에서만 동기화합니다.
  void _syncScrollCoordinatorTab() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScrollToTopScope.maybeOf(context)?.setActiveMainTab(_index);
    });
  }

  @override
  void dispose() {
    LabPrefs.departmentNoticesEnabled
        .removeListener(_onLabDepartmentNoticesChanged);
    _noticeSubTab.removeListener(_handleNoticeSubTabChanged);
    _noticeSubNavRevealTimer?.cancel();
    _onlineFeedbackTimer?.cancel();
    ConnectivityService.instance.isOnlineNotifier
        .removeListener(_onConnectivityNotifierChanged);
    _authHydrateSubscription?.cancel();
    _noticeSubTab.dispose();
    super.dispose();
  }

  // ── 오프라인 배너 로직 ────────────────────────────────────────────────────

  void _onConnectivityNotifierChanged() {
    _handleConnectivityChange(ConnectivityService.instance.isOnline);
  }

  void _handleConnectivityChange(bool nowOnline) {
    if (!mounted) return;
    if (nowOnline) {
      // 오프라인 배너가 보이던 중에만 온라인 피드백 표시
      if (!_bannerVisible) return;
      _onlineFeedbackTimer?.cancel();
      setState(() {
        _bannerIsOnline = true; // 초록색으로 전환
      });
      _onlineFeedbackTimer = Timer(_onlineFeedbackDuration, () {
        if (!mounted) return;
        setState(() => _bannerVisible = false);
      });
    } else {
      // 오프라인: 피드백 타이머 취소하고 즉시 배너 표시
      _onlineFeedbackTimer?.cancel();
      setState(() {
        _bannerVisible = true;
        _bannerIsOnline = false;
      });
    }
  }

  void _hideNoticeSubNavDuringScroll() {
    _noticeSubNavRevealTimer?.cancel();
    if (_noticeSubNavVisible) {
      setState(() => _noticeSubNavVisible = false);
    }
  }

  void _scheduleNoticeSubNavReveal() {
    _noticeSubNavRevealTimer?.cancel();
    _noticeSubNavRevealTimer = Timer(const Duration(milliseconds: 320), () {
      if (!mounted || _index != MainNavTabIndex.notices) return;
      if (!_noticeSubNavVisible) {
        setState(() => _noticeSubNavVisible = true);
      }
    });
  }

  bool _handleMainScrollNotification(ScrollNotification notification) {
    if (_index != MainNavTabIndex.notices) return false;
    if (notification is ScrollStartNotification ||
        notification is ScrollUpdateNotification ||
        notification is OverscrollNotification) {
      _hideNoticeSubNavDuringScroll();
      _scheduleNoticeSubNavReveal();
    } else if (notification is ScrollEndNotification) {
      _scheduleNoticeSubNavReveal();
    }
    return false;
  }

  Object _mainTabChildKey(int index) {
    if (index == MainNavTabIndex.mypage) {
      return (MainNavTabIndex.mypage, _myPageNavigateEpoch);
    }
    return index;
  }

  void _setTabSlideDirection(int fromIndex, int toIndex) {
    _tabSlideDirection =
        MjcDirectionalScreenTransition.directionForStep(fromIndex, toIndex);
  }

  Widget _mainTabSlideTransition(Widget child, Animation<double> animation) {
    return MjcDirectionalScreenTransition.transitionBuilder(
      child: child,
      animation: animation,
      activeKey: _mainTabChildKey(_index),
      direction: _tabSlideDirection,
    );
  }

  void _onMenuItemClick(
    int index, {
    NoticesSubTab? noticesSubTab,
    int? myPageBookmarkTabIndex,
  }) {
    if (noticesSubTab != null) {
      if (noticesSubTab == NoticesSubTab.dept &&
          !LabPrefs.departmentNoticesEnabled.value) {
        _noticeSubTab.value = NoticesSubTab.main;
      } else {
        _noticeSubTab.value = noticesSubTab;
      }
    }
    if (index == MainNavTabIndex.mypage && myPageBookmarkTabIndex != null) {
      _myPageBookmarkTabIndex = myPageBookmarkTabIndex.clamp(0, 1);
      _myPageNavigateEpoch++;
    }
    final bool tabChanged = index != _index;
    setState(() {
      if (tabChanged) {
        _setTabSlideDirection(_index, index);
        if (index == 0) {
          _tabHistory.clear();
        } else {
          _tabHistory.add(_index);
        }
        _index = index;
        _noticeSubNavVisible = index == MainNavTabIndex.notices;
      }
    });
    if (tabChanged) {
      _syncScrollCoordinatorTab();
    }
  }

  /// 시스템 뒤로가기: 이전 메인 탭 → (공지 서브탭 본교) → 앱 종료 순.
  void _onSystemPopInvoked(bool didPop, Object? result) {
    if (didPop) return;

    if (_tabHistory.isNotEmpty) {
      setState(() {
        final int fromIndex = _index;
        _index = _tabHistory.removeLast();
        _setTabSlideDirection(fromIndex, _index);
      });
      _syncScrollCoordinatorTab();
      return;
    }
    if (_index == MainNavTabIndex.notices &&
        _noticeSubTab.value != NoticesSubTab.main) {
      _noticeSubTab.value = NoticesSubTab.main;
      return;
    }
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final Color scaffoldBackground = Theme.of(context).scaffoldBackgroundColor;
    final bool noticesFloatingNav = _index == MainNavTabIndex.notices;
    return MainNavigationScope(
      navigate: _onMenuItemClick,
      noticesFloatingNav: noticesFloatingNav,
      child: ValueListenableBuilder<int>(
        valueListenable: bookmarkSnackBarSubnavSuppressionCount,
        builder: (context, snackbarSuppression, _) {
          final bool showNoticeSubChrome = !noticesFloatingNav &&
              _index == MainNavTabIndex.notices &&
              _noticeSubTab.value != NoticesSubTab.main &&
              _noticeSubNavVisible &&
              snackbarSuppression == 0;
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: _onSystemPopInvoked,
            child: Scaffold(
              backgroundColor: scaffoldBackground,
              extendBody: true,
              body: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: ColoredBox(
                      color: scaffoldBackground,
                      child: NotificationListener<ScrollNotification>(
                        onNotification: _handleMainScrollNotification,
                        child: ClipRect(
                          child: AnimatedSwitcher(
                            duration:
                                MjcDirectionalScreenTransition.duration,
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            layoutBuilder: (Widget? currentChild,
                                List<Widget> previousChildren) {
                              return Stack(
                                fit: StackFit.expand,
                                clipBehavior: Clip.hardEdge,
                                children: <Widget>[
                                  ...previousChildren,
                                  if (currentChild != null) currentChild,
                                ],
                              );
                            },
                            transitionBuilder: _mainTabSlideTransition,
                            child: KeyedSubtree(
                              key: ValueKey<Object>(_mainTabChildKey(_index)),
                              child: _buildMainTab(_index),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildAnimatedBottomNavSwitcher(noticesFloatingNav),
                        _buildNetworkBanner(),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: MainNavLayout.bottomInset(context) +
                        _noticeSubNavBottomGap,
                    child: IgnorePointer(
                      ignoring: !showNoticeSubChrome,
                      child: AnimatedSlide(
                        offset: showNoticeSubChrome
                            ? Offset.zero
                            : const Offset(0, 0.55),
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                        child: AnimatedOpacity(
                          opacity: showNoticeSubChrome ? 1 : 0,
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          child: _buildNoticeSubNav(),
                        ),
                      ),
                    ),
                  ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    right: 14,
                    bottom: MainNavLayout.bottomInset(context) +
                        10 +
                        (showNoticeSubChrome
                            ? _noticeSubNavBottomGap +
                                _noticeSubNavHeight +
                                _noticeSubNavFabGap
                            : 0),
                    child: ScrollToTopFab(
                      debugTag: ScrollFabDebug.enabled ? "mainNav" : null,
                    ),
                  ),
                ],
              ),
              bottomNavigationBar: null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildNetworkBanner() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // 오프라인 색상 (어두운 베이지/차콜)
    final Color offlineBg = isDark
        ? const Color(0xFF2A2A2E)
        : const Color(0xFF3A3A3F);
    const Color offlineFg = Color(0xFFCCCCCC);

    // 온라인 색상 (초록)
    final Color onlineBg = isDark
        ? const Color(0xFF14532D)
        : const Color(0xFF16A34A);
    const Color onlineFg = Color(0xFFDCFCE7);

    final Color bg = _bannerIsOnline ? onlineBg : offlineBg;
    final Color fg = _bannerIsOnline ? onlineFg : offlineFg;
    final IconData icon = _bannerIsOnline
        ? Icons.wifi_rounded
        : Icons.wifi_off_rounded;
    final String label = _bannerIsOnline ? "인터넷에 연결됨" : "오프라인 상태입니다";

    return ClipRect(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        height: _bannerVisible ? _offlineBannerHeight : 0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          color: bg,
          height: _offlineBannerHeight,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Row(
              key: ValueKey<bool>(_bannerIsOnline),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 15, color: fg),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedBottomNavSwitcher(bool showNoticeNav) {
    final double bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final double navSlotHeight = MainNavLayout.barHeight + bottomSafe;
    Widget wrapNavSlot(Widget child) {
      return SizedBox(
        height: navSlotHeight,
        width: double.infinity,
        child: child,
      );
    }

    return ClipRect(
      child: SizedBox(
        height: navSlotHeight,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          fit: StackFit.expand,
          children: <Widget>[
            AnimatedSlide(
              duration: _navSwapDuration,
              curve: _navSwapCurve,
              offset: showNoticeNav ? _navHiddenSlideOffset : Offset.zero,
              child: wrapNavSlot(
                IgnorePointer(
                  ignoring: showNoticeNav,
                  child: _buildBottomAppBar(),
                ),
              ),
            ),
            AnimatedSlide(
              duration: _navSwapDuration,
              curve: _navSwapCurve,
              offset: showNoticeNav ? Offset.zero : _navHiddenSlideOffset,
              child: wrapNavSlot(
                IgnorePointer(
                  ignoring: !showNoticeNav,
                  child: _buildBottomFloatingNoticeNav(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomAppBar() {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final MjcSurfaceTokens surfaceTokens =
        Theme.of(context).extension<MjcSurfaceTokens>()!;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color barColor = scheme.surface;
    final double bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    const BorderRadius topBarRadius = BorderRadius.only(
      topLeft: Radius.circular(MainNavLayout.barTopCornerRadius),
      topRight: Radius.circular(MainNavLayout.barTopCornerRadius),
    );
    final double slotHeight = MainNavLayout.barHeight + bottomSafe;
    return SizedBox(
      height: slotHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (bottomSafe > 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: bottomSafe,
              child: ColoredBox(color: barColor),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomSafe,
            height: MainNavLayout.barHeight,
            child: ClipRRect(
              borderRadius: topBarRadius,
              child: PhysicalModel(
                color: barColor,
                elevation: isDark ? 8 : 4,
                shadowColor:
                    Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                borderRadius: topBarRadius,
                clipBehavior: Clip.antiAlias,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: surfaceTokens.hairline.withValues(
                          alpha: isDark ? 0.45 : 0.55,
                        ),
                      ),
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      for (final _BottomNavItem item in _bottomNavItems)
                        Expanded(
                          child: _BottomNavTapTarget(
                            selected: _index == item.index,
                            onTap: () => _onMenuItemClick(item.index),
                            child: _buildBottomNavSegment(
                              item: item,
                              selected: _index == item.index,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomFloatingNoticeNav() {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final MjcSurfaceTokens surfaceTokens =
        Theme.of(context).extension<MjcSurfaceTokens>()!;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color accent = _components.bottomNavSelected;
    final double bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        MainNavLayout.noticeFloatingPillHorizontalInset,
        0,
        MainNavLayout.noticeFloatingPillHorizontalInset,
        bottomSafe,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: SizedBox(
            height: MainNavLayout.barHeight,
            child: PhysicalModel(
              color: scheme.surface.withValues(alpha: isDark ? 0.96 : 1),
              elevation: isDark ? 10 : 6,
              shadowColor:
                  Colors.black.withValues(alpha: isDark ? 0.42 : 0.14),
              borderRadius:
                  BorderRadius.circular(MainNavLayout.barHeight / 2),
              clipBehavior: Clip.antiAlias,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: surfaceTokens.hairline.withValues(
                      alpha: isDark ? 0.55 : 0.65,
                    ),
                  ),
                  borderRadius:
                      BorderRadius.circular(MainNavLayout.barHeight / 2),
                ),
                child: Row(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(left: 8, right: 4),
                        child: _FloatingNavBackButton(
                          size: _floatingNavBackSize,
                          onPressed: () => _onMenuItemClick(0),
                        ),
                      ),
                      Expanded(
                        child: ValueListenableBuilder<bool>(
                          valueListenable: LabPrefs.departmentNoticesEnabled,
                          builder: (context, labEnabled, _) {
                            final List<NoticesSubTab> visibleTabs =
                                visibleNoticeSubTabs(labEnabled);
                            return ValueListenableBuilder<NoticesSubTab>(
                              valueListenable: _noticeSubTab,
                              builder: (context, current, __) {
                                final int selectedIndex =
                                    visibleIndexOfNoticeSubTab(
                                        visibleTabs, current);
                                return MjcDraggableSegmentPillBar(
                                  segmentCount: visibleTabs.length,
                                  selectedIndex: selectedIndex,
                                  accentColor: accent,
                                  isDark: isDark,
                                  horizontalPadding: 4,
                                  verticalPadding: 4,
                                  showThumbWhenIdle: false,
                                  onSelectedIndexChanged: (int index) {
                                    final NoticesSubTab tab =
                                        noticeSubTabFromVisibleIndex(
                                            visibleTabs, index);
                                    if (tab == current) return;
                                    _noticeSubTab.value = tab;
                                  },
                                  segmentBuilder:
                                      (context, index, selected, ___) {
                                    final NoticesSubTab tab =
                                        visibleTabs[index];
                                    return _buildBottomFloatingNoticeSegment(
                                      tab: tab,
                                      selected: selected,
                                      accent: accent,
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomFloatingNoticeSegment({
    required NoticesSubTab tab,
    required bool selected,
    required Color accent,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color foreground =
        selected ? accent : scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            tab.icon,
            size: selected ? 20 : 18,
            color: foreground,
          ),
          const SizedBox(height: 2),
          Text(
            tab.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foreground,
              fontSize: 10,
              height: 1,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeSubNav() {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final MjcSurfaceTokens surfaceTokens =
        Theme.of(context).extension<MjcSurfaceTokens>()!;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color subNavAccent = _components.bottomNavSelected;
    return Align(
      key: const ValueKey<String>("notice_sub_nav"),
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: SizedBox(
          height: _noticeSubNavHeight,
          child: ValueListenableBuilder<bool>(
            valueListenable: LabPrefs.departmentNoticesEnabled,
            builder: (context, labEnabled, _) {
              final List<NoticesSubTab> visibleTabs =
                  visibleNoticeSubTabs(labEnabled);
              return ValueListenableBuilder<NoticesSubTab>(
                valueListenable: _noticeSubTab,
                builder: (context, current, __) {
                  final int selectedIndex =
                      visibleIndexOfNoticeSubTab(visibleTabs, current);
                  return Material(
                    color:
                        scheme.surface.withValues(alpha: isDark ? 0.98 : 0.96),
                    elevation: 10,
                    shadowColor: _components.noticeSubNavShadow,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(_noticeSubNavHeight / 2),
                      side: BorderSide(color: surfaceTokens.hairline, width: 1),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: MjcDraggableSegmentPillBar(
                      segmentCount: visibleTabs.length,
                      selectedIndex: selectedIndex,
                      accentColor: subNavAccent,
                      isDark: isDark,
                      onSelectedIndexChanged: (int index) {
                        _noticeSubTab.value =
                            noticeSubTabFromVisibleIndex(visibleTabs, index);
                      },
                      segmentBuilder: (context, index, selected, ___) {
                        final NoticesSubTab tab = visibleTabs[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                tab.icon,
                                size: 18,
                                color: selected
                                    ? subNavAccent
                                    : scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  tab.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: selected
                                        ? subNavAccent
                                        : scheme.onSurfaceVariant,
                                    fontSize: 13,
                                    fontWeight: selected
                                        ? FontWeight.w800
                                        : FontWeight.w700,
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
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavSegment({
    required _BottomNavItem item,
    required bool selected,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color selectedColor = _components.bottomNavSelected;
    return Transform.translate(
      offset: const Offset(
        0,
        -MainNavLayout.barHeight * _bottomNavContentLiftFactor,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          selected
              ? BouncyIcon(
                  item.selectedIcon,
                  color: selectedColor,
                  size: 24,
                )
              : Icon(item.icon, color: scheme.onSurfaceVariant, size: 24),
          const SizedBox(height: 3),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              height: 1.05,
              color:
                  selected ? selectedColor : _components.bottomNavUnselected,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNavTapTarget extends StatelessWidget {
  const _BottomNavTapTarget({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        child: Semantics(
          button: true,
          selected: selected,
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _FloatingNavBackButton extends StatelessWidget {
  const _FloatingNavBackButton({
    required this.size,
    required this.onPressed,
  });

  final double size;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(
        alpha: isDark ? 0.55 : 0.85,
      ),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            Icons.arrow_back_rounded,
            size: 20,
            color: scheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem {
  const _BottomNavItem({
    required this.index,
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final int index;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class BouncyIcon extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double size;
  const BouncyIcon(this.icon, {this.color, this.size = 24, super.key});
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(icon.hashCode),
      tween: Tween<double>(begin: 0.5, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      builder: (context, value, child) => Transform.scale(
          scale: value, child: Icon(icon, color: color, size: size)),
    );
  }
}
