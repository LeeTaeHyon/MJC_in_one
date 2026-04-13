import "dart:io";

void agentAppendNdjson(String line) {
  try {
    const String path =
        r"C:\Users\dlxog\Desktop\all\prjs\Mio\MJC_in_one\debug-62d9f7.log";
    File(path).writeAsStringSync("$line\n", mode: FileMode.append, flush: true);
  } catch (_) {}
}
