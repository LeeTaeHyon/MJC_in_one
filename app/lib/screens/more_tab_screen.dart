import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";
import "package:mio_notice/mpu_profile_prefs.dart";
import "package:mio_notice/screens/academic_schedule_screen.dart";
import "package:mio_notice/screens/campus_map_screen.dart";
import "package:mio_notice/screens/common_webview_screen.dart";
import "package:mio_notice/screens/foodcourt_menu_screen.dart";
import "package:mio_notice/screens/library_screen.dart";
import "package:mio_notice/screens/login_screen.dart";
import "package:mio_notice/screens/my_page_screen.dart";
import "package:mio_notice/screens/notices_tab_screen.dart";
import "package:mio_notice/screens/notification_history_screen.dart";
import "package:mio_notice/screens/open_source_licenses_screen.dart";
import "package:mio_notice/screens/profile_setup_screen.dart";
import "package:mio_notice/screens/settings_screen.dart";
import "package:mio_notice/services/auth_service.dart";
import "package:mio_notice/services/user_data_repository.dart";
import "package:mio_notice/theme/app_colors.dart";
import "package:mio_notice/theme/app_theme.dart";
import "package:mio_notice/widgets/scroll_to_top_scope.dart";

class MoreTabScreen extends StatefulWidget {
  const MoreTabScreen({super.key});

  @override
  State<MoreTabScreen> createState() => _MoreTabScreenState();
}

