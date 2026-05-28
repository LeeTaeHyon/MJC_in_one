import "package:flutter/material.dart";

import "package:mjc_in_one/theme/app_theme.dart";

/// 접힌 공지 히어로 제목. 배너·단색 배경 모두에서 가독성을 위해 얇은 스트로크만 사용합니다.
class CollapsedHeroTitle extends StatelessWidget {
  const CollapsedHeroTitle({
    super.key,
    required this.text,
    required this.baseStyle,
    this.icon,
  });

  final String text;
  final TextStyle baseStyle;
  /// 하단 공지 서브 pill과 동일한 아이콘 ([NoticesSubTab.icon]).
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final TextStyle fill = MjcAppTypography.noticeHeroCollapsedTitleFill(baseStyle);
    final TextStyle stroke = fill.copyWith(
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = MjcAppTypography.noticeHeroCollapsedTitleStrokeWidth
        ..color = MjcAppTypography.noticeHeroCollapsedTitleStroke,
    );
    final Widget title = Stack(
      alignment: AlignmentDirectional.centerStart,
      children: <Widget>[
        Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: stroke,
        ),
        Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: fill,
        ),
      ],
    );

    if (icon == null) return title;

    final double iconSize = fill.fontSize ?? 20;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Icon(
          icon,
          size: iconSize,
          color: Colors.white,
          shadows: const <Shadow>[
            Shadow(
              color: MjcAppTypography.noticeHeroCollapsedTitleStroke,
              blurRadius: 4,
            ),
          ],
        ),
        const SizedBox(width: 8),
        Flexible(child: title),
      ],
    );
  }
}
