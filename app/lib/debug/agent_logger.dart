import "package:flutter/foundation.dart";

import "agent_logger_impl.dart";

/// Small debug logger for this session (works on mobile + web).
///
/// Writes NDJSON-like payloads to a local file on IO platforms, and sends HTTP
/// POST requests to the local ingest server on web.
class AgentLogger {
  static const String _sessionId = "300508";
  static const String _endpoint =
      "http://127.0.0.1:7711/ingest/29d80b18-384f-47b8-bfd6-4a209adf91a1";

  static Future<void> log({
    required String hypothesisId,
    required String location,
    required String message,
    Map<String, Object?>? data,
    String runId = "pre-fix",
  }) async {
    // Avoid spamming logs in release builds.
    if (kReleaseMode) return;
    final payload = <String, Object?>{
      "sessionId": _sessionId,
      "runId": runId,
      "hypothesisId": hypothesisId,
      "location": location,
      "message": message,
      "data": data ?? const <String, Object?>{},
      "timestamp": DateTime.now().millisecondsSinceEpoch,
    };
    try {
      await agentLoggerSend(
        endpoint: _endpoint,
        sessionId: _sessionId,
        payload: payload,
      );
    } catch (_) {
      // Intentionally swallow to keep UI stable.
    }
  }
}

