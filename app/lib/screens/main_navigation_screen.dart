import "package:flutter/material.dart";
import "package:mio_notice/screens/ctl_screen.dart";
import "package:mio_notice/screens/library_screen.dart";
import "package:mio_notice/screens/main_website_screen.dart";
import "package:mio_notice/screens/mpu_screen.dart";
import "package:mio_notice/screens/home_dashboard_screen.dart";

/// 하단 탭으로 4개 대분류(메인홈페이지, MPU, CTL, 도서관)를 전환합니다.
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
      body: IndexedStack(
        index: _index,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        type: BottomNavigationBarType.fixed,
        onTap: (value) => setState(() => _index = value),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: "홈",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.campaign_outlined),
            activeIcon: Icon(Icons.campaign),
            label: "공지",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.school_outlined),
            activeIcon: Icon(Icons.school),
            label: "MPU",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_outlined),
            activeIcon: Icon(Icons.menu_book),
            label: "CTL",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_library_outlined),
            activeIcon: Icon(Icons.local_library),
            label: "도서관",
          ),
        ],
      ),
    );
  }
}
