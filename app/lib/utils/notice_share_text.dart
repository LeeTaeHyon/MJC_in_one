/// 공지 상세 화면에서 [Share] 로 보낼 텍스트를 만듭니다.
String buildNoticeShareText({
  required String title,
  required String date,
  required String category,
  required String url,
  required String summary,
  required String body,
  required String bodyHtml,
  String boardId = "",
}) {
  final String trimmedTitle = title.trim().isEmpty ? "공지사항" : title.trim();
  final String trimmedUrl = url.trim();

  if (trimmedUrl.isNotEmpty) {
    return "$trimmedTitle\n$trimmedUrl";
  }

  final StringBuffer buffer = StringBuffer(trimmedTitle);

  final List<String> meta = <String>[
    if (category.trim().isNotEmpty) category.trim(),
    if (date.trim().isNotEmpty) date.trim(),
  ];
  if (meta.isNotEmpty) {
    buffer.writeln();
    buffer.writeln(meta.join(" · "));
  }

  final String content = _shareBodyText(
    summary: summary,
    body: body,
    bodyHtml: bodyHtml,
  );
  if (content.isNotEmpty) {
    buffer.writeln();
    buffer.writeln(content);
  }

  buffer.writeln();
  buffer.write("— MJC ONE");
  return buffer.toString().trim();
}

String _shareBodyText({
  required String summary,
  required String body,
  required String bodyHtml,
}) {
  for (final String candidate in <String>[summary, body, bodyHtml]) {
    final String text = _plainTextFromNoticeField(candidate);
    if (text.isNotEmpty) return _truncateShareText(text);
  }
  return "";
}

String _plainTextFromNoticeField(String raw) {
  final String trimmed = raw.trim();
  if (trimmed.isEmpty) return "";
  if (trimmed.contains("<") && trimmed.contains(">")) {
    return _stripHtml(trimmed);
  }
  return trimmed;
}

String _stripHtml(String html) {
  String text = html
      .replaceAll(RegExp(r"<br\s*/?>", caseSensitive: false), "\n")
      .replaceAll(RegExp(r"</p>", caseSensitive: false), "\n")
      .replaceAll(RegExp(r"</div>", caseSensitive: false), "\n")
      .replaceAll(RegExp(r"</li>", caseSensitive: false), "\n")
      .replaceAll(RegExp(r"<[^>]+>"), "")
      .replaceAll("&nbsp;", " ")
      .replaceAll("&amp;", "&")
      .replaceAll("&lt;", "<")
      .replaceAll("&gt;", ">")
      .replaceAll("&quot;", "\"")
      .replaceAll("&#39;", "'");

  text = text.replaceAll(RegExp(r"[ \t]+\n"), "\n");
  text = text.replaceAll(RegExp(r"\n{3,}"), "\n\n");
  return text.trim();
}

String _truncateShareText(String text, {int maxChars = 1800}) {
  if (text.length <= maxChars) return text;
  return "${text.substring(0, maxChars).trim()}…";
}
