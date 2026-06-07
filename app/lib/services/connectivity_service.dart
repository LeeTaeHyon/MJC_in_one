import "dart:async";

import "package:connectivity_plus/connectivity_plus.dart";
import "package:flutter/foundation.dart";

/// 인터넷 연결 여부를 감시하는 싱글톤 서비스.
///
/// [isOnline]으로 현재 상태를, [onlineStream]으로 변경 이벤트를 구독한다.
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final _connectivity = Connectivity();
  final ValueNotifier<bool> isOnlineNotifier = ValueNotifier<bool>(true);

  StreamSubscription<List<ConnectivityResult>>? _sub;

  bool get isOnline => isOnlineNotifier.value;

  /// [MainNavigationScreen] 진입 시 한 번 호출. 이후 자동 갱신된다.
  Future<void> start() async {
    // 최초 상태 확인
    final initial = await _connectivity.checkConnectivity();
    isOnlineNotifier.value = _resultsAreOnline(initial);

    // 이후 변경 감시
    _sub ??= _connectivity.onConnectivityChanged.listen((results) {
      isOnlineNotifier.value = _resultsAreOnline(results);
    });
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }

  static bool _resultsAreOnline(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
  }
}
