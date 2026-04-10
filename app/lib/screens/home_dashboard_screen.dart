import 'package:flutter/material.dart';
import 'package:mio_notice/screens/settings_screen.dart';

class HomeDashboardScreen extends StatelessWidget {
  final Function(int) onNavigate;

  const HomeDashboardScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "MJC In One",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                "빠른 바로가기",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _buildNavigationCard(
              context,
              title: "명지전문대 전체 공지사항 모아보기",
              subtitle: "학사, 장학, 일반 공지사항을 실시간으로 확인하세요.",
              icon: Icons.campaign,
              color: Colors.blueAccent,
              onTap: () => onNavigate(1),
            ),
            const SizedBox(height: 12),
            _buildNavigationCard(
              context,
              title: "MPU 핵심역량 프로그램",
              subtitle: "나의 핵심역량을 키우는 프로그램 신청",
              icon: Icons.school,
              color: Colors.orangeAccent,
              onTap: () => onNavigate(2),
            ),
            const SizedBox(height: 12),
            _buildNavigationCard(
              context,
              title: "CTL 교수학습센터",
              subtitle: "학습 지원 프로그램 및 공지사항",
              icon: Icons.menu_book,
              color: Colors.teal,
              onTap: () => onNavigate(3),
            ),
            const SizedBox(height: 12),
            _buildNavigationCard(
              context,
              title: "도서관 검색 및 현황",
              subtitle: "도서 검색, 대출 연장, 모바일 이용증",
              icon: Icons.local_library,
              color: Colors.brown,
              onTap: () => onNavigate(4),
            ),
            const SizedBox(height: 32),
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Icon(Icons.notifications_active, size: 40, color: Colors.indigo),
                    const SizedBox(height: 8),
                    const Text(
                      "푸시 알람 설정 안내",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "우측 상단 톱니바퀴를 눌러\n원하는 키워드만 알림으로 받아보세요!",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SettingsScreen()),
                        );
                      },
                      child: const Text("알림 설정하러 가기"),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
