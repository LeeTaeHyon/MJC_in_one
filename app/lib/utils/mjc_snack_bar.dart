import "package:flutter/material.dart";
import "package:mjc_in_one/theme/app_theme.dart";
import "package:mjc_in_one/utils/snack_bar_utils.dart";
import "package:mjc_in_one/widgets/main_navigation_scope.dart";

/// MJC 앱 공통 SnackBar 스타일.
///
/// 새 SnackBar는 [showMjcSnackBar] 또는 [showUniqueMjcSnackBar]만 사용합니다.
/// `SnackBar(...)` 직접 생성은 피하세요.
/// 다크 모드 스낵바 배경.
const Color kMjcSnackBarBackgroundDark = Color(0xFF424242);

/// 라이트 모드 — [kMjcSnackBarBackgroundDark]보다 조금 더 어둡게.
const Color kMjcSnackBarBackgroundLight = Color(0xFF363636);

const Color kMjcSnackBarAction = Color(0xFF5EB3FF);

Color mjcSnackBarBackground(BuildContext context) {
  final bool isDark = Theme.of(context).brightness == Brightness.dark;
  return isDark ? kMjcSnackBarBackgroundDark : kMjcSnackBarBackgroundLight;
}

TextStyle mjcSnackBarTextStyle({
  required Color color,
  FontWeight fontWeight = FontWeight.w400,
}) =>
    TextStyle(
      fontFamily: kPretendardFontFamily,
      color: color,
      fontSize: 14,
      fontWeight: fontWeight,
      height: 1.2,
    );

Widget mjcSnackBarContent({
  required String message,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  return Row(
    children: <Widget>[
      Expanded(
        child: Text(
          message,
          style: mjcSnackBarTextStyle(color: Colors.white),
        ),
      ),
      if (actionLabel != null && onAction != null) ...<Widget>[
        const SizedBox(width: 12),
        GestureDetector(
          onTap: onAction,
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                actionLabel,
                style: mjcSnackBarTextStyle(
                  color: kMjcSnackBarAction,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: kMjcSnackBarAction,
                size: 20,
              ),
            ],
          ),
        ),
      ],
    ],
  );
}

SnackBar buildMjcSnackBar(
  BuildContext context, {
  required String message,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(milliseconds: 1500),
  EdgeInsetsGeometry? margin,
}) {
  final VoidCallback? wrappedOnAction = onAction == null
      ? null
      : () {
          ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
          onAction();
        };
  return SnackBar(
    duration: duration,
    persist: false,
    behavior: SnackBarBehavior.floating,
    backgroundColor: mjcSnackBarBackground(context),
    elevation: 0,
    margin: margin ?? MainNavLayout.snackBarMargin(context),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    content: mjcSnackBarContent(
      message: message,
      actionLabel: actionLabel,
      onAction: wrappedOnAction,
    ),
  );
}

/// MJC 공통 floating 스낵바(고정·즐겨찾기·시간표 등).
void showMjcSnackBar(
  BuildContext context, {
  required String message,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(milliseconds: 1500),
  EdgeInsetsGeometry? margin,
  VoidCallback? onShown,
  VoidCallback? onClosed,
}) {
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  onShown?.call();
  messenger.hideCurrentSnackBar();
  final ScaffoldFeatureController<SnackBar, SnackBarClosedReason> controller =
      messenger.showSnackBar(
    buildMjcSnackBar(
      context,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
      margin: margin,
    ),
  );
  controller.closed.then((_) => onClosed?.call());
}

/// [SnackBarUtils.showUnique] + MJC 스낵바 스타일(설정 알림 토글 등).
ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? showUniqueMjcSnackBar(
  BuildContext context, {
  required String key,
  required String message,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(milliseconds: 1500),
  EdgeInsetsGeometry? margin,
}) {
  return SnackBarUtils.showUnique(
    context,
    key: key,
    snackBar: buildMjcSnackBar(
      context,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
      margin: margin,
    ),
  );
}
