import "package:flutter/material.dart";
import "package:mio_notice/screens/ctl_screen.dart";
import "package:mio_notice/screens/library_screen.dart";
import "package:mio_notice/screens/main_website_screen.dart";
import "package:mio_notice/screens/mpu_screen.dart";
import "package:mio_notice/screens/home_dashboard_screen.dart";
import "package:mio_notice/widgets/app_menu_drawer.dart";
import "package:mio_notice/theme/app_colors.dart";

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  static final GlobalKey<ScaffoldState> scaffoldKey =
      GlobalKey<ScaffoldState>();

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  bool _isMenuOpen = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack, // 열릴 때 살짝 튕기는 효과
    );
  }

  @override
  void dispose() {
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

  late final List<Widget> _pages = <Widget>[
    HomeDashboardScreen(onNavigate: _onMenuItemClick),
    const LibraryScreen(),
    const MainWebsiteScreen(),
    const CtlScreen(),
    const MpuScreen(),
  ];

  void _onMenuItemClick(int index) {
    setState(() {
      _index = index;
      if (_isMenuOpen) _toggleMenu();
    });
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double centerX = screenWidth / 2;

    return Scaffold(
      backgroundColor: AppColors.scaffoldMuted,
      key: MainNavigationScreen.scaffoldKey,
      drawer: const AppMenuDrawer(),
      body: Stack(
        children: [
          // 1. 메인 콘텐츠 영역 (애니메이션 전환)
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              switchInCurve: Curves.easeOutQuart,
              switchOutCurve: Curves.easeInQuart,
              layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
                return Stack(
                  alignment: Alignment.topCenter,
                  children: <Widget>[
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                );
              },
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.05),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: SizedBox(
                key: ValueKey<int>(_index),
                child: _pages[_index],
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
                targetY: 40),
            _buildFixedMenuItem(
                index: 3,
                icon: Icons.menu_book,
                label: "교수학습",
                color: AppColors.teaching,
                left: centerX - 30,
                targetY: 70),
            _buildFixedMenuItem(
                index: 4,
                icon: Icons.emoji_events,
                label: "역량관리",
                color: AppColors.competency,
                left: centerX + 49,
                targetY: 40),
          ],
        ],
      ),
      floatingActionButton: _buildMainFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomAppBar(),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => _onMenuItemClick(index),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
              color: Colors.black45, borderRadius: BorderRadius.circular(10)),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildMainFab() {
    return FloatingActionButton(
      onPressed: _toggleMenu,
      backgroundColor: Colors.red.shade600,
      elevation: 4,
      shape: const CircleBorder(),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) => RotationTransition(
            turns: animation,
            child: ScaleTransition(scale: animation, child: child)),
        child: _isMenuOpen
            ? const Icon(Icons.close,
                key: ValueKey('close_icon'), color: Colors.white, size: 32)
            : Image.asset("assets/images/notice_megaphone.png",
                key: const ValueKey('megaphone_icon'),
                color: Colors.white,
                width: 28,
                height: 28),
      ),
    );
  }

  Widget _buildBottomAppBar() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      height: 70,
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavTab(0, Icons.home_outlined, Icons.home, "홈"),
          const SizedBox(width: 40),
          _buildNavTab(
              1, Icons.local_library_outlined, Icons.local_library, "도서관"),
        ],
      ),
    );
  }

  Widget _buildNavTab(
      int index, IconData icon, IconData selectedIcon, String label) {
    bool isSelected = _index == index;
    return GestureDetector(
      onTap: () => _onMenuItemClick(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          isSelected
              ? BouncyIcon(selectedIcon, color: AppColors.primary)
              : Icon(icon, color: Colors.grey),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? AppColors.primary : Colors.grey,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal)),
        ],
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
