import "dart:async";

import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:mio_notice/screens/library_screen.dart";
import "package:mio_notice/notification_history_prefs.dart";
import "package:mio_notice/screens/home_dashboard_screen.dart";
import "package:mio_notice/screens/more_tab_screen.dart";
import "package:mio_notice/screens/notification_history_screen.dart";
import "package:mio_notice/screens/notices_tab_screen.dart";
import "package:mio_notice/services/auth_service.dart";
import "package:mio_notice/services/user_data_repository.dart";
import "package:mio_notice/widgets/scroll_to_top_fab.dart";
import "package:mio_notice/widgets/scroll_to_top_scope.dart";
import "package:mio_notice/theme/app_colors.dart";

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  static const double _bottomNavHeight = 70;
  static const double _noticeSubNavHeight = 64;

  int _index = 0;
  final List<int> _tabHistory = <int>[];
  final ValueNotifier<NoticesSubTab> _noticeSubTab =
      ValueNotifier<NoticesSubTab>(NoticesSubTab.main);
  StreamSubscription<User?>? _authHydrateSubscription;

  @override
  void initState() {
    super.initState();
    _authHydrateSubscription =
        AuthService.instance.authStateChanges().listen((User? user) async {
      if (user == null) return;
      try {
        await UserDataRepository.instance.hydrateFromCloudOnLogin(user);
      } catch (e, st) {
        debugPrint("hydrateFromCloudOnLogin: $e\n$st");
      }
    });
    _syncScrollCoordinatorTab();
  }

  Widget _buildMainTab(int index) {
    switch (index) {
      case MainNavTabIndex.home:
        return HomeDashboardScreen(
          onNavigate: _onMenuItemClick,
        );
      case MainNavTabIndex.notices:
        return NoticesTabScreen(subTabNotifier: _noticeSubTab);
      case MainNavTabIndex.library:
        return const LibraryScreen();
      case MainNavTabIndex.alerts:
        return const NotificationHistoryScreen(embedded: true);
      case MainNavTabIndex.more:
        return const MoreTabScreen();
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
    _authHydrateSubscription?.cancel();
    _noticeSubTab.dispose();
    super.dispose();
  }

  void _onMenuItemClick(int index, {NoticesSubTab? noticesSubTab}) {
    if (noticesSubTab != null) {
      _noticeSubTab.value = noticesSubTab;
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onSystemPopInvoked,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Scaffold(
            backgroundColor: AppColors.scaffoldMuted,
            body: Stack(
              children: [
                // 1. 메인 콘텐츠 영역 – 탭 전환 시 새로 생성(상태 유지하지 않음) + 전환 애니메이션.
                Positioned.fill(
                  child: ColoredBox(
                    color: AppColors.scaffoldMuted,
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
                        // 나가는 화면은 슬라이드하지 않고 페이드만 해서,
                        // 전환 중 왼쪽에 "빈 흰 영역"이 드러나지 않게 합니다.
                        if (animation.status == AnimationStatus.reverse) {
                          return FadeTransition(opacity: fade, child: child);
                        }
                        final Animation<Offset> slide = Tween<Offset>(
                          begin: const Offset(0.04, 0),
                          end: Offset.zero,
                        ).animate(fade);
                        return SlideTransition(
                          position: slide,
                          child: FadeTransition(opacity: fade, child: child),
                        );
                      },
                      child: KeyedSubtree(
                        key: ValueKey<int>(_index),
                        child: _buildMainTab(_index),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            bottomNavigationBar: _buildBottomAppBar(),
          ),
          Positioned(
            right: 14,
            bottom: MediaQuery.paddingOf(context).bottom +
                _bottomNavHeight +
                10 +
                (_index == MainNavTabIndex.notices ? _noticeSubNavHeight : 0),
            child: const ScrollToTopFab(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAppBar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: _index == MainNavTabIndex.notices
              ? _buildNoticeSubNav()
              : const SizedBox.shrink(),
        ),
        const Divider(
          height: 1,
          thickness: 1,
          color: Color(0x1F000000),
        ),
        SizedBox(
          height: _bottomNavHeight,
          child: BottomAppBar(
            height: _bottomNavHeight,
            color: Colors.white,
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
                    MainNavTabIndex.library,
                    Icons.local_library_outlined,
                    Icons.local_library,
                    "도서관",
                  ),
                ),
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: loadNotificationHistoryNewestFirst(),
                    builder: (context, snapshot) {
                      final int count = snapshot.data?.length ?? 0;
                      return _buildNavTab(
                        MainNavTabIndex.alerts,
                        Icons.notifications_none_rounded,
                        Icons.notifications_rounded,
                        "알림",
                        badgeCount: count,
                      );
                    },
                  ),
                ),
                Expanded(
                  child: _buildNavTab(
                    MainNavTabIndex.more,
                    Icons.menu_rounded,
                    Icons.menu_rounded,
                    "더보기",
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoticeSubNav() {
    return SizedBox(
      key: const ValueKey<String>("notice_sub_nav"),
      height: _noticeSubNavHeight,
      child: ColoredBox(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 7, 14, 9),
          child: ValueListenableBuilder<NoticesSubTab>(
            valueListenable: _noticeSubTab,
            builder: (context, current, _) {
              return Material(
                color: const Color(0xFFEFF4FC),
                borderRadius: BorderRadius.circular(18),
                clipBehavior: Clip.antiAlias,
                child: Row(
                  children: NoticesSubTab.values.map((tab) {
                    final bool selected = tab == current;
                    return Expanded(
                      child: InkWell(
                        onTap: () => _noticeSubTab.value = tab,
                        borderRadius: BorderRadius.circular(16),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          curve: Curves.easeOutCubic,
                          margin: const EdgeInsets.all(4),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: selected
                                ? [
                                    BoxShadow(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.24),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                tab.icon,
                                size: 18,
                                color: selected
                                    ? Colors.white
                                    : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  tab.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: selected
                                        ? Colors.white
                                        : Colors.grey.shade700,
                                    fontSize: 14,
                                    fontWeight: selected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// 탭 영역 가로의 약 80%만 터치로 인식(양옆 여백).
  static const double _navTabHitWidthFactor = 0.8;

  /// [radius]로 스플래시 반경을 제한해 노치 밖으로 퍼지는 느낌을 줄임.
  Widget _buildNavTab(
    int index,
    IconData icon,
    IconData selectedIcon,
    String label, {
    int badgeCount = 0,
  }) {
    final bool isSelected = _index == index;
    return Center(
      child: FractionallySizedBox(
        widthFactor: _navTabHitWidthFactor,
        heightFactor: 1,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _onMenuItemClick(index),
            radius: 26,
            splashColor: AppColors.primary.withValues(alpha: 0.14),
            highlightColor: AppColors.primary.withValues(alpha: 0.06),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      isSelected
                          ? BouncyIcon(selectedIcon, color: AppColors.primary)
                          : Icon(icon, color: Colors.grey),
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
                              color: const Color(0xFFE53935),
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
                  Text(label,
                      style: TextStyle(
                          fontSize: 12,
                          color: isSelected ? AppColors.primary : Colors.grey,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal)),
                ],
              ),
            ),
          ),
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
