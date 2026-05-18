import "dart:async";

import "package:flutter/foundation.dart";

/// 홈 대시보드 등에서 «지금» 기준 문구(셔틀 N분 후, 강의 N분 남음)를 주기적으로 다시 그릴 때 씁니다.
final class LiveClock {
  LiveClock._();

  static final LiveClock instance = LiveClock._();

  final ValueNotifier<int> tick = ValueNotifier<int>(0);

  Timer? _timer;
  int _attachCount = 0;

  void attach() {
    _attachCount++;
    if (_attachCount == 1) {
      _timer = Timer.periodic(const Duration(seconds: 30), (_) {
        tick.value++;
      });
    }
  }

  void detach() {
    if (_attachCount <= 0) return;
    _attachCount--;
    if (_attachCount == 0) {
      _timer?.cancel();
      _timer = null;
    }
  }

  /// 앱 복귀·홈 탭 재진입 등 즉시 한 번 갱신할 때 호출합니다.
  void notifyNow() {
    tick.value++;
  }
}
