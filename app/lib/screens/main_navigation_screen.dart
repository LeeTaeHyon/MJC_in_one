import "dart:async";

import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:mio_notice/screens/ctl_screen.dart";
import "package:mio_notice/screens/library_screen.dart";
import "package:mio_notice/screens/main_website_screen.dart";
import "package:mio_notice/screens/mpu_screen.dart";
import "package:mio_notice/screens/home_dashboard_screen.dart";
import "package:mio_notice/services/auth_service.dart";
import "package:mio_notice/services/user_data_repository.dart";
import "package:mio_notice/widgets/app_menu_drawer.dart";
import "package:mio_notice/widgets/scroll_to_top_fab.dart";
import "package:mio_notice/widgets/scroll_to_top_scope.dart";
import "package:mio_notice/theme/app_colors.dart";

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  static final GlobalKey<ScaffoldState> scaffoldKey =
      GlobalKey<ScaffoldState>();

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with TickerProviderStateMixin {
  int _index = 0;
  final List<int> _tabHistory = <int>[];
  bool _isMenuOpen = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;
  late AnimationController _homeMenuOpen;
  StreamSubscription<User?>? _authHydrateSubscription;

  @override
  void initState() {
    super.initState();
    _homeMenuOpen = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack, // 열릴 때 살짝 튕기는 효과
    );
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
          menuOpen: _homeMenuOpen,
        );
      case MainNavTabIndex.library:
        return const LibraryScreen();
      case MainNavTabIndex.mainSite:
        return const MainWebsiteScreen();
      case MainNavTabIndex.ctl:
        return const CtlScreen();
      case MainNavTabIndex.mpu:
        return const MpuScreen();
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
    _homeMenuOpen.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
      _isMenuOpen
          ? _animationController.forward()
          : _animationController.reverse();
    });
  }

  void _onMenuItemClick(int index) {
    final bool tabChanged = index != _index;
    setState(() {
      if (tabChanged) {
        if (_index == 0 && index != 0) {
          _homeMenuOpen.value = 0.0;
        }
        if (index == 0) {
          _tabHistory.clear();
        } else {
          _tabHistory.add(_index);
        }
        _index = index;
      }
      if (_isMenuOpen) _toggleMenu();
    });
    if (tabChanged) {
      _syncScrollCoordinatorTab();
    }
  }

  /// 시스템 뒤로가기: 드로어·FAB 메뉴 닫기 → 이전 탭 → 앱 종료 순.
  void _onSystemPopInvoked(bool didPop, Object? result) {
    if (didPop) return;

    final ScaffoldState? scaffold =
        MainNavigationScreen.scaffoldKey.currentState;
    if (scaffold?.isDrawerOpen == true) {
      scaffold!.closeDrawer();
      return;
    }
    if (_index == 0 && _homeMenuOpen.value > 0.001) {
      _homeMenuOpen.animateTo(0.0, curve: Curves.easeInCubic);
      return;
    }
    if (_isMenuOpen) {
      _toggleMenu();
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
    final double screenWidth = MediaQuery.of(context).size.width;
    final double centerX = screenWidth / 2;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onSystemPopInvoked,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Scaffold(
            backgroundColor: AppColors.scaffoldMuted,
            key: MainNavigationScreen.scaffoldKey,
            drawer: const AppMenuDrawer(),
            // 홈 커스텀 슬라이드 메뉴와 이중으로 열리지 않도록 엣지 드래그는 끔(메뉴는 버튼으로만).
            drawerEnableOpenDragGesture: false,
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

                // 2. 메뉴 배경 오버레이 (메뉴 열렸을 때만 배경을 어둡게 하고 클릭 시 닫기)
                if (_isMenuOpen || _animationController.isAnimating)
                  IgnorePointer(
                    ignoring: !_isMenuOpen, // 닫히는 중에는 클릭 무시
                    child: GestureDetector(
                      onTap: _toggleMenu,
                      child: AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) => Container(
                          color: Colors.black
                              .withOpacity(0.3 * _animationController.value),
                        ),
                      ),
                    ),
                  ),

                // 3. 팝업 메뉴 버튼들 (위치 고정 및 수직 애니메이션)
                if (_isMenuOpen || _animationController.isAnimating) ...[
                  _buildFixedMenuItem(
                      index: 2,
                      icon: Icons.school,
                      label: "메인",
                      color: AppColors.primary,
                      left: centerX - 110,
                      targetY: 10),
                  _buildFixedMenuItem(
                      index: 3,
                      icon: Icons.menu_book,
                      label: "교수학습",
                      color: AppColors.teaching,
                      left: centerX - 30,
                      targetY: 10),
                  _buildFixedMenuItem(
                      index: 4,
                      icon: Icons.emoji_events,
                      label: "역량관리",
                      color: AppColors.competency,
                      left: centerX + 49,
                      targetY: 10),
                ],
              ],
            ),
            bottomNavigationBar: _buildBottomAppBar(),
          ),
          if (!_isMenuOpen)
            Positioned(
              right: 14,
              bottom: MediaQuery.paddingOf(context).bottom + 70 + 10,
              child: const ScrollToTopFab(),
            ),
          if (_index == 0)
            HomeSideMenuOverlay(
              menuOpen: _homeMenuOpen,
              dialogContext: context,
            ),
        ],
      ),
    );
  }

  /// X축은 고정되고 Y축으로만 솟아오르는 메뉴 아이템
  Widget _buildFixedMenuItem({
    required int index,
    required IconData icon,
    required String label,
    required Color color,
    required double left,
    required double targetY,
  }) {
    return AnimatedBuilder(
      animation: _expandAnimation,
      builder: (context, child) {
        final value = _expandAnimation.value;
        // 닫혀있을 때(0)는 바닥(0), 열릴 때(1)는 목표 높이(targetY)
        final double currentY = targetY * value;

        return Positioned(
          bottom: currentY,
          left: left,
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.5 + (0.5 * value), // 0.5에서 1.0으로 커짐
              child: _buildPopupItem(index, icon, label, color),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPopupItem(int index, IconData icon, String label, Color color) {
    void onSelect() => _onMenuItemClick(index);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color,
          elevation: 4,
          shadowColor: color.withValues(alpha: 0.45),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onSelect,
            splashColor: Colors.white.withValues(alpha: 0.35),
            highlightColor: Colors.white.withValues(alpha: 0.2),
            child: SizedBox(
              width: 56,
              height: 56,
              child: Icon(icon, color: Colors.white, size: 28),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Material(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onSelect,
            borderRadius: BorderRadius.circular(10),
            splashColor: Colors.white.withValues(alpha: 0.25),
            highlightColor: Colors.white.withValues(alpha: 0.12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMainFabInNavBar() {
    // 네비게이션 바 "영역 안"으로 들어오는 버전 (떠있는 FAB 미사용).
    return Center(
      child: SizedBox(
        width: 52,
        height: 52,
        child: Material(
          color: Color(0xFF003FB4),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          elevation: 0,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _toggleMenu,
            splashColor: Colors.white.withValues(alpha: 0.38),
            highlightColor: Colors.white.withValues(alpha: 0.22),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: _isMenuOpen
                    ? const Icon(
                        Icons.close,
                        key: ValueKey('close_icon_nav'),
                        color: Colors.white,
                        size: 30,
                      )
                    : Image.asset(
                        "assets/images/notice_megaphone.png",
                        key: const ValueKey('megaphone_icon_nav'),
                        color: Colors.white,
                        filterQuality: FilterQuality.medium,
                        width: 26,
                        height: 26,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomAppBar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(
          height: 1,
          thickness: 1,
          color: Color(0x1F000000),
        ),
        BottomAppBar(
          height: 70,
          color: Colors.white,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildNavTab(0, Icons.home_outlined, Icons.home, "홈"),
              ),
              SizedBox(
                width: 80,
                child: _buildMainFabInNavBar(),
              ),
              Expanded(
                child: _buildNavTab(1, Icons.local_library_outlined,
                    Icons.local_library, "도서관"),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 탭 영역 가로의 약 80%만 터치로 인식(양옆 여백).
  static const double _navTabHitWidthFactor = 0.8;

  /// [radius]로 스플래시 반경을 제한해 노치 밖으로 퍼지는 느낌을 줄임.
  Widget _buildNavTab(
      int index, IconData icon, IconData selectedIcon, String label) {
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
                  isSelected
                      ? BouncyIcon(selectedIcon, color: AppColors.primary)
                      : Icon(icon, color: Colors.grey),
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
