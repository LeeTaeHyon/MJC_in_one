import "package:flutter/material.dart";
import "package:mio_notice/notification_sources.dart";
import "package:mio_notice/screens/open_source_licenses_screen.dart";
import "package:mio_notice/services/notice_filter.dart";
import "package:mio_notice/theme/theme_mode_scope.dart";
import "package:mio_notice/utils/snack_bar_utils.dart";
import "package:mio_notice/widgets/scroll_to_top_scope.dart";
import "package:mio_notice/debug_session_log.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:url_launcher/url_launcher.dart";

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _allNoticesEnabled = true;
  bool _keywordNoticesEnabled = true;
  List<String> _keywords = [];
  List<String> _enabledSources = List<String>.from(kNotificationSourceIds);
  NoticeFilterState _noticeFilter = const NoticeFilterState();
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
          ScrollFabMetrics.viewportHeightForThreshold(
              _scrollController, context),
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
    if (!mounted) return;
    setState(() {
      _allNoticesEnabled = prefs.getBool("allNoticesEnabled") ?? true;
      _keywordNoticesEnabled = prefs.getBool("keywordNoticesEnabled") ?? true;
      _keywords = prefs.getStringList("keywords") ?? [];
      _noticeFilter = NoticeFilterState(
        enabled: prefs.getBool(kNoticeFilterEnabledPrefKey) ?? false,
        requireKeywordHit:
            prefs.getBool(kNoticeFilterRequireKeywordPrefKey) ?? false,
        sources: (prefs.getStringList(kNoticeFilterSourcesPrefKey) ??
                kNoticeFilterSourceOptions)
            .where(kNoticeFilterSourceOptions.contains)
            .toList(),
        types: (prefs.getStringList(kNoticeFilterTypesPrefKey) ??
                kNoticeFilterTypeOptions)
            .where(kNoticeFilterTypeOptions.contains)
            .toList(),
        excludes: prefs.getStringList(kNoticeFilterExcludesPrefKey) ?? const [],
      );
      if (_noticeFilter.sources.isEmpty || _noticeFilter.types.isEmpty) {
        _noticeFilter = _noticeFilter.copyWith(
          sources: _noticeFilter.sources.isEmpty
              ? kNoticeFilterSourceOptions
              : _noticeFilter.sources,
          types: _noticeFilter.types.isEmpty
              ? kNoticeFilterTypeOptions
              : _noticeFilter.types,
        );
      }
      final stored = prefs.getStringList(kNotificationSourcesPrefKey);
      if (stored == null || stored.isEmpty) {
        _enabledSources = defaultNotificationSources();
      } else {
        _enabledSources =
            kNotificationSourceIds.where((id) => stored.contains(id)).toList();
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
    return EdgeInsets.fromLTRB(
        16, 0, 16, safeBottom + mainBottomNavHeight + 12);
  }

  /// 전체 알림 스위치 저장
  Future<void> _toggleAllNotices(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("allNoticesEnabled", value);
    if (!mounted) return;
    setState(() {
      _allNoticesEnabled = value;
    });
    if (mounted) {
      final bool allOff = !value && !_keywordNoticesEnabled;
      final message = allOff
          ? "알람이 꺼집니다."
          : (value ? "전체 알림이 활성화되었습니다." : "전체 알림이 비활성화되었습니다.");
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

  Future<void> _toggleKeywordNotices(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("keywordNoticesEnabled", value);
    if (!mounted) return;
    setState(() => _keywordNoticesEnabled = value);

    if (!mounted) return;
    final bool allOff = !_allNoticesEnabled && !value;
    final String message = allOff
        ? "알람이 꺼집니다."
        : (value ? "키워드 알림이 활성화되었습니다." : "키워드 알림이 비활성화되었습니다.");
    SnackBarUtils.showUnique(
      context,
      key: "settings_keyword_notices_${value ? "on" : "off"}",
      snackBar: SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: _snackBarMargin(context),
        content: Text(message),
      ),
    );
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
    if (!mounted) return;
    setState(() => _enabledSources = ordered);
  }

  Future<void> _setNoticeFilter(NoticeFilterState next) async {
    final NoticeFilterState safeNext = next.copyWith(
      sources: next.sources.isEmpty ? kNoticeFilterSourceOptions : next.sources,
      types: next.types.isEmpty ? kNoticeFilterTypeOptions : next.types,
    );
    await safeNext.save();
    if (!mounted) return;
    setState(() => _noticeFilter = safeNext);
  }

  Future<void> _toggleNoticeFilterSource(String source, bool selected) async {
    final Set<String> next = Set<String>.from(_noticeFilter.sources);
    selected ? next.add(source) : next.remove(source);
    await _setNoticeFilter(_noticeFilter.copyWith(sources: next.toList()));
  }

  Future<void> _toggleNoticeFilterType(String type, bool selected) async {
    final Set<String> next = Set<String>.from(_noticeFilter.types);
    selected ? next.add(type) : next.remove(type);
    await _setNoticeFilter(_noticeFilter.copyWith(types: next.toList()));
  }

  void _showExcludeKeywordDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("제외 키워드 관리"),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "제외 키워드가 제목이나 설명에 포함된 공지는 앱 목록에서 숨겨집니다.",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          hintText: "예: 폐강, 취소",
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () async {
                              final String text = controller.text.trim();
                              if (text.isEmpty ||
                                  _noticeFilter.excludes.contains(text)) {
                                return;
                              }
                              final List<String> next = [
                                ..._noticeFilter.excludes,
                                text,
                              ];
                              await _setNoticeFilter(
                                _noticeFilter.copyWith(excludes: next),
                              );
                              if (!mounted) return;
                              controller.clear();
                              setDialogState(() {});
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _noticeFilter.excludes.map((kw) {
                            return Chip(
                              label: Text(kw),
                              onDeleted: () async {
                                final List<String> next = _noticeFilter.excludes
                                    .where((item) => item != kw)
                                    .toList();
                                await _setNoticeFilter(
                                  _noticeFilter.copyWith(excludes: next),
                                );
                                if (!mounted) return;
                                setDialogState(() {});
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
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
    ).whenComplete(controller.dispose);
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
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.6,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "등록한 키워드가 포함된 공지만 알림이 옵니다.",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: controller,
                          decoration: InputDecoration(
                            hintText: "예: 장학, 기숙사, 성적",
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: () async {
                                final text = controller.text.trim();
                                if (text.isEmpty || _keywords.contains(text))
                                  return;

                                // #region agent log
                                debugSessionNdjson(
                                  hypothesisId: "H1",
                                  location:
                                      "settings_screen.dart:_showKeywordDialog:add:onPressed:start",
                                  message: "Keyword add pressed",
                                  data: <String, dynamic>{
                                    "mounted": mounted,
                                    "textLen": text.length,
                                    "keywordsCountBefore": _keywords.length,
                                  },
                                );
                                // #endregion

                                try {
                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  // #region agent log
                                  debugSessionNdjson(
                                    hypothesisId: "H2",
                                    location:
                                        "settings_screen.dart:_showKeywordDialog:add:onPressed:afterPrefs",
                                    message: "SharedPreferences obtained",
                                    data: <String, dynamic>{
                                      "mounted": mounted,
                                    },
                                  );
                                  // #endregion

                                  _keywords = [..._keywords, text];
                                  await prefs.setStringList(
                                      "keywords", _keywords);
                                  // #region agent log
                                  debugSessionNdjson(
                                    hypothesisId: "H2",
                                    location:
                                        "settings_screen.dart:_showKeywordDialog:add:onPressed:afterSetStringList",
                                    message: "keywords saved",
                                    data: <String, dynamic>{
                                      "mounted": mounted,
                                      "keywordsCountAfter": _keywords.length,
                                    },
                                  );
                                  // #endregion

                                  if (!mounted) {
                                    // #region agent log
                                    debugSessionNdjson(
                                      hypothesisId: "H1",
                                      location:
                                          "settings_screen.dart:_showKeywordDialog:add:onPressed:unmountedEarlyReturn",
                                      message:
                                          "State unmounted after await; return before setState",
                                      data: <String, dynamic>{
                                        "keywordsCount": _keywords.length,
                                      },
                                    );
                                    // #endregion
                                    return;
                                  }

                                  controller.clear();
                                  setDialogState(() {}); // 다이얼로그 UI 갱신
                                  setState(() {}); // 배경 설정창 UI 갱신
                                } catch (e) {
                                  // #region agent log
                                  debugSessionNdjson(
                                    hypothesisId: "HERR",
                                    location:
                                        "settings_screen.dart:_showKeywordDialog:add:onPressed:catch",
                                    message: "Exception during keyword add",
                                    data: <String, dynamic>{
                                      "error": e.toString(),
                                      "mounted": mounted,
                                    },
                                  );
                                  // #endregion
                                  rethrow;
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _keywords.map((kw) {
                              return Chip(
                                label: Text(kw),
                                onDeleted: () async {
                                  // #region agent log
                                  debugSessionNdjson(
                                    hypothesisId: "H1",
                                    location:
                                        "settings_screen.dart:_showKeywordDialog:delete:onDeleted:start",
                                    message: "Keyword delete pressed",
                                    data: <String, dynamic>{
                                      "mounted": mounted,
                                      "kwLen": kw.length,
                                      "keywordsCountBefore": _keywords.length,
                                    },
                                  );
                                  // #endregion

                                  try {
                                    final prefs =
                                        await SharedPreferences.getInstance();
                                    _keywords = _keywords
                                        .where((k) => k != kw)
                                        .toList();
                                    await prefs.setStringList(
                                        "keywords", _keywords);
                                    // #region agent log
                                    debugSessionNdjson(
                                      hypothesisId: "H2",
                                      location:
                                          "settings_screen.dart:_showKeywordDialog:delete:onDeleted:afterSetStringList",
                                      message: "keywords saved after delete",
                                      data: <String, dynamic>{
                                        "mounted": mounted,
                                        "keywordsCountAfter": _keywords.length,
                                      },
                                    );
                                    // #endregion

                                    if (!mounted) {
                                      // #region agent log
                                      debugSessionNdjson(
                                        hypothesisId: "H1",
                                        location:
                                            "settings_screen.dart:_showKeywordDialog:delete:onDeleted:unmountedEarlyReturn",
                                        message:
                                            "State unmounted after await; return before setState",
                                        data: <String, dynamic>{
                                          "keywordsCount": _keywords.length,
                                        },
                                      );
                                      // #endregion
                                      return;
                                    }

                                    setDialogState(() {});
                                    setState(() {});
                                  } catch (e) {
                                    // #region agent log
                                    debugSessionNdjson(
                                      hypothesisId: "HERR",
                                      location:
                                          "settings_screen.dart:_showKeywordDialog:delete:onDeleted:catch",
                                      message:
                                          "Exception during keyword delete",
                                      data: <String, dynamic>{
                                        "error": e.toString(),
                                        "mounted": mounted,
                                      },
                                    );
                                    // #endregion
                                    rethrow;
                                  }
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
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
    ).whenComplete(controller.dispose);
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
            content: RichText(
                text:
                    TextSpan(style: TextStyle(color: Colors.white), children: [
              TextSpan(
                  text: "메일 앱을 열 수 없어요. ",
                  style: TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(
                  text: "메일 앱 설치/계정 설정 후 다시 시도해 주세요.",
                  style: TextStyle(fontWeight: FontWeight.w400)),
            ])),
          ),
        );
      }
    }
  }

  Widget _buildFilterChipGroup({
    required List<String> options,
    required List<String> selected,
    required ValueChanged<String> onEnabled,
    required ValueChanged<String> onDisabled,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((String value) {
        final bool isSelected = selected.contains(value);
        return FilterChip(
          label: Text(value),
          selected: isSelected,
          onSelected: (bool next) =>
              next ? onEnabled(value) : onDisabled(value),
        );
      }).toList(),
    );
  }

  Widget _buildNoticeScreenFilterCard() {
    final bool enabled = _noticeFilter.enabled;
    final bool requireKeyword = _noticeFilter.requireKeywordHit;
    final String excludeSummary = _noticeFilter.excludes.isEmpty
        ? "현재 등록된 제외 키워드 없음"
        : "${_noticeFilter.excludes.length}개 제외 키워드 사용 중";
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: "공지 화면 필터"),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                title: const Text("공지 화면 필터 사용"),
                subtitle: const Text("홈·공지·CTL·MPU 목록에 필터를 적용합니다."),
                value: enabled,
                onChanged: (bool value) =>
                    _setNoticeFilter(_noticeFilter.copyWith(enabled: value)),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text("키워드 알람과 동일한 키워드만 표시"),
                subtitle: Text(
                  _keywords.isEmpty
                      ? "키워드가 없으면 필터 사용 시 목록이 비어 보일 수 있습니다."
                      : "${_keywords.length}개 키워드를 화면 필터에도 사용",
                ),
                value: requireKeyword,
                onChanged: (bool value) => _setNoticeFilter(
                  _noticeFilter.copyWith(requireKeywordHit: value),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Text(
                  "출처",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _buildFilterChipGroup(
                  options: kNoticeFilterSourceOptions,
                  selected: _noticeFilter.sources,
                  onEnabled: (value) => _toggleNoticeFilterSource(value, true),
                  onDisabled: (value) =>
                      _toggleNoticeFilterSource(value, false),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Text(
                  "유형",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _buildFilterChipGroup(
                  options: kNoticeFilterTypeOptions,
                  selected: _noticeFilter.types,
                  onEnabled: (value) => _toggleNoticeFilterType(value, true),
                  onDisabled: (value) => _toggleNoticeFilterType(value, false),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text("제외 키워드 추가/삭제"),
                subtitle: Text(excludeSummary),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _showExcludeKeywordDialog,
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeModeController? themeController =
        ThemeModeScope.maybeOf(context);
    final ThemeMode themeMode = themeController?.value ?? ThemeMode.system;
    final bool allNotices = _allNoticesEnabled;
    final bool keywordNotices = _keywordNoticesEnabled;
    final bool notificationsAllOff = !allNotices && !keywordNotices;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("설정"),
            SizedBox(height: 2),
            Text(
              "MJC in one",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                height: 1.1,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        children: [
          _SectionHeader(title: "알림"),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text("전체 알람"),
                  subtitle: const Text("모든 공지사항 새글 알림 받기"),
                  value: allNotices,
                  onChanged: _toggleAllNotices,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text("키워드 알람"),
                  subtitle: const Text("등록한 키워드가 포함된 공지사항만"),
                  value: keywordNotices,
                  onChanged: _toggleKeywordNotices,
                ),
                if (notificationsAllOff) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    child: Row(
                      children: [
                        Icon(
                          Icons.notifications_off_outlined,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.72),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "알람이 꺼집니다.",
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.78),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: keywordNotices
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 6),
                      child: Text(
                        "키워드 관리",
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: Text(
                        "키워드가 없으면 알림이 오지 않습니다.",
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    ListTile(
                      title: const Text("키워드 추가/삭제"),
                      subtitle: Text(
                        _keywords.isEmpty
                            ? "현재 등록된 키워드 없음"
                            : "${_keywords.length}개 키워드 감시 중",
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: _showKeywordDialog,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _buildNoticeScreenFilterCard(),
          const SizedBox(height: 18),
          _SectionHeader(title: "테마"),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "앱 화면 테마 선택",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.light,
                        label: Text("라이트"),
                        icon: Icon(Icons.light_mode_outlined),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.dark,
                        label: Text("다크"),
                        icon: Icon(Icons.dark_mode_outlined),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.system,
                        label: Text("자동"),
                        icon: Icon(Icons.settings_suggest_outlined),
                      ),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (s) {
                      final ThemeMode next =
                          s.isEmpty ? ThemeMode.system : s.first;
                      if (themeController == null) return;
                      themeController.setAndPersist(next);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          _SectionHeader(title: "알림 받을 출처"),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text("메인 홈페이지 (mjc.ac.kr)"),
                  subtitle: const Text("공지·학사·장학 등 본교 게시판"),
                  value: _enabledSources.contains("mjc"),
                  onChanged: (v) => _setSourceEnabled("mjc", v),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text("CTL (ctl.mjc.ac.kr)"),
                  subtitle: const Text("CTL 프로그램·공지"),
                  value: _enabledSources.contains("ctl"),
                  onChanged: (v) => _setSourceEnabled("ctl", v),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text("MPU 핵심역량 (mpu.mjc.ac.kr)"),
                  subtitle: const Text("핵심역량 프로그램 안내"),
                  value: _enabledSources.contains("mpu"),
                  onChanged: (v) => _setSourceEnabled("mpu", v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SectionHeader(title: "앱 정보"),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                const ListTile(
                  title: Text("앱 버전"),
                  trailing: Text("1.0.0 (Build 1)"),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text("개발자에게 문의하기"),
                  subtitle: const Text("불편한 점이나 건의사항을 보내주세요."),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _contactDeveloper,
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text("오픈소스 라이선스"),
                  trailing: const Icon(Icons.chevron_right_rounded),
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
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}
