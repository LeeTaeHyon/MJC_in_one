import "dart:convert";
import "dart:io";

import "package:flutter/foundation.dart";
import "package:flutter_test/flutter_test.dart";

String _normalizeParagraphText(String s) {
  return s.replaceAll(RegExp(r"\s+"), " ").trim();
}

String _bodyKey(LicenseEntry e) {
  return e.paragraphs
      .map((p) => "${p.indent}\u{001F}${_normalizeParagraphText(p.text)}")
      .join("\u{001E}");
}

void main() {
  test("generate assets/licenses/licenses.json", () async {
    final raw = await LicenseRegistry.licenses.toList();
    final byBody = <String, ({List<Map<String, dynamic>> paragraphs, Set<String> packages})>{};

    for (final e in raw) {
      final key = _bodyKey(e);
      final paragraphs = e.paragraphs
          .map((p) => <String, dynamic>{"indent": p.indent, "text": p.text})
          .toList(growable: false);
      final cur = byBody[key];
      if (cur == null) {
        byBody[key] = (paragraphs: paragraphs, packages: {...e.packages});
      } else {
        cur.packages.addAll(e.packages);
      }
    }

    final merged = byBody.values.map((v) {
      final pkgs = v.packages.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      return <String, dynamic>{
        "packages": pkgs,
        "paragraphs": v.paragraphs,
      };
    }).toList();

    merged.sort((a, b) {
      final ap = (a["packages"] as List).cast<String>();
      final bp = (b["packages"] as List).cast<String>();
      final an = ap.isEmpty ? "" : ap.first;
      final bn = bp.isEmpty ? "" : bp.first;
      return an.toLowerCase().compareTo(bn.toLowerCase());
    });

    final outFile = File("assets/licenses/licenses.json");
    await outFile.parent.create(recursive: true);
    await outFile.writeAsString(
      const JsonEncoder.withIndent("  ").convert(merged),
    );
  });
}

