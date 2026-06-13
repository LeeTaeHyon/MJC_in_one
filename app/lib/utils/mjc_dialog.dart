import "dart:async";
import "dart:math";

import "package:flutter/material.dart";
import "package:mjc_in_one/services/foodcourt_menu.dart";
import "package:mjc_in_one/theme/app_colors.dart";
import "package:mjc_in_one/theme/app_theme.dart";

/// MJC 앱 공통 다이얼로그 스타일.
///
/// 새 다이얼로그는 [showMjcAlertDialog], [showMjcConfirmDialog],
/// [showMjcLogoutDialog], [showMjcClearCacheDialog],
/// [showMjcFoodcourtRecommendDialog] 또는
/// [MjcDialogShell]을 사용합니다.
/// `AlertDialog(...)` 직접 생성은 피하세요.

const double kMjcDialogRadius = 20;
const double kMjcDialogPadding = 24;
const double kMjcDialogButtonHeight = 44;

const Color _kMjcDialogBackgroundDark = Color(0xFF24282E);
const Color _kMjcDialogTitleDark = Color(0xFFF5F5F5);
const Color _kMjcDialogBodyDark = Color(0xFFD4D4D4);
const Color _kMjcDialogTitleLight = Color(0xFF111827);
const Color _kMjcDialogBodyLight = Color(0xFF6B7280);
const Color _kMjcDialogInfoTint = Color(0xFFE3F2FD);
const Color _kMjcDialogWarningTint = Color(0xFFFFF3E0);

Color mjcDialogBackground(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? _kMjcDialogBackgroundDark
      : Colors.white;
}

Color mjcDialogTitleColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? _kMjcDialogTitleDark
      : _kMjcDialogTitleLight;
}

Color mjcDialogBodyColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? _kMjcDialogBodyDark
      : _kMjcDialogBodyLight;
}

Color mjcDialogDividerColor(BuildContext context) {
  final bool isDark = Theme.of(context).brightness == Brightness.dark;
  return isDark
      ? Colors.white.withValues(alpha: 0.08)
      : Colors.black.withValues(alpha: 0.08);
}

TextStyle mjcDialogTitleStyle(BuildContext context) {
  return TextStyle(
    fontFamily: kPretendardFontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w800,
    height: 1.3,
    color: mjcDialogTitleColor(context),
  );
}

TextStyle mjcDialogBodyStyle(BuildContext context) {
  return TextStyle(
    fontFamily: kPretendardFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.45,
    color: mjcDialogBodyColor(context),
  );
}

/// 공통 다이얼로그 셸 (radius 20, padding 24).
class MjcDialogShell extends StatelessWidget {
  const MjcDialogShell({
    super.key,
    required this.body,
    this.actions,
    this.centerIcon,
    this.header,
  });

  final Widget body;
  final Widget? actions;
  final Widget? centerIcon;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: mjcDialogBackground(context),
      elevation: isDark ? 0 : 1,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kMjcDialogRadius),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              kMjcDialogPadding,
              kMjcDialogPadding,
              kMjcDialogPadding,
              actions == null ? kMjcDialogPadding : 0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (header != null) ...[
                  header!,
                  const SizedBox(height: 16),
                ],
                if (centerIcon != null) ...[
                  centerIcon!,
                  const SizedBox(height: 16),
                ],
                body,
                if (actions != null) const SizedBox(height: 20),
              ],
            ),
          ),
          if (actions != null) actions!,
        ],
      ),
    );
  }
}

/// 알림 / 안내 (단일 확인).
Future<void> showMjcAlertDialog(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = "확인",
  VoidCallback? onConfirm,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      return MjcDialogShell(
        centerIcon: const _MjcDialogInfoIcon(),
        body: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: mjcDialogTitleStyle(ctx),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: mjcDialogBodyStyle(ctx),
              ),
            ],
          ],
        ),
        actions: _MjcDialogSingleAction(
          label: confirmLabel,
          color: AppColors.primary,
          onPressed: () {
            Navigator.of(ctx).pop();
            onConfirm?.call();
          },
        ),
      );
    },
  );
}

