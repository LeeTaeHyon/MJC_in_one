import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";
import "package:mio_notice/mpu_profile_prefs.dart";
import "package:mio_notice/screens/academic_schedule_screen.dart";
import "package:mio_notice/screens/campus_map_screen.dart";
import "package:mio_notice/screens/login_screen.dart";
import "package:mio_notice/screens/my_page_screen.dart";
import "package:mio_notice/screens/settings_screen.dart";
import "package:mio_notice/services/auth_service.dart";
import "package:mio_notice/services/user_data_repository.dart";
import "package:mio_notice/theme/app_colors.dart";
import "package:mio_notice/widgets/scroll_to_top_scope.dart";

class MoreTabScreen extends StatefulWidget {
  const MoreTabScreen({super.key});

  @override
  State<MoreTabScreen> createState() => _MoreTabScreenState();
}

class _MoreTabScreenState extends State<MoreTabScreen> {
  final ScrollController _scrollController = ScrollController();
  ScrollToTopCoordinator? _scrollToTopCoordinator;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    _scrollToTopCoordinator?.reportMainTabScroll(
      MainNavTabIndex.more,
      _scrollController.offset,
      ScrollFabMetrics.viewportHeightInScrollListener(_scrollController),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ScrollToTopCoordinator? c = ScrollToTopScope.maybeOf(context);
    if (c != null) {
      _scrollToTopCoordinator = c;
      c.registerMainTab(MainNavTabIndex.more, _scrollContentToTop);
    }
  }

  void _scrollContentToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollToTopCoordinator?.unregisterMainTab(MainNavTabIndex.more);
    _scrollController.dispose();
    super.dispose();
  }

  void _push(Widget screen) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  Future<void> _signOut() async {
    await UserDataRepository.instance.pushSnapshotToCloud();
    await clearMpuProfile();
    await AuthService.instance.signOut();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("로그아웃되었습니다.")),
    );
  }

  void _showAppInfo() {
    showAboutDialog(
      context: context,
      applicationName: "MJC in one",
      applicationVersion: "1.0.0",
      applicationLegalese: "© 2026 명지전문대학교",
    );
  }

  void _showHelp() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("도움말"),
        content: const Text(
          "앱 사용 중 불편한 점은 설정 화면의「개발자에게 문의하기」로 보내 주세요.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("확인"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldMuted,
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          "더보기",
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.4,
                              ),
                        ),
                        const SizedBox(height: 14),
                        _AccountCard(
                          onLogin: () => _push(const LoginScreen()),
                          onLogout: _signOut,
                        ),
                        const SizedBox(height: 18),
                        _MenuGrid(
                          items: [
                            _MoreMenuItem(
                              icon: Icons.person_outline_rounded,
                              label: "마이페이지",
                              color: AppColors.primary,
                              onTap: () => _push(const MyPageScreen()),
                            ),
                            _MoreMenuItem(
                              icon: Icons.event_note_outlined,
                              label: "학사일정",
                              color: const Color(0xFF5E35B1),
                              onTap: () =>
                                  _push(const AcademicScheduleScreen()),
                            ),
                            _MoreMenuItem(
                              icon: Icons.map_outlined,
                              label: "캠퍼스 약도",
                              color: const Color(0xFF00897B),
                              onTap: () => _push(const CampusMapScreen()),
                            ),
                            _MoreMenuItem(
                              icon: Icons.settings_outlined,
                              label: "설정",
                              color: const Color(0xFF546E7A),
                              onTap: () => _push(const SettingsScreen()),
                            ),
                            _MoreMenuItem(
                              icon: Icons.info_outline_rounded,
                              label: "앱 정보",
                              color: const Color(0xFF6D4C41),
                              onTap: _showAppInfo,
                            ),
                            _MoreMenuItem(
                              icon: Icons.help_outline_rounded,
                              label: "도움말",
                              color: const Color(0xFFF57C00),
                              onTap: _showHelp,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Center(
                          child: Text(
                            "MJC in one  v1.0.0",
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.onLogin,
    required this.onLogout,
  });

  final VoidCallback onLogin;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges(),
      initialData: AuthService.instance.currentUser,
      builder: (context, snapshot) {
        final User? user = snapshot.data;
        final bool signedIn = user != null;
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.24),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: Colors.white.withValues(alpha: 0.18),
                child: Icon(
                  signedIn ? Icons.person_rounded : Icons.login_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      signedIn ? "로그인됨" : "로그인이 필요합니다",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      signedIn
                          ? (user.email ?? "MJC 계정")
                          : "동기화와 개인 기능을 사용할 수 있어요",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.86),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.16),
                  foregroundColor: Colors.white,
                ),
                onPressed: signedIn ? () => onLogout() : onLogin,
                child: Text(signedIn ? "로그아웃" : "로그인"),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MenuGrid extends StatelessWidget {
  const _MenuGrid({required this.items});

  final List<_MoreMenuItem> items;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 210,
        mainAxisExtent: 118,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) => items[index],
    );
  }
}

class _MoreMenuItem extends StatelessWidget {
  const _MoreMenuItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 1,
      shadowColor: Colors.black12,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
