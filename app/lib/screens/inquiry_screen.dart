import "dart:io" show Platform;

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:mjc_in_one/debug/app_debug_flags.dart";
import "package:mjc_in_one/screens/login_screen.dart";
import "package:mjc_in_one/services/auth_service.dart";
import "package:mjc_in_one/services/developer_support_service.dart";
import "package:mjc_in_one/utils/mjc_snack_bar.dart";
import "package:mjc_in_one/widgets/main_navigation_scope.dart";
import "package:mjc_in_one/widgets/mjc_floating_pill_cta.dart";
import "package:shared_preferences/shared_preferences.dart";

/// 사용자가 개발자에게 보내는 문의 유형.
enum InquiryType {
  bug("bug", "버그 신고"),
  suggestion("suggestion", "기능 제안"),
  general("general", "일반 문의"),
  other("other", "기타");

  final String value;
  final String label;
  const InquiryType(this.value, this.label);

  IconData get icon => switch (this) {
        InquiryType.bug => Icons.bug_report_outlined,
        InquiryType.suggestion => Icons.lightbulb_outline_rounded,
        InquiryType.general => Icons.chat_bubble_outline_rounded,
        InquiryType.other => Icons.more_horiz_rounded,
      };
}

const String _kInquiryCooldownKey = "developer_inquiry_last_at";
const Duration _kInquiryCooldown = Duration(seconds: 60);

/// 개발자에게 문의 보내기 화면. 결과는 Firestore `developer_inquiries` 컬렉션에 저장됩니다.
///
/// 기존 mailto 흐름을 대체합니다.
class InquiryScreen extends StatefulWidget {
  const InquiryScreen({super.key});

  @override
  State<InquiryScreen> createState() => _InquiryScreenState();
}

class _InquiryScreenState extends State<InquiryScreen> {
  final DeveloperSupportService _support = DeveloperSupportService();
  final TextEditingController _messageCtrl = TextEditingController();
  final TextEditingController _contactCtrl = TextEditingController();
  final FocusNode _messageFocus = FocusNode();
  InquiryType _type = InquiryType.general;
  bool _submitting = false;
  bool _showAllLogs = false;

  void _showLoginRequiredSnackBar() {
    showUniqueMjcSnackBar(
      context,
      key: "inquiry_login_required",
      message: "문의하려면 로그인해 주세요.",
      actionLabel: "로그인",
      onAction: () {
        Navigator.push<void>(
          context,
          MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        );
      },
      margin: MainNavLayout.snackBarMargin(context),
    );
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _contactCtrl.dispose();
    _messageFocus.dispose();
    super.dispose();
  }

  String _platformLabel() {
    if (kIsWeb) return "web";
    try {
      return Platform.operatingSystem;
    } catch (_) {
      return "unknown";
    }
  }

