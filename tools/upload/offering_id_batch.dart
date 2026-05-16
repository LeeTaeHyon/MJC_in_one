import "dart:convert";
import "dart:io";

/// Matches [TimetableSlotParser.stableOfferingId] in the Flutter app.
///
/// stdin: one row per line, TAB-separated:
///   department, courseName, section, professor (trimmed strings)
/// stdout: one lowercase hex id per line ([Object.hash].toRadixString(16))
void main() async {
  await for (final String line
      in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
    final String t = line.trimRight();
    if (t.isEmpty) continue;
    // Dart's String.split drops trailing empty fields in some cases
    // (e.g. "a\tb\tc\t"). We also tolerate extra tabs by folding them into the
    // last field.
    final List<String> raw = t.split("\t");
    final List<String> parts = <String>[];
    if (raw.length >= 4) {
      parts.add(raw[0]);
      parts.add(raw[1]);
      parts.add(raw[2]);
      parts.add(raw.sublist(3).join("\t"));
    } else {
      parts.addAll(raw);
      while (parts.length < 4) {
        parts.add("");
      }
    }
    if (parts.length != 4) {
      stderr.writeln(
        "offering_id_batch: expected 4 tab-separated fields, got ${parts.length}",
      );
      exitCode = 2;
      return;
    }
    final String id =
        Object.hash(parts[0], parts[1], parts[2], parts[3]).toRadixString(16);
    stdout.writeln(id);
  }
}
