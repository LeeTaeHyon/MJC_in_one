import "package:flutter/gestures.dart";
import "package:flutter/material.dart";
import "package:url_launcher/url_launcher.dart";

/// 본문 속 URL을 탭 가능한 하이퍼링크로 표시하는 선택 가능 텍스트.
class LinkifiedSelectableText extends StatefulWidget {
  const LinkifiedSelectableText({
    super.key,
    required this.text,
    this.style,
    this.linkStyle,
  });

  final String text;
  final TextStyle? style;
  final TextStyle? linkStyle;

  static final RegExp _urlPattern = RegExp(
    r'(https?://\S+|www\.\S+)',
    caseSensitive: false,
  );

  static String launchableUrl(String raw) {
    String url = raw.trim();
    while (url.isNotEmpty && ",.;:!?)]}>".contains(url[url.length - 1])) {
      url = url.substring(0, url.length - 1);
    }
    if (url.startsWith("www.")) {
      return "https://$url";
    }
    return url;
  }

  @override
  State<LinkifiedSelectableText> createState() => _LinkifiedSelectableTextState();
}

class _LinkifiedSelectableTextState extends State<LinkifiedSelectableText> {
  final List<TapGestureRecognizer> _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    _clearRecognizers();
    super.dispose();
  }

  void _clearRecognizers() {
    for (final TapGestureRecognizer r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  Future<void> _openUrl(String raw) async {
    final String url = LinkifiedSelectableText.launchableUrl(raw);
    final Uri? uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("링크를 열 수 없습니다.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    _clearRecognizers();

    final TextStyle baseStyle =
        widget.style ?? DefaultTextStyle.of(context).style;
    final Color linkColor = widget.linkStyle?.color ??
        Theme.of(context).colorScheme.primary;
    final TextStyle linkStyle = (widget.linkStyle ?? baseStyle).copyWith(
      color: linkColor,
      decoration: TextDecoration.underline,
      decorationColor: linkColor,
    );

    final List<TextSpan> spans = <TextSpan>[];
    int cursor = 0;
    for (final RegExpMatch match
        in LinkifiedSelectableText._urlPattern.allMatches(widget.text)) {
      if (match.start > cursor) {
        spans.add(
          TextSpan(
            text: widget.text.substring(cursor, match.start),
            style: baseStyle,
          ),
        );
      }
      final String url = match.group(0)!;
      final TapGestureRecognizer recognizer = TapGestureRecognizer()
        ..onTap = () => _openUrl(url);
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(
          text: url,
          style: linkStyle,
          recognizer: recognizer,
        ),
      );
      cursor = match.end;
    }

    if (spans.isEmpty) {
      return SelectableText(widget.text, style: baseStyle);
    }

    if (cursor < widget.text.length) {
      spans.add(
        TextSpan(
          text: widget.text.substring(cursor),
          style: baseStyle,
        ),
      );
    }

    return SelectableText.rich(
      TextSpan(children: spans),
      style: baseStyle,
    );
  }
}
