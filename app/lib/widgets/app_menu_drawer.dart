import "package:flutter/material.dart";
import "package:mio_notice/notification_history_prefs.dart";
import "package:mio_notice/screens/notification_history_screen.dart";
import "package:mio_notice/screens/settings_screen.dart";
import "package:mio_notice/theme/app_colors.dart";
/// 드로어 본문(헤더 + 알림 미리보기 + 메뉴). [Drawer]·홈 슬라이드 패널 공통.
class AppMenuDrawerContent extends StatefulWidget {
  /// 메뉴/닫기 직전에 호출(스캐폴드 드로어면 pop, 홈 오버레이면 닫기 애니메이션).
  final VoidCallback closeMenu;

  /// 홈 슬라이드 패널처럼 `closeMenu` 후 [context]가 무효화되면 true. 스캐폴드 [Drawer]는 false.
  final bool closeBeforeSystemDialogs;

  /// [closeBeforeSystemDialogs]가 true일 때 다이얼로그에 사용(홈 화면 [State]의 context 등, 닫혀도 유지되는 것).
  final BuildContext? dialogContext;

  const AppMenuDrawerContent({
    super.key,
    required this.closeMenu,
    this.closeBeforeSystemDialogs = false,
    this.dialogContext,
  });

  @override
  State<AppMenuDrawerContent> createState() => _AppMenuDrawerContentState();
}

class _AppMenuDrawerContentState extends State<AppMenuDrawerContent> {
  List<Map<String, dynamic>> _previewNotices = [];
  bool _loadingNotices = true;
  int _totalNotificationCount = 0;

  @override
  void initState() {
    super.initState();
    _loadNotificationPreview();
  }

  Future<void> _loadNotificationPreview() async {
    final full = await loadNotificationHistoryNewestFirst();
    final list = full.take(3).toList();
    if (mounted) {
      setState(() {
        _previewNotices = list;
        _totalNotificationCount = full.length;
        _loadingNotices = false;
      });
    }
  }

  Future<void> _dismissNotificationAt(int newestFirstIndex) async {
    await removeNotificationHistoryAtNewestFirstIndex(newestFirstIndex);
    if (!mounted) return;
    await _loadNotificationPreview();
  }

  void _openAllNotifications(BuildContext context) {
    final BuildContext navCtx = widget.dialogContext ?? context;
    void push() {
      if (!navCtx.mounted) return;
      Navigator.push<void>(
        navCtx,
        MaterialPageRoute<void>(
          builder: (context) => const NotificationHistoryScreen(),
        ),
      );
    }

    widget.closeMenu();
    if (widget.closeBeforeSystemDialogs) {
      WidgetsBinding.instance.addPostFrameCallback((_) => push());
    } else {
      push();
    }
  }

  void _openSettings(BuildContext context) {
    final BuildContext navCtx = widget.dialogContext ?? context;
    void push() {
      if (!navCtx.mounted) return;
      Navigator.push<void>(
        navCtx,
        MaterialPageRoute<void>(
          builder: (context) => const SettingsScreen(),
        ),
      );
    }

    widget.closeMenu();
    if (widget.closeBeforeSystemDialogs) {
      WidgetsBinding.instance.addPostFrameCallback((_) => push());
    } else {
      push();
    }
  }

  BuildContext _dialogHost(BuildContext stateContext) {
    final BuildContext? anchor = widget.dialogContext;
    if (widget.closeBeforeSystemDialogs && anchor != null) return anchor;
    return stateContext;
  }

  void _showAppInfo(BuildContext stateContext) {
    final BuildContext host = _dialogHost(stateContext);

    void show() {
      if (!host.mounted) return;
      showAboutDialog(
        context: host,
        applicationName: "MJC in one",
        applicationVersion: "1.0.0",
        applicationLegalese: "© 2026 명지전문대학교",
      );
    }

    if (widget.closeBeforeSystemDialogs) {
      widget.closeMenu();
      WidgetsBinding.instance.addPostFrameCallback((_) => show());
    } else {
      show();
    }
  }

