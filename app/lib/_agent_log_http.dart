import "dart:convert";
import "dart:io";

void agentPostNdjson(String line) {
  try {
    const String endpointPath = "/ingest/29d80b18-384f-47b8-bfd6-4a209adf91a1";
    const int port = 7711;
    const Map<String, String> headers = <String, String>{
      "Content-Type": "application/json",
      "X-Debug-Session-Id": "e0832f",
    };

    // 데스크톱/웹서버 로컬과 안드로이드 에뮬레이터 호스트 모두 시도.
    final List<String> hosts = <String>["127.0.0.1", "10.0.2.2"];
    for (final host in hosts) {
      // ignore: discarded_futures
      _postOnce(host, port, endpointPath, headers, line);
    }
  } catch (_) {}
}

Future<void> _postOnce(
  String host,
  int port,
  String endpointPath,
  Map<String, String> headers,
  String body,
) async {
  try {
    final HttpClient client = HttpClient();
    try {
      final Uri uri = Uri(scheme: "http", host: host, port: port, path: endpointPath);
      final HttpClientRequest req = await client.postUrl(uri);
      headers.forEach(req.headers.set);
      req.add(utf8.encode(body));
      final HttpClientResponse res = await req.close();
      // consume stream
      // ignore: unused_local_variable
      final String _ = await res.transform(utf8.decoder).join();
    } finally {
      client.close(force: true);
    }
  } catch (_) {}
}

