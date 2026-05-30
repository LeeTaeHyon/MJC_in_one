import "package:flutter/material.dart";
import "package:mjc_in_one/theme/app_colors.dart";

/// 로그인 등에서 필수 약관·개인정보(국외 이전 포함) 동의 체크박스.
class LegalConsentRow extends StatelessWidget {
  const LegalConsentRow({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onOpenTerms,
    required this.onOpenPrivacy,
  });

  final bool value;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onOpenTerms;
  final VoidCallback onOpenPrivacy;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color linkColor =
        isDark ? AppColors.switchActiveDark : cs.primary;
    final TextStyle bodyStyle = TextStyle(
      fontSize: 13,
      height: 1.45,
      fontWeight: FontWeight.w600,
      color: cs.onSurface.withValues(alpha: 0.78),
    );
    final ButtonStyle linkStyle = TextButton.styleFrom(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      foregroundColor: linkColor,
      textStyle: bodyStyle.copyWith(
        decoration: TextDecoration.underline,
        decorationColor: linkColor.withValues(alpha: 0.55),
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text("[필수] ", style: bodyStyle),
                TextButton(
                  style: linkStyle,
                  onPressed: onOpenTerms,
                  child: const Text("서비스 이용약관"),
                ),
                Text(" 및 ", style: bodyStyle),
                TextButton(
                  style: linkStyle,
                  onPressed: onOpenPrivacy,
                  child: const Text("개인정보처리방침"),
                ),
                Text("(국외 이전 포함)에 동의합니다.", style: bodyStyle),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