/// 확인 / 취소.
Future<bool?> showMjcConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  String cancelLabel = "취소",
  String confirmLabel = "확인",
  bool destructive = false,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) {
      return MjcDialogShell(
        centerIcon: const _MjcDialogWarningIcon(),
        body: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: mjcDialogTitleStyle(ctx),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: mjcDialogBodyStyle(ctx),
              ),
            ],
          ],
        ),
        actions: _MjcDialogSplitActions(
          cancelLabel: cancelLabel,
          confirmLabel: confirmLabel,
          confirmDestructive: destructive,
          onCancel: () => Navigator.of(ctx).pop(false),
          onConfirm: () => Navigator.of(ctx).pop(true),
        ),
      );
    },
  );
}

/// 로그아웃 확인.
Future<bool?> showMjcLogoutDialog(BuildContext context) {
  return showMjcConfirmDialog(
    context,
    title: "로그아웃 하시겠어요?",
    message: "로그아웃 시 현재 계정에서 로그아웃됩니다.",
    confirmLabel: "로그아웃",
    destructive: true,
  );
}

/// 캐시 데이터 삭제 확인.
Future<bool?> showMjcClearCacheDialog(BuildContext context) {
  return showMjcConfirmDialog(
    context,
    title: "캐시 데이터를 지우시겠어요?",
    message:
        "식단·셔틀·캠퍼스맵·공지 목록 등 임시 데이터를 삭제합니다.\n\n"
        "다음 사용 시 서버에서 다시 받아옵니다. 알림 설정, 북마크, 시간표, 프로필은 유지됩니다.",
    confirmLabel: "지우기",
    destructive: true,
  );
}

/// 랜덤 학식 메뉴 추천.
Future<void> showMjcFoodcourtRecommendDialog(
  BuildContext context, {
  required List<FoodcourtMenuItem> items,
  required Random random,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      return _MjcFoodcourtRecommendDialog(
        items: items,
        random: random,
      );
    },
  );
}

class _MjcDialogInfoIcon extends StatelessWidget {
  const _MjcDialogInfoIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        color: _kMjcDialogInfoTint,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.info_outline_rounded,
        color: AppColors.primary,
        size: 24,
      ),
    );
  }
}

class _MjcDialogWarningIcon extends StatelessWidget {
  const _MjcDialogWarningIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        color: _kMjcDialogWarningTint,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.error_outline_rounded,
        color: Color(0xFFE65100),
        size: 24,
      ),
    );
  }
}

class _MjcDialogSingleAction extends StatelessWidget {
  const _MjcDialogSingleAction({
    required this.label,
    required this.onPressed,
    required this.color,
  });

