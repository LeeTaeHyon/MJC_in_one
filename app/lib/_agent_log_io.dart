import "dart:io";

void agentAppendNdjson(String line) {
  try {
    const String path =
        r"C:\Users\dlxog\Desktop\all\prjs\Mio\MJC_in_one\debug-e0832f.log";
    // 고빈도 경로에서 호출될 수 있어 동기 flush는 지양합니다.
    // 디버그 로그는 유실돼도 괜찮으므로 비동기로 남깁니다.
    // ignore: discarded_futures
    File(path).writeAsString("$line\n", mode: FileMode.append, flush: false);
  } catch (_) {}
}
