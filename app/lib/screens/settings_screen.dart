import "package:flutter/material.dart";
import "package:mio_notice/notification_sources.dart";
import "package:mio_notice/screens/open_source_licenses_screen.dart";
import "package:mio_notice/theme/app_colors.dart";
import "package:mio_notice/utils/snack_bar_utils.dart";
import "package:mio_notice/widgets/scroll_to_top_scope.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:url_launcher/url_launcher.dart";

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _allNoticesEnabled = true;
  List<String> _keywords = [];
  List<String> _enabledSources = List<String>.from(kNotificationSourceIds);
  final ScrollController _scrollController = ScrollController();
  ScrollToTopCoordinator? _scrollRouteCoordinator;
  bool _registeredScrollRoute = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _scrollController.addListener(_onSettingsScroll);
  }

  void _onSettingsScroll() {
    if (!mounted) return;
    _scrollRouteCoordinator?.reportRouteScroll(
      _scrollController.offset,
      ScrollFabMetrics.viewportHeightInScrollListener(_scrollController),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_registeredScrollRoute) return;
    final ScrollToTopCoordinator? c = ScrollToTopScope.maybeOf(context);
    if (c != null) {
      _scrollRouteCoordinator = c;
      c.pushRouteHandler(_scrollContentToTop);
      _registeredScrollRoute = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        c.reportRouteScroll(
          _scrollController.offset,
          ScrollFabMetrics.viewportHeightForThreshold(_scrollController, context),
        );
      });
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
    _scrollController.removeListener(_onSettingsScroll);
    if (_registeredScrollRoute) {
      _scrollRouteCoordinator?.popRouteHandler();
    }
    _scrollController.dispose();
    super.dispose();
  }

  /// 설정값 로드
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _allNoticesEnabled = prefs.getBool("allNoticesEnabled") ?? true;
      _keywords = prefs.getStringList("keywords") ?? [];
      final stored = prefs.getStringList(kNotificationSourcesPrefKey);
      if (stored == null || stored.isEmpty) {
        _enabledSources = defaultNotificationSources();
      } else {
        _enabledSources = kNotificationSourceIds
            .where((id) => stored.contains(id))
            .toList();
        if (_enabledSources.isEmpty) {
          _enabledSources = defaultNotificationSources();
        }
      }
    });
  }

  /// 메인 탭의 [BottomAppBar] 높이와 맞춤. SnackBar가 라우트 아래로 남아도 네비를 가리지 않게 함.
  EdgeInsets _snackBarMargin(BuildContext context) {
    const double mainBottomNavHeight = 10;
    final double safeBottom = MediaQuery.paddingOf(context).bottom;
    return EdgeInsets.fromLTRB(16, 0, 16, safeBottom + mainBottomNavHeight + 12);
  }

  /// 전체 알림 스위치 저장
  Future<void> _toggleAllNotices(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("allNoticesEnabled", value);
    setState(() {
      _allNoticesEnabled = value;
    });
    if (mounted) {
      final message = value ? "전체 알림이 활성화되었습니다." : "키워드 알림 모드로 전환되었습니다.";
      SnackBarUtils.showUnique(
        context,
        key: "settings_all_notices_${value ? "on" : "off"}",
        snackBar: SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: _snackBarMargin(context),
          content: Text(message),
        ),
      );
    }
  }

  Future<void> _setSourceEnabled(String sourceId, bool enabled) async {
    if (!kNotificationSourceIds.contains(sourceId)) return;
    final next = Set<String>.from(_enabledSources);
    if (enabled) {
      next.add(sourceId);
    } else {
      next.remove(sourceId);
    }
    if (next.isEmpty) {
      if (mounted) {
        SnackBarUtils.showUnique(
          context,
          key: "settings_sources_min_one",
          snackBar: SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: _snackBarMargin(context),
            content: const Text("알림 출처는 최소 하나 선택해야 합니다."),
          ),
        );
      }
      return;
    }
    final ordered =
        kNotificationSourceIds.where((id) => next.contains(id)).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(kNotificationSourcesPrefKey, ordered);
    setState(() => _enabledSources = ordered);
  }

  /// 키워드 관리 다이얼로그
  void _showKeywordDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("맞춤 키워드 관리"),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("등록한 키워드가 포함된 공지만 알림이 옵니다.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        hintText: "예: 장학, 기숙사, 성적",
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () async {
                            final text = controller.text.trim();
                            if (text.isNotEmpty && !_keywords.contains(text)) {
                              final prefs = await SharedPreferences.getInstance();
                              _keywords.add(text);
                              await prefs.setStringList("keywords", _keywords);
                              controller.clear();
                              setDialogState(() {}); // 다이얼로그 UI 갱신
                              setState(() {}); // 배경 설정창 UI 갱신
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      children: _keywords.map((kw) {
                        return Chip(
                          label: Text(kw),
                          onDeleted: () async {
                            final prefs = await SharedPreferences.getInstance();
                            _keywords.remove(kw);
                            await prefs.setStringList("keywords", _keywords);
                            setDialogState(() {});
                            setState(() {});
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("닫기"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 개발자 이메일 문의
  Future<void> _contactDeveloper() async {
    final Uri emailLaunchUri = Uri(
      scheme: "mailto",
      path: "dlxogus0619@mjc.ac.kr",
      queryParameters: {"subject": "[MJC In One] 앱 관련 문의"},
    );
    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    } else {
      if (mounted) {
        SnackBarUtils.showUnique(
          context,
          key: "settings_mail_app_unavailable",
          snackBar: SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: _snackBarMargin(context),
            content: RichText(text: TextSpan(style: TextStyle(color: Colors.white), 
            children: [TextSpan(text: "메일 앱을 열 수 없어요. ", style: TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(text: "메일 앱 설치/계정 설정 후 다시 시도해 주세요.", style: TextStyle(fontWeight: FontWeight.w400)),]
      )),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: const Text(
          "설정",
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
      body: ListView(
        controller: _scrollController,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              "알림 설정",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          SwitchListTile(
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.primary,
            title: const Text("전체 공지사항 새글 알림"),
            subtitle: Text(
              _allNoticesEnabled
                  ? "모든 새 공지 알림을 받습니다."
                  : "키워드가 포함된 알림만 받습니다. 아래에서 키워드를 설정하세요.",
            ),
            value: _allNoticesEnabled,
            onChanged: _toggleAllNotices,
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 240),
            sizeCurve: Curves.easeInOut,
            firstCurve: Curves.easeOut,
            secondCurve: Curves.easeIn,
            crossFadeState: _allNoticesEnabled
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(height: 1),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: Text(
                    "맞춤 키워드 알림",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Text(
                    "등록한 키워드가 알림 제목·본문에 포함될 때만 표시됩니다.",
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
                ListTile(
                  title: const Text("키워드 관리"),
                  subtitle: Text(
                    _keywords.isEmpty
                        ? "키워드가 없으면 알림이 오지 않습니다."
                        : "${_keywords.length}개 키워드 감시 중",
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _showKeywordDialog,
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              "알림 받을 출처",
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ),
          SwitchListTile(
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.primary,
            title: const Text("메인 홈페이지 (mjc.ac.kr)"),
            subtitle: const Text("공지·학사·장학 등 본교 게시판"),
            value: _enabledSources.contains("mjc"),
            onChanged: (v) => _setSourceEnabled("mjc", v),
          ),
          SwitchListTile(
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.primary,
            title: const Text("CTL (ctl.mjc.ac.kr)"),
            subtitle: const Text("CTL 프로그램·공지"),
            value: _enabledSources.contains("ctl"),
            onChanged: (v) => _setSourceEnabled("ctl", v),
          ),
          SwitchListTile(
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.primary,
            title: const Text("MPU 핵심역량 (mpu.mjc.ac.kr)"),
            subtitle: const Text("핵심역량 프로그램 안내"),
            value: _enabledSources.contains("mpu"),
            onChanged: (v) => _setSourceEnabled("mpu", v),
          ),
          const Divider(height: 1),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              "앱 정보",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const ListTile(
            title: Text("앱 버전"),
            trailing: Text("1.0.0 (Build 1)"),
          ),
          ListTile(
            title: const Text("개발자에게 문의하기"),
            subtitle: const Text("불편한 점이나 건의사항을 보내주세요."),
            onTap: _contactDeveloper,
          ),
          ListTile(
            title: const Text("오픈소스 라이선스"),
            onTap: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (context) => const OpenSourceLicensesScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
