import "dart:convert";
import "dart:io";

Future<void> agentLoggerSend({
  required String endpoint,
  required String sessionId,
  required Map<String, Object?> payload,
}) async {
  // Non-web: append a single NDJSON line to the session log file.
  final File f = File("debug-300508.log");
  await f.writeAsString("${jsonEncode(payload)}\n", mode: FileMode.append);
}

