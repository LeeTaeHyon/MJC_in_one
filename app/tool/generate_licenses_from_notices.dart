import "dart:convert";
import "dart:io";

String _normalizeBody(String s) => s.replaceAll(RegExp(r"\s+"), " ").trim();

void main(List<String> args) {
  final noticesPath = args.isNotEmpty ? args.first : "build/web/assets/NOTICES";
  final outPath =
      args.length >= 2 ? args[1] : "assets/licenses/licenses.json";

  final noticesFile = File(noticesPath);
  if (!noticesFile.existsSync()) {
    stderr.writeln("NOTICES not found: $noticesPath");
    stderr.writeln(
      "Tip: run `flutter build web --release` first (or pass a NOTICES path).",
    );
    exitCode = 2;
    return;
  }

  final s = noticesFile.readAsStringSync();
  final separator = "\n--------------------------------------------------------------------------------\n";
  final chunks = s.split(separator);

  final merged = <String, ({Set<String> packages, String body})>{};

  for (final chunkRaw in chunks) {
    final chunk = chunkRaw.trim();
    if (chunk.isEmpty) continue;

    final lines = chunk.split("\n");
    final blankIdx = lines.indexWhere((l) => l.trim().isEmpty);
    if (blankIdx <= 0) continue;

    final packages = lines
        .take(blankIdx)
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toSet();
    final body = lines.skip(blankIdx + 1).join("\n").trimRight();
    if (packages.isEmpty || body.trim().isEmpty) continue;

    final key = _normalizeBody(body);
    final cur = merged[key];
    if (cur == null) {
      merged[key] = (packages: packages, body: body);
    } else {
      cur.packages.addAll(packages);
    }
  }

  final out = merged.values.map((v) {
    final pkgs = v.packages.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return <String, dynamic>{
      "packages": pkgs,
      "paragraphs": [
        {"indent": 0, "text": v.body},
      ],
    };
  }).toList();

  out.sort((a, b) {
    final ap = (a["packages"] as List).cast<String>();
    final bp = (b["packages"] as List).cast<String>();
    final an = ap.isEmpty ? "" : ap.first;
    final bn = bp.isEmpty ? "" : bp.first;
    return an.toLowerCase().compareTo(bn.toLowerCase());
  });

  final outFile = File(outPath);
  outFile.parent.createSync(recursive: true);
  outFile.writeAsStringSync(const JsonEncoder.withIndent("  ").convert(out));

  stdout.writeln("Wrote ${out.length} merged licenses to $outPath");
}

