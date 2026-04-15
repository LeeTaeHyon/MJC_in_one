import "dart:convert";

import "package:flutter/foundation.dart";
import "package:flutter/scheduler.dart";

import "_agent_log_io.dart" if (dart.library.html) "_agent_log_stub.dart"
    as agent_io;
import "_agent_log_http.dart"
    if (dart.library.html) "_agent_log_http_web.dart"
    as agent_http;

/// 개발 중 에이전트 디버그 로그(NDJSON)를 파일로 남길지 여부.
///
/// - 스크롤/애니메이션 같은 고빈도 경로에서 호출될 수 있어, 기본값은 꺼둡니다.
/// - 디바이스 성능/IO에 직접 영향을 주므로, 필요할 때만 true로 켜세요.
const bool kEnableAgentDebugLog = bool.fromEnvironment(
  "MJC_ENABLE_AGENT_DEBUG_LOG",
  defaultValue: true,
);

// 로그 오버헤드로 jank가 악화되는 걸 막기 위해, 기본적으로 저빈도 신호만 남깁니다.
// 필요하면 dart-define으로 확장하세요.
const String kAgentEnabledHypotheses = String.fromEnvironment(
  "MJC_AGENT_LOG_HYPOTHESES",
  defaultValue: "H0S,H5,H6,H7A,H7B",
);

void agentDebugNdjson({
  String runId = "pre-fix",
  required String hypothesisId,
  required String location,
  required String message,
  Map<String, dynamic>? data,
}) {
  if (!kDebugMode || !kEnableAgentDebugLog) return;
  if (kAgentEnabledHypotheses.isNotEmpty &&
      !kAgentEnabledHypotheses.split(",").contains(hypothesisId)) {
    return;
  }
  final Map<String, Object?> payload = <String, Object?>{
    "sessionId": "e0832f",
    "runId": runId,
    "hypothesisId": hypothesisId,
    "location": location,
    "message": message,
    "timestamp": DateTime.now().millisecondsSinceEpoch,
    "data": <String, dynamic>{
      ...?data,
      "schedulerPhase": SchedulerBinding.instance.schedulerPhase.name,
    },
  };
  final String line = jsonEncode(payload);
  if (kIsWeb) {
    debugPrint("NDJSON_AGENT|$line");
  }
  // #region agent log
  // 로컬 디버그 서버로 전송.
  // - 데스크톱: 127.0.0.1
  // - 안드로이드 에뮬레이터: 10.0.2.2
  // - 웹: 127.0.0.1 (같은 머신에서 실행 중인 서버로 전송)
  // 실패해도 앱 동작에 영향 없도록 무조건 삼킵니다.
  agent_http.agentPostNdjson(line);
  // #endregion
  if (!kIsWeb) {
    agent_io.agentAppendNdjson(line);
  }
}
