import "package:flutter/material.dart";
import "package:mjc_in_one/utils/mjc_snack_bar.dart";
import "package:mjc_in_one/widgets/main_navigation_scope.dart";

/// Pull-to-refresh 연타로 Firestore read가 쏟아지는 것을 막는 화면별 쿨다운.
class NoticeListRefreshGuard {
  NoticeListRefreshGuard._();

  static const Duration cooldown = Duration(minutes: 5);

  static final Map<String, DateTime> _lastRefreshAt = <String, DateTime>{};

  /// [scopeKey]별 쿨다운을 검사합니다. true면 `forceRefresh: true`를 허용합니다.
  static bool allowForceRefresh(String scopeKey) {
    final DateTime now = DateTime.now();
    final DateTime? last = _lastRefreshAt[scopeKey];
    if (last != null && now.difference(last) < cooldown) {
      return false;
    }
    _lastRefreshAt[scopeKey] = now;
    return true;
  }

  static void showThrottledMessage(
    BuildContext context, {
    required String key,
  }) {
    if (!context.mounted) return;
    showUniqueMjcSnackBar(
      context,
      key: key,
      message:
          "방금 새로고침했어요. ${cooldown.inMinutes}분 후에 다시 시도해 주세요.",
      margin: MainNavLayout.snackBarMargin(context),
    );
  }
}
