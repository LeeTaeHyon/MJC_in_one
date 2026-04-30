import "dart:convert";

import "package:flutter/foundation.dart";

import "_debug_session_log_http.dart"
    if (dart.library.html) "_debug_session_log_http_web.dart" as http;

/// Debug-mode NDJSON logger for session 7886c5.
///
/// Sends one JSON payload per line to the local ingest endpoint.
void debugSessionNdjson({
  String runId = "pre-fix",
  required String hypothesisId,
  required String location,
  required String message,
  Map<String, dynamic>? data,
}) {
  if (!kDebugMode) return;
  final payload = <String, Object?>{
    "sessionId": "7886c5",
    "runId": runId,
    "hypothesisId": hypothesisId,
    "location": location,
    "message": message,
    "timestamp": DateTime.now().millisecondsSinceEpoch,
    "data": data ?? <String, dynamic>{},
  };
  final line = jsonEncode(payload);
  http.postNdjson(line);
}