  Future<bool> _checkCooldown() async {
    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt(_kInquiryCooldownKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsedMs = now - lastMs;
    if (elapsedMs < _kInquiryCooldown.inMilliseconds) {
      final remain =
          (_kInquiryCooldown.inMilliseconds - elapsedMs) ~/ 1000 + 1;
      if (mounted) {
        showUniqueMjcSnackBar(
          context,
          key: "inquiry_cooldown",
          message: "문의는 잠시 후 다시 보낼 수 있습니다. ($remain초)",
        );
      }
      return false;
    }
    return true;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (AuthService.instance.currentUser == null) {
      _showLoginRequiredSnackBar();
      return;
    }
    final String msg = _messageCtrl.text.trim();
    if (msg.length < 5) {
      showUniqueMjcSnackBar(
        context,
        key: "inquiry_too_short",
        message: "문의 내용을 5자 이상 입력해 주세요.",
      );
      return;
    }
    if (!await _checkCooldown()) return;

    setState(() => _submitting = true);
    try {
      await _support.submitInquiry(
        type: _type.value,
        typeLabel: _type.label,
        message: msg,
        contact: _contactCtrl.text.trim(),
        platform: _platformLabel(),
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _kInquiryCooldownKey,
        DateTime.now().millisecondsSinceEpoch,
      );

      if (!mounted) return;
      showUniqueMjcSnackBar(
        context,
        key: "inquiry_submitted",
        message: "문의가 접수되었습니다. 빠르게 확인하겠습니다.",
      );
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint("inquiry submit error: $e");
      if (!mounted) return;
      setState(() => _submitting = false);
      showUniqueMjcSnackBar(
        context,
        key: "inquiry_failed",
        message: "문의를 보내지 못했습니다. 잠시 후 다시 시도해 주세요.",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "개발자에게 문의",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: scheme.outline.withValues(alpha: 0.4),
            height: 1.0,
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MjcFloatingCtaLayout.scrollBottomPadding(
                context,
                buttonHeight: MjcFloatingCtaLayout.compactHeight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (AppDevFeatures.inquiryDevLogSection) ...[
                  _buildDevLogSection(context),
                  const SizedBox(height: 16),
                ],
                _buildInquiryGuideCard(theme, scheme),
                const SizedBox(height: 16),
                _buildFormCard(theme, scheme),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: MjcFloatingCtaLayout.positionedBottom(context),
            child: Center(
              child: MjcFloatingPillCta(
                variant: MjcFloatingPillCtaVariant.primaryCompact,
                label: _submitting ? "보내는 중" : "문의 보내기",
                icon: Icons.send_rounded,
                onTap: _submit,
                enabled: !_submitting,
                loading: _submitting,
              ),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _surfaceCardDecoration(
    ColorScheme scheme, {
    required bool isDark,
  }) {
    return BoxDecoration(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.05),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(
    ThemeData theme,
    ColorScheme scheme, {
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: scheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          title,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration(
    ColorScheme scheme, {
    required String hintText,
  }) {
    final OutlineInputBorder border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    );
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: border,
      enabledBorder: border,
      focusedBorder: border,
    );
  }

  Widget _buildFormCard(ThemeData theme, ColorScheme scheme) {
    final bool isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _surfaceCardDecoration(scheme, isDark: isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            theme,
            scheme,
            icon: Icons.category_outlined,
            title: "문의 종류",
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<InquiryType>(
                value: _type,
                isExpanded: true,
                icon: Icon(
                  Icons.expand_more_rounded,
                  color: scheme.onSurfaceVariant,
                ),
                borderRadius: BorderRadius.circular(12),
                items: InquiryType.values
                    .map(
                      (type) => DropdownMenuItem<InquiryType>(
                        value: type,
                        child: Row(
                          children: [
                            Icon(type.icon, size: 18),
                            const SizedBox(width: 8),
                            Text(type.label),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                selectedItemBuilder: (context) => InquiryType.values
                    .map(
                      (type) => Align(
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            Icon(
                              type.icon,
                              size: 18,
                              color: scheme.onSurface,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              type.label,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (InquiryType? value) {
                  if (value == null) return;
                  setState(() => _type = value);
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionTitle(
            theme,
            scheme,
            icon: Icons.edit_outlined,
            title: "문의 내용",
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _messageCtrl,
            focusNode: _messageFocus,
            minLines: 5,
            maxLines: 12,
            maxLength: 1000,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            decoration: _fieldDecoration(
              scheme,
              hintText:
                  "발생한 상황, 화면, 기대했던 동작 등을 자세히 적어주시면 빠르게 도와드릴 수 있습니다.",
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionTitle(
            theme,
            scheme,
            icon: Icons.mail_outline_rounded,
            title: "답변 받을 연락처 (선택)",
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contactCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: _fieldDecoration(
              scheme,
              hintText: "예: 학교 메일 주소",
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInquiryGuideCard(ThemeData theme, ColorScheme scheme) {
    const List<String> bullets = <String>[
      "접수 후 순차적으로 확인해 답변드립니다.",
      "MJC ONE 앱 이용과 관련된 내용만 보내 주세요.",
      "학번, 비밀번호 등 민감한 개인정보는 작성하지 말아 주세요.",
    ];

    final bool isDark = theme.brightness == Brightness.dark;
    final TextStyle bulletStyle = theme.textTheme.bodySmall!.copyWith(
      color: scheme.onSurfaceVariant,
      height: 1.45,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _surfaceCardDecoration(scheme, isDark: isDark).copyWith(
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            theme,
            scheme,
            icon: Icons.info_outline_rounded,
            title: "문의 전 확인해 주세요",
          ),
          const SizedBox(height: 10),
          ...bullets.map(
            (text) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      "•",
                      style: bulletStyle.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: Text(text, style: bulletStyle)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDevLogSection(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _surfaceCardDecoration(scheme, isDark: isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            theme,
            scheme,
            icon: Icons.bug_report_outlined,
            title: "개발 로그 (Test Build)",
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _support.streamDevLogs(limit: 10),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text("로그를 불러오지 못했습니다.");
              }
              if (!snapshot.hasData) return const SizedBox();

              final items = snapshot.data!;
              if (items.isEmpty) {
                return const Text("등록된 로그가 없습니다.");
              }

              final displayCount = _showAllLogs ? items.length : (items.isNotEmpty ? 1 : 0);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: displayCount,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final data = items[index];
                      final String title = (data["title"] ?? "제목 없음").toString();
                      final String content = (data["content"] ?? "").toString();
                      final String dateStr = () {
                        final v = data["created_at"];
                        if (v is DateTime) return v.toString().split(".").first;
                        return "";
                      }();

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest
                              .withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  height: 1.2,
                                ),
                              ),
                              if (content.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  content,
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 13,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                              if (dateStr.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  dateStr,
                                  style: TextStyle(
                                    color: scheme.primary.withValues(alpha: 0.8),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                    },
                  ),
                  if (items.length > 1) ...[
                    const SizedBox(height: 4),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _showAllLogs = !_showAllLogs;
                        });
                      },
                      icon: Icon(
                        _showAllLogs ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                      ),
                      label: Text(
                        _showAllLogs
                            ? "접기"
                            : "이전 개발 일지 보기 (${items.length - 1}개 더보기)",
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: scheme.onSurfaceVariant,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
