import "package:flutter/material.dart";
import "package:flutter/foundation.dart" show kIsWeb;
import "package:mjc_in_one/notification_history_prefs.dart";
import "package:mjc_in_one/notification_sources.dart";
import "package:mjc_in_one/screens/common_webview_screen.dart";
import "package:mjc_in_one/screens/settings_screen.dart";
import "package:mjc_in_one/theme/app_colors.dart";
import "package:mjc_in_one/widgets/scroll_to_top_scope.dart";
import "package:url_launcher/url_launcher.dart";

/// 푸시 알람 수신 내역을 모아보는 화면입니다.
class NotificationHistoryScreen extends StatefulWidget {
  const NotificationHistoryScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<NotificationHistoryScreen> createState() =>
      _NotificationHistoryScreenState();
}

class _NotificationHistoryScreenState extends State<NotificationHistoryScreen> {
  static const List<String> _categoryLabels = <String>[
    "전체",
    "본교 공지",
    "교수학습",
    "핵심역량관리",
  ];
  static const List<String> _categorySourceIds = <String>["mjc", "ctl", "mpu"];

  List<Map<String, dynamic>> _history = <Map<String, dynamic>>[];
  Set<String> _readKeys = <String>{};
  bool _isLoading = true;
  /// 0: 전체, 1…3: mjc / ctl / mpu
  int _categoryIndex = 0;
  bool _editMode = false;

  final ScrollController _scrollController = ScrollController();
  ScrollToTopCoordinator? _scrollRouteCoordinator;
  bool _registeredScrollRoute = false;
  bool _registeredMainTab = false;

  List<Map<String, dynamic>> get _visibleHistory {
    if (_categoryIndex == 0) {
      return List<Map<String, dynamic>>.from(_history);
    }
    final String sid = _categorySourceIds[_categoryIndex - 1];
    return _history
        .where((Map<String, dynamic> e) =>
            resolveNotificationSource(_fcmPayloadForSourceLookup(e)) == sid)
        .toList();
  }

  String _extractNotificationOpenUrl(Map<String, dynamic> item) {
    final dynamic dataAny = item["data"];
    if (dataAny is Map) {
      final dynamic urlAny = dataAny["url"] ?? dataAny["link"];
      if (urlAny != null) {
        final String url = urlAny.toString().trim();
        if (url.isNotEmpty) return url;
      }
    }
    final dynamic direct = item["url"] ?? item["link"];
    if (direct != null) {
      final String url = direct.toString().trim();
      if (url.isNotEmpty) return url;
    }
    return "";
  }

  String? _thumbnailUrl(Map<String, dynamic> item) {
    final dynamic dataAny = item["data"];
    if (dataAny is Map) {
      final Map<String, dynamic> data = Map<String, dynamic>.from(dataAny);
      for (final String k in <String>[
        "image",
        "imageUrl",
        "thumbnail",
        "thumb",
        "img",
        "picture",
      ]) {
        final String? v = data[k]?.toString().trim();
        if (v != null &&
            v.isNotEmpty &&
            (v.startsWith("http://") ||
                v.startsWith("https://") ||
                v.startsWith("//"))) {
          return v.startsWith("//") ? "https:$v" : v;
        }
      }
    }
    final String url = _extractNotificationOpenUrl(item);
    if (_looksLikeImageUrl(url)) return url;
    return null;
  }

  bool _looksLikeImageUrl(String url) {
    if (url.isEmpty) return false;
    final String u = url.toLowerCase();
    return u.endsWith(".png") ||
        u.endsWith(".jpg") ||
        u.endsWith(".jpeg") ||
        u.endsWith(".webp") ||
        u.endsWith(".gif");
  }

  Map<String, dynamic> _fcmPayloadForSourceLookup(Map<String, dynamic> item) {
    final dynamic raw = item["data"];
    final Map<String, dynamic> fromData =
        raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final String itemTitle = (item["title"] ?? "").toString().trim();
    if (itemTitle.isNotEmpty) {
      final String dataTitle = (fromData["title"] ?? "").toString().trim();
      if (dataTitle.isEmpty) fromData["title"] = itemTitle;
    }
    return fromData;
  }

  Color _unreadRowTint(BuildContext context) {
    final Brightness b = Theme.of(context).brightness;
    if (b == Brightness.dark) {
      return Theme.of(context).colorScheme.primary.withValues(alpha: 0.14);
    }
    return AppColors.chipBackground;
  }