  final String label;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(height: 1, color: mjcDialogDividerColor(context)),
        SizedBox(
          height: kMjcDialogButtonHeight,
          width: double.infinity,
          child: TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(
              foregroundColor: color,
              minimumSize: const Size(double.infinity, kMjcDialogButtonHeight),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: EdgeInsets.zero,
              shape: const RoundedRectangleBorder(),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: kPretendardFontFamily,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MjcDialogSplitActions extends StatelessWidget {
  const _MjcDialogSplitActions({
    required this.cancelLabel,
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
    this.confirmDestructive = false,
  });

  final String cancelLabel;
  final String confirmLabel;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final bool confirmDestructive;

  @override
  Widget build(BuildContext context) {
    final Color confirmColor = confirmDestructive
        ? const Color(0xFFE65100)
        : AppColors.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(height: 1, color: mjcDialogDividerColor(context)),
        SizedBox(
          height: kMjcDialogButtonHeight,
          child: Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: onCancel,
                  style: TextButton.styleFrom(
                    foregroundColor: mjcDialogBodyColor(context),
                    minimumSize:
                        const Size(double.infinity, kMjcDialogButtonHeight),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                    shape: const RoundedRectangleBorder(),
                  ),
                  child: Text(
                    cancelLabel,
                    style: const TextStyle(
                      fontFamily: kPretendardFontFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Container(
                width: 1,
                height: kMjcDialogButtonHeight,
                color: mjcDialogDividerColor(context),
              ),
              Expanded(
                child: TextButton(
                  onPressed: onConfirm,
                  style: TextButton.styleFrom(
                    foregroundColor: confirmColor,
                    minimumSize:
                        const Size(double.infinity, kMjcDialogButtonHeight),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                    shape: const RoundedRectangleBorder(),
                  ),
                  child: Text(
                    confirmLabel,
                    style: const TextStyle(
                      fontFamily: kPretendardFontFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
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

class _MjcFoodcourtRecommendDialog extends StatefulWidget {
  const _MjcFoodcourtRecommendDialog({
    required this.items,
    required this.random,
  });

  final List<FoodcourtMenuItem> items;
  final Random random;

  @override
  State<_MjcFoodcourtRecommendDialog> createState() =>
      _MjcFoodcourtRecommendDialogState();
}

class _MjcFoodcourtRecommendDialogState
    extends State<_MjcFoodcourtRecommendDialog> {
  Timer? _timer;
  late FoodcourtMenuItem _currentItem;
  bool _spinning = false;
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    _currentItem = _pickRandom();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startSpin();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  FoodcourtMenuItem _pickRandom() {
    return widget.items[widget.random.nextInt(widget.items.length)];
  }

  void _startSpin() {
    if (_spinning) return;
    _timer?.cancel();
    setState(() {
      _spinning = true;
      _tick = 0;
    });

    _timer = Timer.periodic(const Duration(milliseconds: 55), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final int nextTick = _tick + 1;
      final bool done = nextTick >= 12;
      setState(() {
        _tick = nextTick;
        _currentItem = _pickRandom();
        _spinning = !done;
      });

      if (done) timer.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final MjcSurfaceTokens tokens =
        Theme.of(context).extension<MjcSurfaceTokens>()!;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color foodAccent = tokens.foodAccent;
    final Color foodTint = foodAccent.withValues(alpha: isDark ? 0.22 : 0.12);
    final Color resultBackground = isDark
        ? const Color(0xFF3A322E)
        : const Color(0xFFFFF8F3);

    return MjcDialogShell(
      header: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: foodTint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.ramen_dining_rounded,
              color: foodAccent,
              size: 20,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(
              Icons.close_rounded,
              color: mjcDialogBodyColor(context),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("오늘 뭐 먹지?", style: mjcDialogTitleStyle(context)),
          const SizedBox(height: 6),
          Text(
            _spinning ? "두구두구..." : "오늘은 이거 어때요?",
            style: mjcDialogBodyStyle(context),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              color: resultBackground,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 90),
                  transitionBuilder: (child, animation) {
                    final Animation<Offset> offset = Tween<Offset>(
                      begin: const Offset(0, 0.35),
                      end: Offset.zero,
                    ).animate(animation);
                    return ClipRect(
                      child: SlideTransition(
                        position: offset,
                        child: FadeTransition(opacity: animation, child: child),
                      ),
                    );
                  },
                  child: Text(
                    _currentItem.menu,
                    key: ValueKey("${_currentItem.shop}-${_currentItem.menu}"),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: kPretendardFontFamily,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                      color: mjcDialogTitleColor(context),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                AnimatedOpacity(
                  opacity: _spinning ? 0.35 : 1,
                  duration: const Duration(milliseconds: 180),
                  child: Text(
                    "${_currentItem.shop} • ${_currentItem.formattedPrice}",
                    textAlign: TextAlign.center,
                    style: mjcDialogBodyStyle(context).copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: mjcDialogBodyColor(context),
                      minimumSize: const Size(0, kMjcDialogButtonHeight),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Text(
                      "닫기",
                      style: TextStyle(
                        fontFamily: kPretendardFontFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: FilledButton.icon(
                    onPressed: _spinning ? null : _startSpin,
                    style: FilledButton.styleFrom(
                      backgroundColor: foodAccent,
                      foregroundColor: isDark ? const Color(0xFF3E2723) : Colors.white,
                      disabledBackgroundColor:
                          foodAccent.withValues(alpha: 0.45),
                      disabledForegroundColor: isDark
                          ? const Color(0xFF3E2723).withValues(alpha: 0.6)
                          : Colors.white.withValues(alpha: 0.8),
                      minimumSize: const Size(0, kMjcDialogButtonHeight),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.casino_rounded, size: 18),
                    label: Text(
                      _spinning ? "고르는 중" : "다시 추천받기",
                      style: const TextStyle(
                        fontFamily: kPretendardFontFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
