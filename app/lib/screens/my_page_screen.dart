import "dart:ui" show ImageFilter;

import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/foundation.dart" show kIsWeb;
import "package:flutter/material.dart";
import "package:mio_notice/mpu_profile_prefs.dart";
import "package:mio_notice/screens/common_webview_screen.dart";
import "package:mio_notice/screens/login_screen.dart";
import "package:mio_notice/screens/mpu_profile_import_screen.dart";
import "package:mio_notice/services/auth_service.dart";
import "package:mio_notice/services/notice_manager.dart";
import "package:mio_notice/services/user_data_repository.dart";
import "package:mio_notice/theme/app_colors.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:url_launcher/url_launcher.dart";

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  /// 설정 화면과 동일한 본문·카드 톤.
  static const Color _pageBackground = Color(0xFFF5F7F9);
  static const Color _cardBorderLight = Color(0xFFEDEDED);

  bool _loading = true;
  List<_MyNotice> _pinned = const [];
  List<_MyNotice> _favorites = const [];
  MpuProfile _mpuProfile = const MpuProfile(
    name: "",
    grade: "",
    mileage: "",
  );

  @override
  void initState() {
    super.initState();
    _loadPinnedAndFavorites();
    _loadMpuProfile();
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

  Future<void> _loadMpuProfile() async {
    final profile = await loadMpuProfile();
    if (!mounted) return;
    setState(() => _mpuProfile = profile);
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

  Future<void> _openMpuProfileImport() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("마이페이지 가져오기는 모바일 앱에서 지원합니다.")),
      );
      return;
    }

    final bool? imported = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const MpuProfileImportScreen(),
      ),
    );
    if (imported == true) {
      await _loadMpuProfile();
    }
  }

  Future<void> _signOut() async {
    await UserDataRepository.instance.pushSnapshotToCloud();
    await AuthService.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Color _hairlineBorderColor() {
    final bool light = Theme.of(context).brightness == Brightness.light;
    return light
        ? _cardBorderLight
        : Theme.of(context).colorScheme.outline.withValues(alpha: 0.35);
  }

  Widget _myPageCard({required Widget child}) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool light = Theme.of(context).brightness == Brightness.light;
    return Material(
      color: scheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color:
              light ? _cardBorderLight : scheme.outline.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final String email = user?.email ?? "로그인이 필요합니다";
    final bool hasMpuProfile = _mpuProfile.hasAnyValue;
    final bool light = Theme.of(context).brightness == Brightness.light;
    final Color pageBg = light
        ? _pageBackground
        : Theme.of(context).colorScheme.surfaceContainerLow;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: pageBg,
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
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.14),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: _openMpuProfileImport,
                            icon: const Icon(Icons.cloud_download_outlined),
                            label: const Text(
                              "마이페이지 가져오기",
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(height: 14),
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
                                    if (hasMpuProfile)
                                      Text(
                                        _mpuProfile.name.trim().isEmpty
                                            ? "MPU 사용자"
                                            : _mpuProfile.name.trim(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.2,
                                        ),
                                      )
                                    else ...[
                                      const _BlurredProfilePlaceholder(
                                        width: 86,
                                        height: 20,
                                      ),
                                      const SizedBox(height: 4),
                                      const _BlurredProfilePlaceholder(
                                        width: 112,
                                        height: 16,
                                      ),
                                    ],
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
                                  icon: Icons.badge_outlined,
                                  label: "학년",
                                  value: _mpuProfile.grade.trim(),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _ProfileChip(
                                  icon: Icons.stars_rounded,
                                  label: "내 마일리지",
                                  value: _mpuProfile.mileage.trim(),
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
              color: pageBg,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _MyPageSectionHeader(
                    title: "고정·즐겨찾기 공지",
                    icon: Icons.bookmarks_outlined,
                  ),
                  _myPageCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TabBar(
                          indicatorColor: Theme.of(context).colorScheme.primary,
                          indicatorWeight: 2,
                          labelColor: Theme.of(context).colorScheme.primary,
                          unselectedLabelColor: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.45),
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
                        Divider(
                            height: 1,
                            thickness: 1,
                            color: _hairlineBorderColor()),
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
                                      dividerColor: _hairlineBorderColor(),
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
                                      dividerColor: _hairlineBorderColor(),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _MyPageSectionHeader(
                    title: "계정 설정",
                    icon: Icons.manage_accounts_outlined,
                  ),
                  _myPageCard(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.mail_outline_rounded),
                          title: const Text(
                            "이메일 변경",
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(email),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("추후 연결 예정입니다.")),
                            );
                          },
                        ),
                        Divider(
                            height: 1,
                            thickness: 1,
                            color: _hairlineBorderColor()),
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
                  const SizedBox(height: 16),
                  _myPageCard(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _signOut,
                      child: const SizedBox(
                        height: 56,
                        width: double.infinity,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
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
                if (value.isEmpty)
                  const _BlurredProfilePlaceholder(
                    width: double.infinity,
                    height: 16,
                  )
                else
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
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

class _BlurredProfilePlaceholder extends StatelessWidget {
  const _BlurredProfilePlaceholder({
    required this.width,
    required this.height,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(6),
        ),
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
    required this.dividerColor,
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
  final Color dividerColor;

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
                          const _MiniChip(
                            label: "N",
                            background: Color(0xFFE53935),
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
      separatorBuilder: (_, __) =>
          Divider(height: 1, thickness: 1, color: dividerColor),
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

class _MyPageSectionHeader extends StatelessWidget {
  const _MyPageSectionHeader({required this.title, this.icon});

  final String title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final Color accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: accent),
            const SizedBox(width: 8),
          ],
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: accent,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}
