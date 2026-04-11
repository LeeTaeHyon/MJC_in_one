import "package:flutter/material.dart";
import "package:mio_notice/screens/settings_screen.dart";
import "package:mio_notice/theme/app_colors.dart";

class HomeDashboardScreen extends StatelessWidget {
  final void Function(int) onNavigate;

  const HomeDashboardScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldMuted,
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary,
                  AppColors.secondary,
                ],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "명지전문대학",
                          style:
                              Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ) ??
                                  const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "통합 공지사항 시스템",
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ) ??
                                  TextStyle(
                                    fontSize: 16,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (context) => const SettingsScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.settings, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _CategoryCard(
                  title: "명지전문대 전체 공지사항 모아보기",
                  subtitle: "학사, 장학, 일반 공지사항을 실시간으로 확인하세요.",
                  icon: Icons.campaign,
                  color: AppColors.primary,
                  onTap: () => onNavigate(1),
                ),
                const SizedBox(height: 16),
                _CategoryCard(
                  title: "MPU 핵심역량 프로그램",
                  subtitle: "나의 핵심역량을 키우는 프로그램 신청",
                  icon: Icons.emoji_events,
                  color: AppColors.competency,
                  onTap: () => onNavigate(2),
                ),
                const SizedBox(height: 16),
                _CategoryCard(
                  title: "CTL 교수학습센터",
                  subtitle: "학습 지원 프로그램 및 공지사항",
                  icon: Icons.menu_book,
                  color: AppColors.teaching,
                  onTap: () => onNavigate(3),
                ),
                const SizedBox(height: 16),
                _CategoryCard(
                  title: "도서관 검색 및 현황",
                  subtitle: "도서 검색, 대출 연장, 모바일 이용증",
                  icon: Icons.local_library,
                  color: AppColors.library,
                  onTap: () => onNavigate(4),
                ),
                const SizedBox(height: 24),
                Card(
                  elevation: 1,
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.notifications_active,
                          size: 40,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "푸시 알람 설정 안내",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "우측 상단 톱니바퀴를 눌러\n원하는 키워드만 알림으로 받아보세요!",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (context) => const SettingsScreen(),
                              ),
                            );
                          },
                          child: const Text("알림 설정하러 가기"),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.iconBackdrop(color),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 40),
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
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
