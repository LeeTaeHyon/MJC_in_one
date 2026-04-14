import "package:flutter/material.dart";

/// SnackBar 중복 표시를 막기 위한 유틸.
///
/// - 같은 [key]의 SnackBar가 이미 떠있으면 다시 띄우지 않습니다.
/// - 닫히면 내부 상태에서 자동으로 제거합니다.
class SnackBarUtils {
  SnackBarUtils._();

  static final Map<String, ScaffoldFeatureController<SnackBar, SnackBarClosedReason>>
      _inFlight = <String, ScaffoldFeatureController<SnackBar, SnackBarClosedReason>>{};

  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? showUnique(
    BuildContext context, {
    required String key,
    required SnackBar snackBar,
  }) {
    final existing = _inFlight[key];
    if (existing != null) return null;

    final messenger = ScaffoldMessenger.of(context);
    final controller = messenger.showSnackBar(snackBar);
    _inFlight[key] = controller;

    controller.closed.whenComplete(() {
      final current = _inFlight[key];
      if (identical(current, controller)) {
        _inFlight.remove(key);
      }
    });

    return controller;
  }
}