  Future<void> _openNoticeFromHistoryItem(Map<String, dynamic> item) async {
    String openUrl = _extractNotificationOpenUrl(item);
    final String resolvedSource =
        resolveNotificationSource(_fcmPayloadForSourceLookup(item));
    if (resolvedSource == "mpu") {
      openUrl = kMpuPortalWebUrl;
    }
    if (openUrl.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("이 알림에는 이동할 공지 링크가 없습니다.")),
      );
      return;
    }

    await markNotificationHistoryItemRead(item);
    final String key = notificationHistoryItemKey(item);
    if (!mounted) return;
    setState(() {
      if (key.isNotEmpty) _readKeys.add(key);
    });

    final String title = resolvedSource == "mpu"
        ? "핵심역량 관리 (MPU)"
        : (item["title"] ?? "공지사항").toString();

    if (kIsWeb) {
      await launchUrl(Uri.parse(openUrl), webOnlyWindowName: "_blank");
      return;
    }
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => CommonWebViewScreen(url: openUrl, title: title),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onHistoryScroll);
    _loadHistory();
  }

  void _onHistoryScroll() {
    if (!mounted) return;
    final double viewportHeight =
        ScrollFabMetrics.viewportHeightInScrollListener(_scrollController);
    if (widget.embedded) {
      _scrollRouteCoordinator?.reportMainTabScroll(
        MainNavTabIndex.alerts,
        _scrollController.offset,
        viewportHeight,
      );
    } else {
      _scrollRouteCoordinator?.reportRouteScroll(
        _scrollController.offset,
        viewportHeight,
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_registeredScrollRoute || _registeredMainTab) return;
    final ScrollToTopCoordinator? c = ScrollToTopScope.maybeOf(context);
    if (c != null) {
      _scrollRouteCoordinator = c;
      if (widget.embedded) {
        c.registerMainTab(
          MainNavTabIndex.alerts,
          _scrollContentToTop,
          owner: this,
        );
        _registeredMainTab = true;
      } else {
        c.pushRouteHandler(_scrollContentToTop);
        _registeredScrollRoute = true;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        final double viewportHeight =
            ScrollFabMetrics.viewportHeightForThreshold(
                _scrollController, context);
        if (widget.embedded) {
          c.reportMainTabScroll(
            MainNavTabIndex.alerts,
            _scrollController.offset,
            viewportHeight,
          );
        } else {
          c.reportRouteScroll(_scrollController.offset, viewportHeight);
        }
      });
    }
  }

  void _scrollContentToTop() {
    if (!_scrollController.hasClients) return;
    for (final ScrollPosition position in _scrollController.positions) {
      position.animateTo(
        0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onHistoryScroll);
    if (_registeredScrollRoute) {
      _scrollRouteCoordinator?.popRouteHandler();
    }
    if (_registeredMainTab) {
      _scrollRouteCoordinator?.unregisterMainTab(
        MainNavTabIndex.alerts,
        owner: this,
      );
    }
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final List<Map<String, dynamic>> list =
        await loadNotificationHistoryNewestFirst();
    final Set<String> keys = await loadNotificationReadKeys();
    if (!mounted) return;
    setState(() {
      _history = list;
      _readKeys = keys;
      _isLoading = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final double viewportHeight = ScrollFabMetrics.viewportHeightForThreshold(
          _scrollController, context);
      if (widget.embedded) {
        _scrollRouteCoordinator?.reportMainTabScroll(
          MainNavTabIndex.alerts,
          _scrollController.offset,
          viewportHeight,
        );
      } else {
        _scrollRouteCoordinator?.reportRouteScroll(
          _scrollController.offset,
          viewportHeight,
        );
      }
    });
  }

  Future<void> _clearHistory() async {
    await clearNotificationHistory();
    if (!mounted) return;
    setState(() {
      _history = <Map<String, dynamic>>[];
      _readKeys = <String>{};
      _editMode = false;
    });
  }

  int _newestFirstIndexInFullHistory(Map<String, dynamic> item) {
    final String key = notificationHistoryItemKey(item);
    for (int i = 0; i < _history.length; i++) {
      if (notificationHistoryItemKey(_history[i]) == key) return i;
    }
    return -1;
  }

  Future<void> _removeOneForItem(Map<String, dynamic> item) async {
    final int idx = _newestFirstIndexInFullHistory(item);
    if (idx < 0) return;
    await removeNotificationHistoryAtNewestFirstIndex(idx);
    if (!mounted) return;
    await _loadHistory();
  }

  Future<void> _confirmDeleteAll() async {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text("알림 전체 삭제"),
        content: const Text("저장된 알림 내역을 모두 지울까요?"),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("취소"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text("삭제", style: TextStyle(color: scheme.error)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) await _clearHistory();
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const SettingsScreen(),
      ),
    );
  }

  /// 편집 모드에서 분류 칩 자리에 표시 (높이·여백을 칩 줄과 맞춤).
  Widget _buildEditModeDeleteBar(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    const double chipBarVerticalPadding = 4;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: chipBarVerticalPadding),
      child: SizedBox(
        height: 44,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _confirmDeleteAll,
              child: Text(
                "전체 삭제",
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: scheme.error,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChips(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    const double chipBarVerticalPadding = 4;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: chipBarVerticalPadding),
      child: SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: _categoryLabels.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (BuildContext context, int i) {
            final bool selected = _categoryIndex == i;
            return ChoiceChip(
              label: Text(_categoryLabels[i]),
              selected: selected,
              showCheckmark: false,
              onSelected: (bool v) {
                if (!v) return;
                setState(() => _categoryIndex = i);
              },
              selectedColor: scheme.onSurface,
              backgroundColor: scheme.surface,
              checkmarkColor: scheme.surface,
              labelStyle: TextStyle(
                color: selected ? scheme.surface : scheme.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              side: BorderSide(
                color: scheme.outline.withValues(alpha: selected ? 0.0 : 0.35),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
            );
          },
        ),
      ),
    );
  }

  Widget _fallbackThumb(String sourceId, double size) {
    final IconData icon;
    final Color accent;
    if (sourceId == "ctl") {
      icon = Icons.school_outlined;
      accent = AppColors.teaching;
    } else if (sourceId == "mpu") {
      icon = Icons.psychology_outlined;
      accent = AppColors.competency;
    } else {
      icon = Icons.account_balance_outlined;
      accent = AppColors.primary;
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.iconBackdrop(accent),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: accent, size: 26),
    );
  }

  Widget _buildThumb(Map<String, dynamic> item, String sourceId) {
    const double size = 56;
    final String? url = _thumbnailUrl(item);
    if (url != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder:
              (_, Object __, StackTrace? ___) => _fallbackThumb(sourceId, size),
        ),
      );
    }
    return _fallbackThumb(sourceId, size);
  }

  Widget _buildNotificationTile({
    required Map<String, dynamic> item,
    required String sourceId,
    required ColorScheme scheme,
  }) {
    final String key = notificationHistoryItemKey(item);
    final bool read = key.isEmpty ? true : _readKeys.contains(key);
    final String title = (item["title"] ?? "새로운 알림").toString();
    final String? body = item["body"]?.toString();
    final String time = (item["received_at"] ?? "").toString();

    return Material(
      color: read ? scheme.surface : _unreadRowTint(context),
      child: InkWell(
        onTap: _editMode ? null : () => _openNoticeFromHistoryItem(item),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _buildThumb(item, sourceId),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        height: 1.25,
                      ),
                    ),
                    if (body != null && body.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.35,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              if (_editMode)
                IconButton(
                  icon: Icon(Icons.close_rounded, color: scheme.error),
                  tooltip: "이 알림 삭제",
                  onPressed: () => _removeOneForItem(item),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color appBarIconColor =
        Theme.of(context).appBarTheme.foregroundColor ?? scheme.onPrimary;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        title: const Text("알림"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            width: double.infinity,
            color: scheme.outline.withValues(alpha: 0.32),
          ),
        ),
        actions: <Widget>[
          if (_editMode)
            TextButton(
              onPressed: () => setState(() => _editMode = false),
              child: Text(
                "취소",
                style: TextStyle(
                  color: appBarIconColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: appBarIconColor),
              tooltip: "삭제",
              onPressed: _history.isEmpty
                  ? null
                  : () => setState(() => _editMode = true),
            ),
          IconButton(
            icon: Icon(Icons.settings_outlined, color: appBarIconColor),
            tooltip: "설정",
            onPressed: _openSettings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (_editMode)
                  _buildEditModeDeleteBar(context)
                else
                  _buildCategoryChips(context),
                Expanded(
                  child: _history.isEmpty
                      ? _buildEmptyState(allCategories: true)
                      : _visibleHistory.isEmpty
                          ? _buildEmptyState(allCategories: false)
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.only(bottom: 12),
                              itemCount: _visibleHistory.length,
                              itemBuilder: (BuildContext context, int index) {
                                final Map<String, dynamic> item =
                                    _visibleHistory[index];
                                final String sid =
                                    resolveNotificationSource(
                                        _fcmPayloadForSourceLookup(item));
                                return _buildNotificationTile(
                                  item: item,
                                  sourceId: sid,
                                  scheme: scheme,
                                );
                              },
                            ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState({required bool allCategories}) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            Icons.notifications_none_rounded,
            size: 64,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.45),
          ),
          const SizedBox(height: 16),
          Text(
            allCategories
                ? "수신된 알림이 없습니다."
                : "이 카테고리 알림이 없습니다.",
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
