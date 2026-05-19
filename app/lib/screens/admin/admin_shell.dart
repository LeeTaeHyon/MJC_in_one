import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";
import "package:mjc_in_one/screens/admin/admin_auth_service.dart";
import "package:mjc_in_one/screens/admin/admin_inquiries_screen.dart";
import "package:mjc_in_one/screens/admin/admin_login_screen.dart";
import "package:mjc_in_one/screens/admin/admin_reports_screen.dart";
import "package:mjc_in_one/screens/admin/admin_responsive.dart";

/// 관리자 콘솔 진입점.
///
/// - 로그인 안 되어 있으면 [AdminLoginScreen]
/// - 로그인 됐지만 admin 화이트리스트에 없으면 권한 없음 화면 + 로그아웃 버튼
/// - 통과하면 신고함 / 문의함 탭 노출
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _tab = 0;
  Future<bool>? _adminCheckFuture;
  String? _checkedForUid;

  Future<bool> _ensureAdminCheck(User user) {
    if (_checkedForUid != user.uid) {
      _checkedForUid = user.uid;
      _adminCheckFuture = AdminAuthService.instance.isAdmin(user.uid);
    }
    return _adminCheckFuture!;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AdminAuthService.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _LoadingScaffold();
        }
        final user = snap.data;
        if (user == null) {
          return AdminLoginScreen(
            onSignedIn: () {
              setState(() {
                _checkedForUid = null;
                _adminCheckFuture = null;
              });
            },
          );
        }
        return FutureBuilder<bool>(
          future: _ensureAdminCheck(user),
          builder: (context, adminSnap) {
            if (adminSnap.connectionState == ConnectionState.waiting) {
              return const _LoadingScaffold();
            }
            if (adminSnap.data == true) {
              return _buildAdminBody(context, user);
            }
            return _NotAdminScaffold(email: user.email);
          },
        );
      },
    );
  }

  Widget _buildAdminBody(BuildContext context, User user) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final double width = MediaQuery.sizeOf(context).width;
    final bool isMobile = adminIsMobile(context);
    final String accountLabel = user.email ?? user.uid;
    final Widget tabBody = IndexedStack(
      index: _tab,
      children: const [
        AdminReportsScreen(),
        AdminInquiriesScreen(),
      ],
    );

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(
          isMobile || width < 520 ? "관리자" : "MJC In One 관리자",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        actions: [
          if (!isMobile && width >= 720)
            Tooltip(
              message: accountLabel,
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: width * 0.22),
                    child: Text(
                      accountLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ),
              ),
            ),
          IconButton(
            tooltip: "로그아웃 ($accountLabel)",
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AdminAuthService.instance.signOut();
              if (!mounted) return;
              setState(() {
                _checkedForUid = null;
                _adminCheckFuture = null;
              });
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: scheme.outline.withValues(alpha: 0.4),
            height: 1.0,
          ),
        ),
      ),
      body: isMobile
          ? tabBody
          : Row(
              children: [
                NavigationRail(
                  extended: width >= 900,
                  selectedIndex: _tab,
                  onDestinationSelected: (i) => setState(() => _tab = i),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.report_outlined),
                      selectedIcon: Icon(Icons.report),
                      label: Text("신고함"),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.support_agent_outlined),
                      selectedIcon: Icon(Icons.support_agent),
                      label: Text("문의함"),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: tabBody),
              ],
            ),
      bottomNavigationBar: isMobile
          ? NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() => _tab = i),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.report_outlined),
                  selectedIcon: Icon(Icons.report),
                  label: "신고함",
                ),
                NavigationDestination(
                  icon: Icon(Icons.support_agent_outlined),
                  selectedIcon: Icon(Icons.support_agent),
                  label: "문의함",
                ),
              ],
            )
          : null,
    );
  }
}

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _NotAdminScaffold extends StatelessWidget {
  const _NotAdminScaffold({this.email});

  final String? email;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text("관리자 권한 필요"),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 48, color: scheme.error),
                const SizedBox(height: 12),
                Text(
                  "이 계정은 관리자 권한이 없습니다.",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                if (email != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    email!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text("다른 계정으로 로그인"),
                  onPressed: () async {
                    await AdminAuthService.instance.signOut();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
