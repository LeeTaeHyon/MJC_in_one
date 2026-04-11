import "package:flutter/material.dart";
import "package:mio_notice/screens/notification_history_screen.dart";
import "package:mio_notice/screens/settings_screen.dart";
import "package:mio_notice/theme/app_colors.dart";

/// 앱의 주요 부가 기능(알림, 설정 등)을 모아둔 메뉴 바(Drawer)입니다.
class AppMenuDrawer extends StatelessWidget {
  const AppMenuDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          // 드로어 헤더
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, Color(0xFF5C6BC0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.school, size: 48, color: Colors.white),
                  const SizedBox(height: 12),
                  Text(
                    "MJC IN ONE",
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                  ),
                ],
              ),
            ),
          ),
          
          // 메뉴 리스트
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildMenuItem(
                  context,
                  icon: Icons.notifications_active_outlined,
                  title: "알림 내역",
                  onTap: () {
                    Navigator.pop(context); // 메뉴 닫기
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(builder: (context) => const NotificationHistoryScreen()),
                    );
                  },
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.settings_outlined,
                  title: "앱 설정",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(builder: (context) => const SettingsScreen()),
                    );
                  },
                ),
                const Divider(height: 32, indent: 20, endIndent: 20),
                _buildMenuItem(
                  context,
                  icon: Icons.info_outline,
                  title: "버전 정보: 1.0.0",
                  onTap: () {},
                ),
              ],
            ),
          ),
          
          // 하단 카피라이트
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "© 2026 명지전문대학교",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, {required IconData icon, required String title, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: Colors.black87),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      horizontalTitleGap: 16, // 간격을 16으로 넓혀 가독성 확보
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
    );
  }
}
