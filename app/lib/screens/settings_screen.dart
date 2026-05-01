import "package:flutter/material.dart";
import "package:mio_notice/notification_sources.dart";
import "package:mio_notice/screens/open_source_licenses_screen.dart";
import "package:mio_notice/services/notice_filter.dart";
import "package:mio_notice/services/user_data_repository.dart";
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
  /// 설정 화면 본문·카드 구분용 (참고 UI와 유사한 톤).
  static const Color _pageBackground = Color(0xFFF5F7F9);
  static const Color _cardBorder = Color(0xFFEDEDED);

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
        includes: prefs.getStringList(kNoticeFilterIncludesPrefKey) ?? const [],
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
    await UserDataRepository.instance.pushSnapshotToCloud();
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
    await UserDataRepository.instance.pushSnapshotToCloud();
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

  /// [kNoticeFilterSourceOptions] 라벨(MJC·CTL·MPU) ↔ FCM `source` id.
  String _notificationSourceIdForChip(String chipLabel) {
    switch (chipLabel) {
      case "MJC":
        return "mjc";
      case "CTL":
        return "ctl";
      case "MPU":
        return "mpu";
      default:
        return "";
    }
  }

  List<String> _selectedNotificationSourceChipLabels() {
    return kNoticeFilterSourceOptions
        .where(
          (String label) =>
              _enabledSources.contains(_notificationSourceIdForChip(label)),
        )
        .toList();
  }

  Future<void> _toggleNotificationSourceChip(
      String label, bool selected) async {
    final String id = _notificationSourceIdForChip(label);
    if (id.isEmpty) return;
    await _setSourceEnabled(id, selected);
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
    await UserDataRepository.instance.updateSources(ordered);
    if (!mounted) return;
    setState(() => _enabledSources = ordered);
  }

  /// 저장 전에 출처·유형이 비지 않게 보정합니다(깨진 저장값 복구). 칩은 `_toggleNoticeFilter*`에서 최소 1개를 유지합니다.
  Future<void> _setNoticeFilter(NoticeFilterState next) async {
    final NoticeFilterState safeNext = next.copyWith(
      sources: next.sources.isEmpty ? kNoticeFilterSourceOptions : next.sources,
      types: next.types.isEmpty ? kNoticeFilterTypeOptions : next.types,
    );
    await safeNext.save();
    await UserDataRepository.instance.updateNoticeFilter(safeNext);
    if (!mounted) return;
    setState(() => _noticeFilter = safeNext);
  }

  Future<void> _toggleNoticeFilterSource(String source, bool selected) async {
    final Set<String> next = Set<String>.from(_noticeFilter.sources);
    if (selected) {
      next.add(source);
    } else {
      next.remove(source);
      if (next.isEmpty) {
        if (mounted) {
          SnackBarUtils.showUnique(
            context,
            key: "settings_filter_sources_min_one",
            snackBar: SnackBar(
              behavior: SnackBarBehavior.floating,
              margin: _snackBarMargin(context),
              content: const Text("화면 필터 출처는 최소 하나 선택해야 해요."),
            ),
          );
        }
        return;
      }
    }
    await _setNoticeFilter(_noticeFilter.copyWith(sources: next.toList()));
  }

  Future<void> _toggleNoticeFilterType(String type, bool selected) async {
    final Set<String> next = Set<String>.from(_noticeFilter.types);
    if (selected) {
      next.add(type);
    } else {
      next.remove(type);
      if (next.isEmpty) {
        if (mounted) {
          SnackBarUtils.showUnique(
            context,
            key: "settings_filter_types_min_one",
            snackBar: SnackBar(
              behavior: SnackBarBehavior.floating,
              margin: _snackBarMargin(context),
              content: const Text("화면 필터 유형은 최소 하나 선택해야 해요."),
            ),
          );
        }
        return;
      }
    }
    await _setNoticeFilter(_noticeFilter.copyWith(types: next.toList()));
  }

  void _showIncludeKeywordDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("보고 싶은 키워드"),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "등록한 키워드 중 하나라도 제목·본문 등에 포함된 공지만 목록에 보입니다. 비워 두면 이 조건은 쓰지 않아요.",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          hintText: "예: 장학, 수강신청",
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () async {
                              final String text = controller.text.trim();
                              if (text.isEmpty ||
                                  _noticeFilter.includes.contains(text)) {
                                return;
                              }
                              final List<String> next = [
                                ..._noticeFilter.includes,
                                text,
                              ];
                              await _setNoticeFilter(
                                _noticeFilter.copyWith(includes: next),
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
                          children: _noticeFilter.includes.map((kw) {
                            return Chip(
                              label: Text(kw),
                              onDeleted: () async {
                                final List<String> next = _noticeFilter.includes
                                    .where((item) => item != kw)
                                    .toList();
                                await _setNoticeFilter(
                                  _noticeFilter.copyWith(includes: next),
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
                                  await UserDataRepository.instance
                                      .updateKeywords(_keywords);
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
                                    await UserDataRepository.instance
                                        .updateKeywords(_keywords);
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
    return Align(
      alignment: AlignmentDirectional.topStart,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.start,
        crossAxisAlignment: WrapCrossAlignment.start,
        children: options.map((String value) {
          final bool isSelected = selected.contains(value);
          return FilterChip(
            label: Text(value),
            selected: isSelected,
            onSelected: (bool next) =>
                next ? onEnabled(value) : onDisabled(value),
          );
        }).toList(),
      ),
    );
  }

  Widget _settingsCard({required Widget child}) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool light = Theme.of(context).brightness == Brightness.light;
    return Material(
      color: scheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: light ? _cardBorder : scheme.outline.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _hairlineDivider() {
    final bool light = Theme.of(context).brightness == Brightness.light;
    return Divider(
      height: 1,
      thickness: 1,
      color: light ? _cardBorder : Theme.of(context).colorScheme.outline.withValues(alpha: 0.35),
    );
  }

  Widget _buildNoticeScreenFilterCard() {
    final bool enabled = _noticeFilter.enabled;
    final bool requireKeyword = _noticeFilter.requireKeywordHit;
    final String includeSummary = _noticeFilter.includes.isEmpty
        ? "등록된 보기 키워드 없음(출처·유형만 적용)"
        : "${_noticeFilter.includes.length}개 키워드가 포함된 공지만 표시";
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: "공지 화면 필터",
          icon: Icons.tune_rounded,
        ),
        _settingsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                title: const Text("공지 화면 필터 사용"),
                subtitle: Text(
                  enabled
                      ? "홈·공지·CTL·MPU 목록에 필터를 적용 중입니다."
                      : "끄면 목록은 필터 없이 표시됩니다. 켜면 아래에서 세부 조건을 설정할 수 있어요.",
                ),
                value: enabled,
                onChanged: (bool value) =>
                    _setNoticeFilter(_noticeFilter.copyWith(enabled: value)),
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 220),
                crossFadeState: enabled
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _hairlineDivider(),
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
                    _hairlineDivider(),
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
                        onEnabled: (value) =>
                            _toggleNoticeFilterSource(value, true),
                        onDisabled: (value) =>
                            _toggleNoticeFilterSource(value, false),
                      ),
                    ),
                    _hairlineDivider(),
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
                        onEnabled: (value) =>
                            _toggleNoticeFilterType(value, true),
                        onDisabled: (value) =>
                            _toggleNoticeFilterType(value, false),
                      ),
                    ),
                    _hairlineDivider(),
                    ListTile(
                      title: const Text("보고 싶은 키워드 추가/삭제"),
                      subtitle: Text(includeSummary),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: _showIncludeKeywordDialog,
                    ),
                  ],
                ),
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

    final Color scaffoldBg = Theme.of(context).brightness == Brightness.light
        ? _pageBackground
        : Theme.of(context).colorScheme.surfaceContainerLow;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: const Text("설정"),
      ),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          const _SectionHeader(
            title: "알림",
            icon: Icons.notifications_outlined,
          ),
          _settingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  title: const Text("전체 알람"),
                  subtitle: allNotices
                      ? const Text("모든 공지사항 새글 알림 받기")
                      : const Text("꺼 두면 아래 알람·출처 설정이 접혀 있어요."),
                  value: allNotices,
                  onChanged: _toggleAllNotices,
                ),
                if (allNotices) ...[
                  _hairlineDivider(),
                  SwitchListTile(
                    title: const Text("키워드 알람"),
                    subtitle: const Text("등록한 키워드가 포함된 공지사항만"),
                    value: keywordNotices,
                    onChanged: _toggleKeywordNotices,
                  ),
                  _hairlineDivider(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                    child: Text(
                      "알림 받을 출처",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                    child: Text(
                      "푸시 알림을 받을 사이트를 고릅니다. 최소 한 곳은 선택해야 해요.",
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.65),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: _buildFilterChipGroup(
                      options: kNoticeFilterSourceOptions,
                      selected: _selectedNotificationSourceChipLabels(),
                      onEnabled: (value) =>
                          _toggleNotificationSourceChip(value, true),
                      onDisabled: (value) =>
                          _toggleNotificationSourceChip(value, false),
                    ),
                  ),
                  if (notificationsAllOff) ...[
                    _hairlineDivider(),
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
              ],
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: (allNotices && keywordNotices)
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _settingsCard(
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
          const SizedBox(height: 16),
          _buildNoticeScreenFilterCard(),
          const SizedBox(height: 16),
          const _SectionHeader(
            title: "화면",
            icon: Icons.palette_outlined,
          ),
          _settingsCard(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "앱 화면 테마",
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
          const SizedBox(height: 16),
          const _SectionHeader(
            title: "앱 정보",
            icon: Icons.info_outline_rounded,
          ),
          _settingsCard(
            child: Column(
              children: [
                const ListTile(
                  title: Text("앱 버전"),
                  trailing: Text("1.0.0 (Build 1)"),
                ),
                _hairlineDivider(),
                ListTile(
                  title: const Text("개발자에게 문의하기"),
                  subtitle: const Text("불편한 점이나 건의사항을 보내주세요."),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _contactDeveloper,
                ),
                _hairlineDivider(),
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
  const _SectionHeader({required this.title, this.icon});

  final String title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final Color accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 8),
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
