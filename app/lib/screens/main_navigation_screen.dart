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
import "package:mjc_in_one/services/user_data_repository.dart";
import "package:mjc_in_one/debug/app_debug_flags.dart";
import "package:mjc_in_one/debug/scroll_fab_debug.dart";
import "package:mjc_in_one/utils/bookmark_added_feedback.dart";
import "package:mjc_in_one/widgets/main_navigation_scope.dart";
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
  static const double _bottomNavHeight = 70;
  static const double _noticeSubNavHeight = 44;
  static const double _noticeSubNavBottomGap = 8;
  static const double _noticeSubNavFabGap = 16;

  MjcComponentTokens get _components =>
      Theme.of(context).extension<MjcComponentTokens>()!;

  int _index = 0;
  int _myPageBookmarkTabIndex = 0;
  int _myPageNavigateEpoch = 0;
  bool _noticeSubNavVisible = true;
  Timer? _noticeSubNavRevealTimer;
  final List<int> _tabHistory = <int>[];
  final ValueNotifier<NoticesSubTab> _noticeSubTab =
      ValueNotifier<NoticesSubTab>(NoticesSubTab.main);
  StreamSubscription<User?>? _authHydrateSubscription;

  void _onLabDepartmentNoticesChanged() {
    if (!LabPrefs.departmentNoticesEnabled.value &&
        _noticeSubTab.value == NoticesSubTab.dept) {
      _noticeSubTab.value = NoticesSubTab.main;
    }
  }

  @override
  void initState() {
    super.initState();
    LabPrefs.departmentNoticesEnabled.addListener(_onLabDepartmentNoticesChanged);
    _authHydrateSubscription =
        AuthService.instance.authStateChanges().listen((User? user) async {
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

    // 앱 첫 진입 시 테스트 빌드 안내 팝업 및 피드백 버튼 포커싱 띄우기
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
    _noticeSubNavRevealTimer?.cancel();
    _authHydrateSubscription?.cancel();
    _noticeSubTab.dispose();
    super.dispose();
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

  /// 시스템 뒤로가기: 드로어·FAB 메뉴 닫기 → 이전 탭 → 앱 종료 순.
  void _onSystemPopInvoked(bool didPop, Object? result) {
    if (didPop) return;

    if (_index == MainNavTabIndex.notices &&
        _noticeSubTab.value != NoticesSubTab.main) {
      _noticeSubTab.value = NoticesSubTab.main;
      return;
    }
    if (_tabHistory.isNotEmpty) {
      setState(() {
        _index = _tabHistory.removeLast();
      });
      _syncScrollCoordinatorTab();
      return;
    }
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final Color scaffoldBackground = Theme.of(context).scaffoldBackgroundColor;
    return MainNavigationScope(
      navigate: _onMenuItemClick,
      child: ValueListenableBuilder<int>(
        valueListenable: bookmarkSnackBarSubnavSuppressionCount,
        builder: (context, snackbarSuppression, _) {
          final bool showNoticeSubChrome =
              _index == MainNavTabIndex.notices &&
                  _noticeSubNavVisible &&
                  snackbarSuppression == 0;
          return PopScope(
          canPop: false,
          onPopInvokedWithResult: _onSystemPopInvoked,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Scaffold(
                backgroundColor: scaffoldBackground,
                body: Stack(
                  children: [
                    // 1. 메인 콘텐츠 영역 – 탭 전환 시 새로 생성(상태 유지하지 않음) + 전환 애니메이션.
                    Positioned.fill(
                      child: ColoredBox(
                        color: scaffoldBackground,
                        child: NotificationListener<ScrollNotification>(
                          onNotification: _handleMainScrollNotification,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            layoutBuilder: (Widget? currentChild,
                                List<Widget> previousChildren) {
                              return Stack(
                                fit: StackFit.expand,
                                children: <Widget>[
                                  ...previousChildren,
                                  if (currentChild != null) currentChild,
                                ],
                              );
                            },
                            transitionBuilder: (child, animation) {
                              final CurvedAnimation fade = CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                              );
                              // 기본 페이드 인/아웃만 사용 (슬라이드 제거).
                              return FadeTransition(opacity: fade, child: child);
                            },
                            child: KeyedSubtree(
                              key: ValueKey<Object>(_mainTabChildKey(_index)),
                              child: _buildMainTab(_index),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                bottomNavigationBar: _buildBottomAppBar(),
              ),
              Positioned(
                left: 18,
                right: 18,
                bottom: MediaQuery.paddingOf(context).bottom +
                    _bottomNavHeight +
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
                bottom: MediaQuery.paddingOf(context).bottom +
                    _bottomNavHeight +
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
        );
        },
      ),
    );
  }

  Widget _buildBottomAppBar() {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final MjcSurfaceTokens tokens =
        Theme.of(context).extension<MjcSurfaceTokens>()!;
    return ColoredBox(
      color: scheme.surface,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Divider(
              height: 1,
              thickness: 1,
              color: tokens.hairline,
            ),
            SizedBox(
              height: _bottomNavHeight,
              child: BottomAppBar(
                height: _bottomNavHeight,
                color: scheme.surface,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _buildNavTab(
                        MainNavTabIndex.home,
                        Icons.home_outlined,
                        Icons.home,
                        "홈",
                      ),
                    ),
                    Expanded(
                      child: _buildNavTab(
                        MainNavTabIndex.notices,
                        Icons.campaign_outlined,
                        Icons.campaign_rounded,
                        "공지",
                      ),
                    ),
                    Expanded(
                      child: _buildNavTab(
                        MainNavTabIndex.timetable,
                        Icons.calendar_month_outlined,
                        Icons.calendar_month_rounded,
                        "시간표",
                      ),
                    ),
                    Expanded(
                      child: _buildNavTab(
                        MainNavTabIndex.mypage,
                        Icons.person_outline_rounded,
                        Icons.person_rounded,
                        "마이페이지",
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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

  /// 탭 영역 대부분을 터치/리플로 인식하되, 탭 사이에는 약간의 숨 쉴 공간을 둡니다.
  static const double _navTabHitWidthFactor = 0.92;

  Widget _buildNavTab(
    int index,
    IconData icon,
    IconData selectedIcon,
    String label, {
    int badgeCount = 0,
  }) {
    final bool isSelected = _index == index;
    final Color rippleAccent = _components.bottomNavSelected;
    return Center(
      child: FractionallySizedBox(
        widthFactor: _navTabHitWidthFactor,
        heightFactor: 1,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _onMenuItemClick(index),
            borderRadius: BorderRadius.circular(16),
            splashColor: rippleAccent.withValues(alpha: 0.14),
            highlightColor: rippleAccent.withValues(alpha: 0.06),
            child: SizedBox.expand(
              child: _buildNavTabContent(
                isSelected,
                icon,
                selectedIcon,
                label,
                badgeCount,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavTabContent(
    bool isSelected,
    IconData icon,
    IconData selectedIcon,
    String label,
    int badgeCount,
  ) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color selectedColor = _components.bottomNavSelected;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                isSelected
                    ? BouncyIcon(
                        selectedIcon,
                        color: selectedColor,
                        size: 22,
                      )
                    : Icon(icon, color: scheme.onSurfaceVariant, size: 22),
                if (badgeCount > 0)
                  Positioned(
                    right: -7,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badgeCount > 99 ? "99+" : "$badgeCount",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                height: 1.05,
                color: isSelected
                    ? selectedColor
                    : _components.bottomNavUnselected,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
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