  void _showHelp(BuildContext stateContext) {
    final BuildContext host = _dialogHost(stateContext);

    void show() {
      if (!host.mounted) return;
      showDialog<void>(
        context: host,
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

    if (widget.closeBeforeSystemDialogs) {
      widget.closeMenu();
      WidgetsBinding.instance.addPostFrameCallback((_) => show());
    } else {
      show();
    }
  }

  void _openHistoryFromPreview(BuildContext context) {
    final BuildContext navCtx = widget.dialogContext ?? context;
    void push() {
      if (!navCtx.mounted) return;
      Navigator.push<void>(
        navCtx,
        MaterialPageRoute<void>(
          builder: (context) => const NotificationHistoryScreen(),
        ),
      );
    }

    widget.closeMenu();
    if (widget.closeBeforeSystemDialogs) {
      WidgetsBinding.instance.addPostFrameCallback((_) => push());
    } else {
      push();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DrawerHeader(
          onClose: widget.closeMenu,
        ),
        Expanded(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(0, 16, 0, 72),
                children: [
                  _AlertsBlock(
                    loading: _loadingNotices,
                    items: _previewNotices,
                    badgeCount: _totalNotificationCount,
                    onViewAll: () => _openAllNotifications(context),
                    onPreviewTap: () => _openHistoryFromPreview(context),
                    onDismissAt: _dismissNotificationAt,
                  ),
                  const SizedBox(height: 8),
                  _MenuBlock(
                    onSettings: () => _openSettings(context),
                    onAppInfo: () => _showAppInfo(context),
                    onHelp: () => _showHelp(context),
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
                  const SizedBox(height: 16),
                ],
              ),
              Positioned(
                right: 12,
                bottom: 12,
                child: Material(
                  color: Colors.white,
                  elevation: 2,
                  shadowColor: Colors.black26,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _showHelp(context),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Icon(
                        Icons.help_outline_rounded,
                        size: 22,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 8, 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "MJC in one",
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "명지전문대학 통합 플랫폼",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onClose,
                  splashColor: Colors.white.withValues(alpha: 0.35),
                  highlightColor: Colors.white.withValues(alpha: 0.14),
                  hoverColor: Colors.white.withValues(alpha: 0.10),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertsBlock extends StatelessWidget {
  const _AlertsBlock({
    required this.loading,
    required this.items,
    required this.badgeCount,
    required this.onViewAll,
    required this.onPreviewTap,
    required this.onDismissAt,
  });

  final bool loading;
  final List<Map<String, dynamic>> items;
  final int badgeCount;
  final VoidCallback onViewAll;
  final VoidCallback onPreviewTap;
  final Future<void> Function(int newestFirstIndex) onDismissAt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_none_rounded, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              const Text(
                "알림",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const Spacer(),
              if (!loading && badgeCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badgeCount > 99 ? "99+" : "$badgeCount",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (items.isEmpty)
            _EmptyNoticeCard()
          else
            ...List.generate(items.length, (i) {
              final m = items[i];
              return Padding(
                padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 10),
                child: _NoticePreviewCard(
                  title: "${m["title"] ?? "알림"}",
                  subtitle: "${m["body"] ?? ""}",
                  timeLabel: relativeTimeLabel(m["received_at"]?.toString()),
                  showUnreadDot: i < 2,
                  onTap: onPreviewTap,
                  onDismiss: () => onDismissAt(i),
                ),
              );
            }),
          const SizedBox(height: 14),
          Center(
            child: TextButton(
              onPressed: onViewAll,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              child: const Text("모든 알림 보기"),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyNoticeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        "최근 수신한 알림이 없습니다.",
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
      ),
    );
  }
}

class _NoticePreviewCard extends StatelessWidget {
  const _NoticePreviewCard({
    required this.title,
    required this.subtitle,
    required this.timeLabel,
    required this.showUnreadDot,
    required this.onTap,
    required this.onDismiss,
  });

  final String title;
  final String subtitle;
  final String timeLabel;
  final bool showUnreadDot;
  final VoidCallback onTap;
  final Future<void> Function() onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showUnreadDot)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 5, right: 8),
                            decoration: const BoxDecoration(
                              color: Color(0xFFE53935),
                              shape: BoxShape.circle,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Padding(
                        padding: EdgeInsets.only(left: showUnreadDot ? 16 : 0),
                        child: Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Padding(
                      padding: EdgeInsets.only(left: showUnreadDot ? 16 : 0),
                      child: Text(
                        timeLabel.isEmpty ? " " : timeLabel,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 4, 4, 4),
            child: IconButton(
              icon: Icon(Icons.close_rounded, size: 20, color: Colors.grey.shade600),
              tooltip: "삭제",
              onPressed: () => onDismiss(),
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuBlock extends StatelessWidget {
  const _MenuBlock({
    required this.onSettings,
    required this.onAppInfo,
    required this.onHelp,
  });

  final VoidCallback onSettings;
  final VoidCallback onAppInfo;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              "메뉴",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
          _MenuRow(
            icon: Icons.settings_outlined,
            label: "설정",
            onTap: onSettings,
          ),
          _MenuRow(
            icon: Icons.info_outline_rounded,
            label: "앱 정보",
            onTap: onAppInfo,
          ),
          _MenuRow(
            icon: Icons.help_outline_rounded,
            label: "도움말",
            onTap: onHelp,
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 22, color: const Color(0xFF424242)),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

/// `received_at` 예: `2026.04.12 14:30` → 상대 시간 문자열
String relativeTimeLabel(String? raw) {
  if (raw == null || raw.trim().isEmpty) return "";
  final match = RegExp(r"(\d{4})\.(\d{2})\.(\d{2})\s+(\d{1,2}):(\d{2})").firstMatch(raw);
  if (match == null) return raw;
  try {
    final y = int.parse(match.group(1)!);
    final mo = int.parse(match.group(2)!);
    final d = int.parse(match.group(3)!);
    final h = int.parse(match.group(4)!);
    final mi = int.parse(match.group(5)!);
    final then = DateTime(y, mo, d, h, mi);
    final diff = DateTime.now().difference(then);
    if (diff.isNegative) return "방금 전";
    if (diff.inMinutes < 1) return "방금 전";
    if (diff.inMinutes < 60) return "${diff.inMinutes}분 전";
    if (diff.inHours < 24) return "${diff.inHours}시간 전";
    if (diff.inDays < 7) return "${diff.inDays}일 전";
    return raw.split(" ").first;
  } catch (_) {
    return raw;
  }
}

/// 앱의 주요 부가 기능(알림, 설정 등)을 모아둔 메뉴 바(Drawer)입니다.
class AppMenuDrawer extends StatelessWidget {
  const AppMenuDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final double w = MediaQuery.sizeOf(context).width;
    return Drawer(
      width: (w * 0.86).clamp(280.0, 400.0),
      backgroundColor: Colors.white,
      child: AppMenuDrawerContent(
        closeMenu: () => Navigator.of(context).pop(),
        closeBeforeSystemDialogs: false,
      ),
    );
  }
}
