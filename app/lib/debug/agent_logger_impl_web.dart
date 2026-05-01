// ignore_for_file: avoid_web_libraries_in_flutter

import "dart:convert";
import "dart:html" as html;

Future<void> agentLoggerSend({
  required String endpoint,
  required String sessionId,
  required Map<String, Object?> payload,
}) async {
  final String body = jsonEncode(payload);

  // Prefer sendBeacon to avoid CORS/preflight issues in Flutter Web.
  final bool ok = html.window.navigator.sendBeacon(
    endpoint,
    html.Blob(<Object>[body], "application/json"),
  );
  if (ok) return;

  // Fallback: plain POST without custom headers.
  await html.HttpRequest.request(
    endpoint,
    method: "POST",
    sendData: body,
    requestHeaders: <String, String>{
      "Content-Type": "application/json",
    },
  );
}

