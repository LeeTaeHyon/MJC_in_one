import "dart:convert";
import "dart:html" as html;

void postNdjson(String line) {
  try {
    const String url =
        "http://127.0.0.1:7711/ingest/29d80b18-384f-47b8-bfd6-4a209adf91a1";
    final html.HttpRequest req = html.HttpRequest();
    req.open("POST", url, async: true);
    req.setRequestHeader("Content-Type", "application/json");
    req.setRequestHeader("X-Debug-Session-Id", "7886c5");
    req.send(utf8.encode(line));
  } catch (_) {}
}