class _MoreTabScreenState extends State<MoreTabScreen> {
  final ScrollController _scrollController = ScrollController();
  ScrollToTopCoordinator? _scrollToTopCoordinator;
  static const String _privacyPolicyUrl = "https://mjcinone.web.app/privacy";

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
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (BuildContext ctx) {
        return _AboutAppDialog(
          onPrivacy: () {
            Navigator.of(ctx).pop();
            _push(
              const CommonWebViewScreen(
                url: _privacyPolicyUrl,
                title: "개인정보처리방침",
              ),
            );
          },
          onLicenses: () {
            Navigator.of(ctx).pop();
            _push(const OpenSourceLicensesScreen());
          },
        );
      },
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("더보기"),
      ),
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
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _AccountCard(
                          onLogin: () => _push(const LoginScreen()),
                          onLogout: _signOut,
                        ),
                        const SizedBox(height: 18),
                        _MenuGrid(
                          items: [
                            _MoreMenuItem(
                              icon: Icons.menu_rounded,
                              label: "전체 기능",
                              color: const Color(0xFF263238),
                              onTap: () => _push(const _AllFeaturesScreen()),
                            ),
                            _MoreMenuItem(
                              icon: Icons.person_outline_rounded,
                              label: "마이페이지",
                              color: AppColors.primary,
                              onTap: () => _push(const MyPageScreen()),
                            ),
                            _MoreMenuItem(
                              icon: Icons.school_outlined,
                              label: "본교 공지",
                              color: const Color(0xFF1E88E5),
                              onTap: () => _push(
                                const _NoticesStandaloneScreen(
                                  initial: NoticesSubTab.main,
                                  title: "본교 공지",
                                ),
                              ),
                            ),
                            _MoreMenuItem(
                              icon: Icons.menu_book_outlined,
                              label: "교수학습",
                              color: const Color(0xFF7B1FA2),
                              onTap: () => _push(
                                const _NoticesStandaloneScreen(
                                  initial: NoticesSubTab.ctl,
                                  title: "교수학습",
                                ),
                              ),
                            ),
                            _MoreMenuItem(
                              icon: Icons.emoji_events_outlined,
                              label: "역량관리",
                              color: const Color(0xFFEF6C00),
                              onTap: () => _push(
                                const _NoticesStandaloneScreen(
                                  initial: NoticesSubTab.mpu,
                                  title: "역량관리",
                                ),
                              ),
                            ),
                            _MoreMenuItem(
                              icon: Icons.local_library_outlined,
                              label: "도서관",
                              color: const Color(0xFF2E7D32),
                              onTap: () => _push(const LibraryScreen()),
                            ),
                            _MoreMenuItem(
                              icon: Icons.notifications_none_rounded,
                              label: "알림 내역",
                              color: const Color(0xFF3949AB),
                              onTap: () => _push(
                                const NotificationHistoryScreen(embedded: false),
                              ),
                            ),
                            _MoreMenuItem(
                              icon: Icons.restaurant_menu_rounded,
                              label: "학식 메뉴",
                              color: const Color(0xFFD84315),
                              onTap: () => _push(const FoodcourtMenuScreen()),
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
                              icon: Icons.person_add_alt_1_outlined,
                              label: "프로필 설정",
                              color: const Color(0xFF00838F),
                              onTap: () =>
                                  _push(const _ProfileSetupLoaderScreen()),
                            ),
                            _MoreMenuItem(
                              icon: Icons.code_rounded,
                              label: "오픈소스",
                              color: const Color(0xFF455A64),
                              onTap: () =>
                                  _push(const OpenSourceLicensesScreen()),
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
                              color: scheme.onSurfaceVariant,
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

/// 더보기 탭과 톤을 맞춘 앱 정보 — 개인정보·오픈소스를 동일한 행 스타일로 묶습니다.
class _AboutAppDialog extends StatelessWidget {
  const _AboutAppDialog({
    required this.onPrivacy,
    required this.onLicenses,
  });

  final VoidCallback onPrivacy;
  final VoidCallback onLicenses;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final MjcSurfaceTokens tokens =
        Theme.of(context).extension<MjcSurfaceTokens>()!;

    final List<Color> headerGradient = isDark
        ? tokens.dashboardGradients[0]
        : const [Color(0xFF0D47A1), Color(0xFF1976D2)];

    const Color licenseSwatch = Color(0xFF455A64);
    final Color licenseTint = isDark && licenseSwatch.computeLuminance() < 0.22
        ? Color.lerp(licenseSwatch, scheme.onSurface, 0.52)!
        : licenseSwatch;

    final Color legalCardBg = isDark
        ? tokens.surfaceContainer.withValues(alpha: 0.65)
        : scheme.surfaceContainerLow;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Material(
          color: scheme.surface,
          elevation: isDark ? 2 : 4,
          shadowColor: Colors.black.withValues(alpha: isDark ? 0.55 : 0.18),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: headerGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.school_rounded,
                          size: 28,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "MJC in one",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "버전 1.0.0",
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "© 2026 명지전문대학교",
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.78),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                child: Text(
                  "법적 고지",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: legalCardBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      children: [
                        _AboutAppLinkTile(
                          backgroundColor: legalCardBg,
                          icon: Icons.privacy_tip_outlined,
                          iconTint: scheme.primary,
                          title: "개인정보처리방침",
                          subtitle: "수집 항목·이용 목적을 확인합니다.",
                          onTap: onPrivacy,
                        ),
                        Container(
                          height: 1,
                          width: double.infinity,
                          color: scheme.outlineVariant.withValues(alpha: 0.45),
                        ),
                        _AboutAppLinkTile(
                          backgroundColor: legalCardBg,
                          icon: Icons.integration_instructions_outlined,
                          iconTint: licenseTint,
                          title: "오픈소스 라이선스",
                          subtitle: "사용 중인 라이브러리 고지를 봅니다.",
                          onTap: onLicenses,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text("닫기"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutAppLinkTile extends StatelessWidget {
  const _AboutAppLinkTile({
    required this.backgroundColor,
    required this.icon,
    required this.iconTint,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Color backgroundColor;
  final IconData icon;
  final Color iconTint;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color inkNeutral = scheme.onSurface.withValues(alpha: 0.06);
    final Color inkPressed = scheme.onSurface.withValues(alpha: 0.10);

    return Material(
      color: backgroundColor,
      surfaceTintColor: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        overlayColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          if (states.contains(WidgetState.pressed)) {
            return inkPressed;
          }
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused)) {
            return inkNeutral;
          }
          return null;
        }),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconTint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconTint, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.25,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant,
                size: 22,
              ),
            ],
          ),
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
        final ColorScheme scheme = Theme.of(context).colorScheme;
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        final MjcSurfaceTokens tokens =
            Theme.of(context).extension<MjcSurfaceTokens>()!;

        final Widget row = Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: isDark
                  ? tokens.surfaceContainer
                  : Colors.white.withValues(alpha: 0.18),
              child: Icon(
                signedIn ? Icons.person_rounded : Icons.login_rounded,
                // Dark `ColorScheme.primary` is navy; on `surfaceContainer` the glyph reads too dim.
                color: isDark ? tokens.sourceMjc : Colors.white,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    signedIn ? "로그인됨" : "로그인이 필요합니다",
                    style: TextStyle(
                      color: isDark ? scheme.onSurface : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (signedIn) ...[
                    const SizedBox(height: 4),
                    Text(
                      user.email ?? "MJC 계정",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark
                            ? scheme.onSurfaceVariant
                            : Colors.white.withValues(alpha: 0.86),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: isDark
                    ? scheme.primary
                    : Colors.white.withValues(alpha: 0.16),
                foregroundColor:
                    isDark ? scheme.onPrimary : Colors.white,
              ),
              onPressed: signedIn ? () => onLogout() : onLogin,
              child: Text(signedIn ? "로그아웃" : "로그인"),
            ),
          ],
        );

        if (isDark) {
          return Material(
            color: scheme.surface,
            elevation: 1,
            shadowColor: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: row,
            ),
          );
        }

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
          child: row,
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    // Very dark accent swatches (e.g. blue grey 900 on "전체 기능") disappear on dark cards.
    final Color accent = isDark && color.computeLuminance() < 0.22
        ? Color.lerp(color, scheme.onSurface, 0.52)!
        : color;
    return Material(
      color: scheme.surface,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
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
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant,
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

class _NoticesStandaloneScreen extends StatefulWidget {
  const _NoticesStandaloneScreen({
    required this.initial,
    required this.title,
  });

  final NoticesSubTab initial;
  final String title;

  @override
  State<_NoticesStandaloneScreen> createState() =>
      _NoticesStandaloneScreenState();
}

class _NoticesStandaloneScreenState extends State<_NoticesStandaloneScreen> {
  late final ValueNotifier<NoticesSubTab> _subTabNotifier =
      ValueNotifier<NoticesSubTab>(widget.initial);

  @override
  void dispose() {
    _subTabNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: NoticesTabScreen(subTabNotifier: _subTabNotifier),
    );
  }
}

class _AllFeaturesScreen extends StatelessWidget {
  const _AllFeaturesScreen();

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<_FeatureEntry> items = [
      _FeatureEntry(
        icon: Icons.school_outlined,
        title: "본교 공지",
        subtitle: "학교 공지/홈페이지",
        onTap: () => _push(
          context,
          const _NoticesStandaloneScreen(
            initial: NoticesSubTab.main,
            title: "본교 공지",
          ),
        ),
      ),
      _FeatureEntry(
        icon: Icons.menu_book_outlined,
        title: "교수학습",
        subtitle: "CTL 공지/자료",
        onTap: () => _push(
          context,
          const _NoticesStandaloneScreen(
            initial: NoticesSubTab.ctl,
            title: "교수학습",
          ),
        ),
      ),
      _FeatureEntry(
        icon: Icons.emoji_events_outlined,
        title: "역량관리",
        subtitle: "MPU 공지/프로그램",
        onTap: () => _push(
          context,
          const _NoticesStandaloneScreen(
            initial: NoticesSubTab.mpu,
            title: "역량관리",
          ),
        ),
      ),
      _FeatureEntry(
        icon: Icons.local_library_outlined,
        title: "도서관",
        subtitle: "자료 검색",
        onTap: () => _push(context, const LibraryScreen()),
      ),
      _FeatureEntry(
        icon: Icons.notifications_none_rounded,
        title: "알림 내역",
        subtitle: "수신 알림 기록",
        onTap: () =>
            _push(context, const NotificationHistoryScreen(embedded: false)),
      ),
      _FeatureEntry(
        icon: Icons.restaurant_menu_rounded,
        title: "학식 메뉴",
        subtitle: "식단/가격",
        onTap: () => _push(context, const FoodcourtMenuScreen()),
      ),
      _FeatureEntry(
        icon: Icons.event_note_outlined,
        title: "학사일정",
        subtitle: "다가오는 일정",
        onTap: () => _push(context, const AcademicScheduleScreen()),
      ),
      _FeatureEntry(
        icon: Icons.map_outlined,
        title: "캠퍼스 약도",
        subtitle: "건물 위치",
        onTap: () => _push(context, const CampusMapScreen()),
      ),
      _FeatureEntry(
        icon: Icons.person_outline_rounded,
        title: "마이페이지",
        subtitle: "계정/개인 기능",
        onTap: () => _push(context, const MyPageScreen()),
      ),
      _FeatureEntry(
        icon: Icons.settings_outlined,
        title: "설정",
        subtitle: "앱 설정",
        onTap: () => _push(context, const SettingsScreen()),
      ),
      _FeatureEntry(
        icon: Icons.person_add_alt_1_outlined,
        title: "프로필 설정",
        subtitle: "초기 설정/동기화",
        onTap: () => _push(context, const _ProfileSetupLoaderScreen()),
      ),
      _FeatureEntry(
        icon: Icons.code_rounded,
        title: "오픈소스 라이선스",
        subtitle: "사용 라이브러리",
        onTap: () => _push(context, const OpenSourceLicensesScreen()),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text("앱 기능 전체")),
      body: ListView.separated(
        itemCount: items.length,
        padding: const EdgeInsets.symmetric(vertical: 8),
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.6)),
        itemBuilder: (context, index) {
          final _FeatureEntry e = items[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: scheme.primary.withValues(alpha: 0.10),
              foregroundColor: scheme.primary,
              child: Icon(e.icon),
            ),
            title: Text(e.title),
            subtitle: Text(e.subtitle),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: e.onTap,
          );
        },
      ),
    );
  }
}

class _FeatureEntry {
  const _FeatureEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

class _ProfileSetupLoaderScreen extends StatelessWidget {
  const _ProfileSetupLoaderScreen();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MpuProfile>(
      future: loadMpuProfile(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return ProfileSetupScreen(initialProfile: snapshot.data!);
      },
    );
  }
}
