import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";
import "package:mjc_in_one/mpu_profile_prefs.dart";
import "package:mjc_in_one/screens/academic_schedule_screen.dart";
import "package:mjc_in_one/screens/app_intro_screen.dart";
import "package:mjc_in_one/screens/campus_map_screen.dart";
import "package:mjc_in_one/screens/foodcourt_menu_screen.dart";
import "package:mjc_in_one/screens/library_screen.dart";
import "package:mjc_in_one/screens/login_screen.dart";
import "package:mjc_in_one/screens/notices_tab_screen.dart";
import "package:mjc_in_one/screens/notification_history_screen.dart";
import "package:mjc_in_one/screens/profile_setup_screen.dart";
import "package:mjc_in_one/screens/settings_screen.dart";
import "package:mjc_in_one/services/auth_service.dart";
import "package:mjc_in_one/services/user_data_repository.dart";
import "package:mjc_in_one/theme/app_colors.dart";
import "package:mjc_in_one/theme/app_theme.dart";
import "package:mjc_in_one/utils/mjc_dialog.dart";
import "package:mjc_in_one/utils/mjc_snack_bar.dart";
import "package:mjc_in_one/widgets/main_navigation_scope.dart";
import "package:mjc_in_one/widgets/scroll_to_top_scope.dart";

BorderSide _moreScreenCardBorderSide(bool isDark) => BorderSide(
      color: isDark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.black.withValues(alpha: 0.04),
    );

Border _moreScreenCardBorder(bool isDark) =>
    Border.fromBorderSide(_moreScreenCardBorderSide(isDark));

class MoreTabScreen extends StatefulWidget {
  const MoreTabScreen({
    super.key,
    this.onNavigate,
  });

  /// [MainNavigationScreen] 하단 탭 전환. 없으면 기존처럼 푸시 라우트만 사용합니다.
  final MainNavigationNavigate? onNavigate;

  @override
  State<MoreTabScreen> createState() => _MoreTabScreenState();
}

