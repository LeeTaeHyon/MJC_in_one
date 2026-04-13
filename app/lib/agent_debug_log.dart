import "dart:convert";

import "package:flutter/foundation.dart";
import "package:flutter/scheduler.dart";

import "_agent_log_io.dart" if (dart.library.html) "_agent_log_stub.dart"
    as agent_io;

void agentDebugNdjson({
  required String hypothesisId,
  required String location,
  required String message,
  Map<String, dynamic>? data,
}) {
  final Map<String, Object?> payload = <String, Object?>{
    "sessionId": "62d9f7",
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
    return;
  }
  agent_io.agentAppendNdjson(line);
}
