import "package:flutter/material.dart";
import "package:mjc_in_one/services/app_permission_checker.dart";
import "package:mjc_in_one/theme/app_colors.dart";

const Color _pageBackground = Color(0xFFF5F7F9);
const Color _cardBorder = Color(0xFFEDEDED);
const Color _titleColor = Color(0xFF374151);
const Color _titleColorDark = Color(0xFFD1D5DB);
const Color _subtitleColor = Color(0xFF6B7280);
const Color _subtitleColorDark = Color(0xFF9CA3AF);

TextStyle _itemTitleStyle(BuildContext context) {
  final bool dark = Theme.of(context).brightness == Brightness.dark;
  return (Theme.of(context).listTileTheme.titleTextStyle ??
          Theme.of(context).textTheme.titleMedium!)
      .copyWith(color: dark ? _titleColorDark : _titleColor);
}

TextStyle _itemSubtitleStyle(BuildContext context) {
  final bool dark = Theme.of(context).brightness == Brightness.dark;
  return (Theme.of(context).listTileTheme.subtitleTextStyle ??
          Theme.of(context).textTheme.bodyMedium!)
      .copyWith(color: dark ? _subtitleColorDark : _subtitleColor);
}

/// 설정 > 휴대폰 권한 — 알림·위치 등 권한 상태 확인·요청.
class PhonePermissionsScreen extends StatefulWidget {
  const PhonePermissionsScreen({super.key});

  @override
  State<PhonePermissionsScreen> createState() => _PhonePermissionsScreenState();
}

class _PhonePermissionsScreenState extends State<PhonePermissionsScreen>
    with WidgetsBindingObserver {
  List<MjcPermissionInfo> _permissions = const <MjcPermissionInfo>[];
  bool _loading = true;
  String? _requestingId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh(showLoading: false);
    }
  }

  Future<void> _refresh({bool showLoading = true}) async {
    if (showLoading) {
      setState(() => _loading = true);
    }
    final List<MjcPermissionInfo> next = await AppPermissionChecker.loadAll();
    if (!mounted) return;
    setState(() {
      _permissions = next;
      _loading = false;
    });
  }

  int get _grantedCount =>
      _permissions.where((MjcPermissionInfo p) => p.isGranted).length;

  Future<void> _onRequest(MjcPermissionInfo item) async {
    if (_requestingId != null) return;
    setState(() => _requestingId = item.id);
    try {
      if (item.isGranted || item.shouldOpenSettings) {
        await AppPermissionChecker.openSystemSettings(item.id);
      } else if (item.canRequest) {
        final bool granted = await AppPermissionChecker.request(item.id);
        // 정확한 알람: request()가 이미 전용 설정 화면을 연다. 실패 시 앱 설정만.
        if (!granted && item.id != "exact_alarm") {
          await AppPermissionChecker.openSystemSettings(item.id);
        }
      } else {
        await AppPermissionChecker.openSystemSettings(item.id);
      }
    } finally {
      if (mounted) {
        setState(() => _requestingId = null);
        await _refresh(showLoading: false);
      }
    }
  }

  String _actionLabel(MjcPermissionInfo item) {
    if (item.isGranted) return "설정 열기";
    if (item.shouldOpenSettings) return "기기 설정";
    return "허용 요청";
  }

  Color _statusColor(BuildContext context, MjcPermissionInfo item) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryColor = isDark ? AppColors.switchActiveDark : scheme.primary;
    if (item.isGranted) return primaryColor;
    if (item.state == MjcPermissionState.notSupported) {
      return scheme.onSurfaceVariant;
    }
    return scheme.error;
  }

  Widget _permissionCard(MjcPermissionInfo item) {
    final bool busy = _requestingId == item.id;
    final Color statusColor = _statusColor(context, item);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryColor = isDark
        ? AppColors.switchActiveDark
        : Theme.of(context).colorScheme.primary;

    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).brightness == Brightness.light
              ? _cardBorder
              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(item.icon, size: 22, color: statusColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(item.title, style: _itemTitleStyle(context)),
                      const SizedBox(height: 4),
                      Text(
                        item.description,
                        style: _itemSubtitleStyle(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    item.stateLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
                const Spacer(),
                if (item.state != MjcPermissionState.notSupported)
                  TextButton(
                    onPressed: busy ? null : () => _onRequest(item),
                    style: TextButton.styleFrom(
                      foregroundColor: primaryColor,
                    ),
                    child: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_actionLabel(item)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color scaffoldBg = Theme.of(context).brightness == Brightness.light
        ? _pageBackground
        : Theme.of(context).colorScheme.surfaceContainerLow;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: const Text("휴대폰 권한"),
        actions: <Widget>[
          IconButton(
            tooltip: "새로고침",
            onPressed: _loading ? null : () => _refresh(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                children: <Widget>[
                  Material(
                    color: Theme.of(context).colorScheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: Theme.of(context).brightness == Brightness.light
                            ? _cardBorder
                            : Theme.of(context)
                                .colorScheme
                                .outline
                                .withValues(alpha: 0.35),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.verified_user_outlined,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? AppColors.switchActiveDark
                                : Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _permissions.any(
                                (MjcPermissionInfo p) =>
                                    p.id != "web" &&
                                    p.state != MjcPermissionState.notSupported,
                              )
                                  ? "${_permissions.where((MjcPermissionInfo p) => p.state != MjcPermissionState.notSupported).length}개 중 $_grantedCount개 허용"
                                  : "권한 상태를 확인할 수 없습니다.",
                              style: _itemTitleStyle(context).copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._permissions.map(
                    (MjcPermissionInfo item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _permissionCard(item),
                    ),
                  ),
                  Text(
                    "권한을 변경한 뒤에는 이 화면으로 돌아오면 상태가 자동으로 갱신됩니다.",
                    style: _itemSubtitleStyle(context).copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
    );
  }
}