class _MoreTabScreenState extends State<MoreTabScreen> {
  final ScrollController _scrollController = ScrollController();
  ScrollToTopCoordinator? _scrollToTopCoordinator;
  bool _isListView = false;

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
    for (final position in _scrollController.positions) {
      position.animateTo(
        0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
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

  void _goToMainTab(int tabIndex, {NoticesSubTab? noticesSubTab}) {
    final void Function(int, {NoticesSubTab? noticesSubTab})? navigate =
        widget.onNavigate;
    if (navigate == null) return;
    Navigator.of(context).pop();
    navigate(tabIndex, noticesSubTab: noticesSubTab);
  }

  Future<void> _confirmSignOut() async {
    final bool? confirmed = await showMjcLogoutDialog(context);
    if (confirmed != true || !mounted) return;
    await _signOut();
  }

  Future<void> _signOut() async {
    await UserDataRepository.instance.pushSnapshotToCloud();
    await clearMpuProfile();
    await AuthService.instance.signOut();
    if (!mounted) return;
    showMjcSnackBar(context, message: "로그아웃되었습니다.");
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("더보기"),
        actions: [
          IconButton(
            icon: Icon(_isListView ? Icons.grid_view_rounded : Icons.view_list_rounded),
            tooltip: _isListView ? "그리드로 보기" : "리스트로 보기",
            onPressed: () {
              setState(() {
                _isListView = !_isListView;
              });
            },
          ),
          const SizedBox(width: 8),
        ],
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
                          onLogout: _confirmSignOut,
                        ),
                        const SizedBox(height: 18),
                        Builder(
                          builder: (context) {
                            final MjcSurfaceTokens tokens =
                                Theme.of(context)
                                    .extension<MjcSurfaceTokens>()!;
                            Color dashAccent(int index) =>
                                tokens.dashboardGradients[index][0];

                            final List<_MoreMenuItem> menuItems = [
                              _MoreMenuItem(
                                icon: Icons.person_outline_rounded,
                                label: "마이페이지",
                                color: AppColors.primary,
                                isList: _isListView,
                                onTap: () => _goToMainTab(MainNavTabIndex.mypage),
                              ),
                              _MoreMenuItem(
                                icon: Icons.school_outlined,
                                label: "본교 공지",
                                color: dashAccent(0),
                                isList: _isListView,
                                onTap: () => _goToMainTab(
                                  MainNavTabIndex.notices,
                                  noticesSubTab: NoticesSubTab.main,
                                ),
                              ),
                              _MoreMenuItem(
                                icon: Icons.menu_book_outlined,
                                label: "교수학습",
                                color: dashAccent(1),
                                isList: _isListView,
                                onTap: () => _goToMainTab(
                                  MainNavTabIndex.notices,
                                  noticesSubTab: NoticesSubTab.ctl,
                                ),
                              ),
                              _MoreMenuItem(
                                icon: Icons.emoji_events_outlined,
                                label: "역량관리",
                                color: dashAccent(2),
                                isList: _isListView,
                                onTap: () => _goToMainTab(
                                  MainNavTabIndex.notices,
                                  noticesSubTab: NoticesSubTab.mpu,
                                ),
                              ),
                              _MoreMenuItem(
                                icon: Icons.local_library_outlined,
                                label: "도서관",
                                color: dashAccent(3),
                                isList: _isListView,
                                onTap: () => _push(const LibraryScreen()),
                              ),
                              _MoreMenuItem(
                                icon: Icons.notifications_none_rounded,
                                label: "알림 내역",
                                color: const Color(0xFF3949AB),
                                isList: _isListView,
                                onTap: () => _push(
                                  const NotificationHistoryScreen(embedded: false),
                                ),
                              ),
                              _MoreMenuItem(
                                icon: Icons.restaurant_menu_rounded,
                                label: "학식 메뉴",
                                color: const Color(0xFFD84315),
                                isList: _isListView,
                                onTap: () => _push(const FoodcourtMenuScreen()),
                              ),
                              _MoreMenuItem(
                                icon: Icons.event_note_outlined,
                                label: "학사일정",
                                color: dashAccent(4),
                                isList: _isListView,
                                onTap: () => _push(const AcademicScheduleScreen()),
                              ),
                              _MoreMenuItem(
                                icon: Icons.calendar_month_rounded,
                                label: "시간표",
                                color: AppColors.primary,
                                isList: _isListView,
                                onTap: () => _goToMainTab(MainNavTabIndex.timetable),
                              ),
                              _MoreMenuItem(
                                icon: Icons.map_outlined,
                                label: "캠퍼스 약도",
                                color: dashAccent(5),
                                isList: _isListView,
                                onTap: () => _push(const CampusMapScreen()),
                              ),
                              _MoreMenuItem(
                                icon: Icons.person_add_alt_1_outlined,
                                label: "프로필 설정",
                                color: const Color(0xFF00838F),
                                isList: _isListView,
                                onTap: () => _push(const _ProfileSetupLoaderScreen()),
                              ),
                              _MoreMenuItem(
                                icon: Icons.settings_outlined,
                                label: "설정",
                                color: const Color(0xFF546E7A),
                                isList: _isListView,
                                onTap: () => _push(const SettingsScreen()),
                              ),
                              _MoreMenuItem(
                                icon: Icons.help_outline_rounded,
                                label: "도움말",
                                color: const Color(0xFFF57C00),
                                isList: _isListView,
                                onTap: () => Navigator.of(context).push<void>(
                                  AppIntroScreen.route(
                                    onNavigate: widget.onNavigate,
                                  ),
                                ),
                              ),
                            ];

                            return _isListView
                                ? _MenuList(items: menuItems)
                                : _MenuGrid(items: menuItems);
                          },
                        ),
                        const SizedBox(height: 24),
                        Center(
                          child: Text(
                            "MJC ONE v1.0.0(Alpha)",
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

        const EdgeInsets bannerPadding =
            EdgeInsets.symmetric(horizontal: 16, vertical: 16);

        final Widget row = Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              child: Icon(
                signedIn ? Icons.person_rounded : Icons.login_rounded,
                size: 22,
                // Dark `ColorScheme.primary` is navy; on `surfaceContainer` the glyph reads too dim.
                color: isDark ? tokens.sourceMjc : Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    signedIn ? "로그인됨" : "로그인이 필요합니다",
                    style: TextStyle(
                      color: isDark ? scheme.onSurface : Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (signedIn) ...[
                    const SizedBox(height: 3),
                    Text(
                      user.email ?? "MJC 계정",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark
                            ? scheme.onSurfaceVariant
                            : Colors.white.withValues(alpha: 0.86),
                        fontSize: 11,
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: signedIn ? () => onLogout() : onLogin,
              child: Text(signedIn ? "로그아웃" : "로그인"),
            ),
          ],
        );

        const List<BoxShadow> bannerShadow = [
          BoxShadow(
            color: Color(0x1A000000), // opacity 0.10
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ];

        if (isDark) {
          return Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: _moreScreenCardBorder(isDark),
              boxShadow: bannerShadow,
            ),
            padding: bannerPadding,
            child: row,
          );
        }

        return Container(
          padding: bannerPadding,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: _moreScreenCardBorder(isDark),
            boxShadow: bannerShadow,
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

class _MenuList extends StatelessWidget {
  const _MenuList({required this.items});

  final List<_MoreMenuItem> items;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
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
    this.isList = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isList;

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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: _moreScreenCardBorderSide(isDark),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: isList
              ? Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: accent, size: 22),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
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
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
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
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: scheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Center(
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: scheme.onSurfaceVariant,
                        size: 20,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
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
