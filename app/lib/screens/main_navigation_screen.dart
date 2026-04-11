import "package:flutter/material.dart";
import "package:mio_notice/screens/ctl_screen.dart";
import "package:mio_notice/screens/library_screen.dart";
import "package:mio_notice/screens/main_website_screen.dart";
import "package:mio_notice/screens/mpu_screen.dart";
import "package:mio_notice/screens/home_dashboard_screen.dart";
import "package:mio_notice/theme/app_colors.dart";

/// 하단 탭으로 대분류 전환 (figma Root 하단 네비 레이아웃).
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _index = 0;

  late final List<Widget> _pages = <Widget>[
    HomeDashboardScreen(onNavigate: (int targetIndex) {
      if (mounted) setState(() => _index = targetIndex);
    }),
    MainWebsiteScreen(),
    const MpuScreen(),
    const CtlScreen(),
    const LibraryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldMuted,
      body: IndexedStack(
        index: _index,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: "홈",
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school),
            label: "공지",
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events),
            label: "MPU",
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: "CTL",
          ),
          NavigationDestination(
            icon: Icon(Icons.local_library_outlined),
            selectedIcon: Icon(Icons.local_library),
            label: "도서관",
          ),
        ],
      ),
    );
  }
}
