import "package:flutter/foundation.dart" show kIsWeb;
import "package:flutter/material.dart";
import "package:mio_notice/screens/common_webview_screen.dart";
import "package:mio_notice/services/notice_manager.dart";
import "package:mio_notice/theme/app_colors.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:url_launcher/url_launcher.dart";

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  bool _loading = true;
  List<_MyNotice> _pinned = const [];
  List<_MyNotice> _favorites = const [];

  // TODO: 로그인 구현 후 사용자 정보 바인딩
  final String _userName = "홍길동";
  final String _studentId = "202401234";
  final String _department = "컴퓨터공학과";
  final String _grade = "2학년";
  final String _email = "hong@mjc.ac.kr";

  @override
  void initState() {
    super.initState();
    _loadPinnedAndFavorites();
  }

  String _boardLabel(String boardId) {
    const labels = <String, String>{
      "main_notice": "공지",
      "main_academic": "학사",
      "main_scholarship": "장학",
      "ctl_notice": "CTL",
      "ctl_programs": "CTL",
      "mpu_programs": "역량",
      "combined_dashboard": "대시보드",
    };
    return labels[boardId] ?? boardId;
  }

  String _boardSubtitle(String boardId) {
    if (boardId.startsWith("main_")) return "본교 공지";
    if (boardId.startsWith("ctl_")) return "학사공지";
    if (boardId == "mpu_programs") return "프로그램";
    return "공지";
  }

  String _chipLabel(String boardId) {
    if (boardId == "main_academic") return "학사";
    if (boardId == "main_scholarship") return "장학";
    if (boardId == "main_notice") return "공지";
    if (boardId.startsWith("ctl_")) return "학습";
    if (boardId == "mpu_programs") return "역량";
    return "공지";
  }

  Color _chipColor(String boardId) {
    if (boardId == "main_academic") return const Color(0xFF1976D2);
    if (boardId == "main_scholarship") return const Color(0xFF1976D2);
    if (boardId.startsWith("ctl_")) return const Color(0xFF2962FF);
    if (boardId == "mpu_programs") return const Color(0xFF7986CB);
    return const Color(0xFF1976D2);
  }

  String _formatDate(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return "";
    // 이미 "2026.04.10" 형태가 많아 그대로 사용
    return s.split("~").first.trim();
  }

  String _noticeKey(String boardId, Map<String, dynamic> data) {
    String pickDate() {
      final String date =
          (data["date"] ?? data["reg_date"] ?? "").toString().trim();
      return date;
    }

    if (boardId == "mpu_programs") {
      final String title = (data["title"] ?? "").toString().trim();
      final String branch = (data["branch"] ?? "").toString().trim();
      final String dDay = (data["d_day"] ?? "").toString().trim();
      return "$title|$branch|$dDay|${pickDate()}";
    }

    if (boardId.startsWith("ctl_")) {
      final String url = (data["link"] ?? data["url"] ?? "").toString().trim();
      final String title = (data["title"] ?? "").toString().trim();
      return "$url|$title|${pickDate()}";
    }

    final String id = (data["id"] ?? "").toString().trim();
    if (id.isNotEmpty) return id;
    final String url = (data["url"] ?? data["link"] ?? "").toString().trim();
    final String title = (data["title"] ?? "").toString().trim();
    return "$url|$title|${pickDate()}";
  }

  Future<void> _loadPinnedAndFavorites() async {
    setState(() => _loading = true);

    final prefs = await SharedPreferences.getInstance();
    final Set<String> keys = prefs.getKeys();

    final Map<String, Set<String>> pinnedByBoard = {};
    final Map<String, Set<String>> favByBoard = {};

    for (final k in keys) {
      if (k.startsWith("pinned_notices_")) {
        final boardId = k.substring("pinned_notices_".length);
        pinnedByBoard[boardId] =
            (prefs.getStringList(k) ?? const <String>[]).toSet();
      } else if (k.startsWith("favorite_notices_")) {
        final boardId = k.substring("favorite_notices_".length);
        favByBoard[boardId] =
            (prefs.getStringList(k) ?? const <String>[]).toSet();
      }
    }

    final Set<String> allBoards = {
      ...pinnedByBoard.keys,
      ...favByBoard.keys,
    };

    final List<_MyNotice> pinned = [];
    final List<_MyNotice> favorites = [];

    for (final boardId in allBoards) {
      final Set<String> pinnedKeys = pinnedByBoard[boardId] ?? {};
      final Set<String> favKeys = favByBoard[boardId] ?? {};
      if (pinnedKeys.isEmpty && favKeys.isEmpty) continue;

      final List<Map<String, dynamic>> notices =
          await NoticeManager().getNotices(boardId: boardId);
      for (final n in notices) {
        final String key = _noticeKey(boardId, n);
        final bool isPinned = pinnedKeys.contains(key);
        final bool isFavorite = favKeys.contains(key);
        if (!isPinned && !isFavorite) continue;

        final String title = (n["title"] ?? "").toString();
        final String date = (n["date"] ?? n["reg_date"] ?? "").toString();
        final String url = (n["url"] ?? n["link"] ?? "").toString();
        final String subtitle = _boardLabel(boardId);

        final item = _MyNotice(
          boardId: boardId,
          title: title.isEmpty ? "공지사항" : title,
          subtitle: subtitle,
          date: date,
          url: url,
        );

        if (isPinned) pinned.add(item);
        if (isFavorite) favorites.add(item);
      }
    }

    int cmp(_MyNotice a, _MyNotice b) => b.date.compareTo(a.date);
    pinned.sort(cmp);
    favorites.sort(cmp);

    if (!mounted) return;
    setState(() {
      _pinned = pinned;
      _favorites = favorites;
      _loading = false;
    });
  }

  Future<void> _openNotice(_MyNotice item) async {
    final String url = item.url.trim();
    if (url.isEmpty) return;
    if (kIsWeb) {
      await launchUrl(Uri.parse(url), webOnlyWindowName: "_blank");
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CommonWebViewScreen(url: url, title: item.title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("마이페이지"),
        ),
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              color: AppColors.primary,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                children: [
                  _SoftCard(
                    radius: 18,
                    backgroundColor: const Color(0xFF0A43A8),
                    borderColor: Colors.white.withValues(alpha: 0.10),
                    shadow: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.person_outline_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _userName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _studentId,
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.86),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _ProfileChip(
                                  icon: Icons.school_outlined,
                                  label: "학과",
                                  value: _department,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _ProfileChip(
                                  icon: Icons.badge_outlined,
                                  label: "학년",
                                  value: _grade,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              child: Column(
                children: [
                  _SoftCard(
                    radius: 18,
                    borderColor: Colors.black.withValues(alpha: 0.08),
                    shadow: false,
                    child: Column(
                      children: [
                        TabBar(
                          indicatorColor: const Color(0xFF1A3FBB),
                          indicatorWeight: 2,
                          labelColor: const Color(0xFF1A3FBB),
                          unselectedLabelColor: Colors.black54,
                          labelStyle:
                              const TextStyle(fontWeight: FontWeight.w800),
                          unselectedLabelStyle:
                              const TextStyle(fontWeight: FontWeight.w700),
                          tabs: const [
                            Tab(
                              icon: Icon(Icons.push_pin_outlined),
                              text: "고정 공지",
                            ),
                            Tab(
                              icon: Icon(Icons.star_border_rounded),
                              text: "즐겨찾기",
                            ),
                          ],
                        ),
                        const Divider(height: 1),
                        SizedBox(
                          height: 270,
                          child: _loading
                              ? const Center(
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                )
                              : TabBarView(
                                  children: [
                                    _NoticeList(
                                      items: _pinned,
                                      emptyText: "고정한 공지가 없습니다.",
                                      leadingIcon: Icons.push_pin_rounded,
                                      leadingColor: const Color(0xFFFFC107),
                                      chipLabelFor: _chipLabel,
                                      chipColorFor: _chipColor,
                                      subtitleFor: _boardSubtitle,
                                      formatDate: _formatDate,
                                      onTap: _openNotice,
                                    ),
                                    _NoticeList(
                                      items: _favorites,
                                      emptyText: "즐겨찾기한 공지가 없습니다.",
                                      leadingIcon: Icons.star_rounded,
                                      leadingColor: const Color(0xFFFFC107),
                                      chipLabelFor: _chipLabel,
                                      chipColorFor: _chipColor,
                                      subtitleFor: _boardSubtitle,
                                      formatDate: _formatDate,
                                      onTap: _openNotice,
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "계정 설정",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _SoftCard(
                    radius: 18,
                    borderColor: Colors.black.withValues(alpha: 0.08),
                    shadow: false,
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.mail_outline_rounded),
                          title: const Text(
                            "이메일 변경",
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(_email),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("추후 연결 예정입니다.")),
                            );
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.lock_outline_rounded),
                          title: const Text(
                            "비밀번호 변경",
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text("•" * 8),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("추후 연결 예정입니다.")),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SoftCard(
                    radius: 18,
                    borderColor: Colors.black.withValues(alpha: 0.08),
                    shadow: false,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("로그아웃 로직은 추후 연결됩니다.")),
                        );
                      },
                      child: SizedBox(
                        height: 56,
                        width: double.infinity,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.logout_rounded,
                                color: Color(0xFFD4183D)),
                            SizedBox(width: 10),
                            Text(
                              "로그아웃",
                              style: TextStyle(
                                color: Color(0xFFD4183D),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileChip extends StatelessWidget {
  const _ProfileChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final Color iconBg = Colors.white.withValues(alpha: 0.18);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.18),
            Colors.white.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Icon(
              icon,
              color: Colors.white.withValues(alpha: 0.96),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
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

class _NoticeList extends StatelessWidget {
  const _NoticeList({
    required this.items,
    required this.emptyText,
    required this.leadingIcon,
    required this.leadingColor,
    required this.chipLabelFor,
    required this.chipColorFor,
    required this.subtitleFor,
    required this.formatDate,
    required this.onTap,
  });

  final List<_MyNotice> items;
  final String emptyText;
  final IconData leadingIcon;
  final Color leadingColor;
  final String Function(String boardId) chipLabelFor;
  final Color Function(String boardId) chipColorFor;
  final String Function(String boardId) subtitleFor;
  final String Function(String raw) formatDate;
  final Future<void> Function(_MyNotice item) onTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          emptyText,
          style: TextStyle(
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 4),
      itemBuilder: (context, i) {
        final item = items[i];
        final String chipLabel = chipLabelFor(item.boardId);
        final Color chipColor = chipColorFor(item.boardId);
        final String sub = subtitleFor(item.boardId);
        final String date = formatDate(item.date);

        return InkWell(
          onTap: () => onTap(item),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Icon(leadingIcon, color: leadingColor, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _MiniChip(
                            label: "N",
                            background: const Color(0xFFE53935),
                            foreground: Colors.white,
                            radius: 4,
                          ),
                          const SizedBox(width: 6),
                          _MiniChip(
                            label: chipLabel,
                            background: chipColor.withValues(alpha: 0.12),
                            foreground: chipColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              sub,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.55),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14.5,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_month_outlined,
                            size: 14,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.45),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            date,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.50),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.35),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemCount: items.length,
    );
  }
}

class _SoftCard extends StatelessWidget {
  const _SoftCard({
    required this.child,
    this.radius = 14,
    this.backgroundColor = Colors.white,
    this.borderColor,
    this.shadow = true,
  });

  final Widget child;
  final double radius;
  final Color backgroundColor;
  final Color? borderColor;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(radius),
        border: borderColor == null ? null : Border.all(color: borderColor!),
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ]
            : const [],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({
    required this.label,
    required this.background,
    required this.foreground,
    this.radius = 8,
  });

  final String label;
  final Color background;
  final Color foreground;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          height: 1.1,
        ),
      ),
    );
  }
}

class _MyNotice {
  final String boardId;
  final String title;
  final String subtitle;
  final String date;
  final String url;

  const _MyNotice({
    required this.boardId,
    required this.title,
    required this.subtitle,
    required this.date,
    required this.url,
  });
}
