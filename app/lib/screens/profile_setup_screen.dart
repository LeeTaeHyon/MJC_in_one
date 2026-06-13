import "package:flutter/material.dart";
import "package:mjc_in_one/mpu_profile_prefs.dart";
import "package:mjc_in_one/theme/app_colors.dart";
import "package:mjc_in_one/utils/mjc_snack_bar.dart";
import "package:mjc_in_one/widgets/profile_form.dart";
import "package:shared_preferences/shared_preferences.dart";

const String kProfileSetupSeenPrefKey = "profile_setup_seen";

class ProfileSetupScreen extends StatelessWidget {
  const ProfileSetupScreen({super.key, required this.initialProfile});

  final MpuProfile initialProfile;

  static bool _opening = false;

  static Future<bool> shouldShow() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(kProfileSetupSeenPrefKey) == true) return false;
    final MpuProfile profile = await loadMpuProfile();
    return !profile.hasAnyValue;
  }

  static Future<void> maybePush(NavigatorState navigator) async {
    if (_opening) return;
    _opening = true;
    try {
      if (!await shouldShow()) return;
      final MpuProfile profile = await loadMpuProfile();
      if (!navigator.mounted) return;
      await navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ProfileSetupScreen(initialProfile: profile),
        ),
      );
    } finally {
      _opening = false;
    }
  }

  static Future<void> markSeen() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kProfileSetupSeenPrefKey, true);
  }

  Future<void> _skip(BuildContext context) async {
    await markSeen();
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _finish(BuildContext context, MpuProfile profile) async {
    await markSeen();
    if (context.mounted) {
      showMjcSnackBar(context, message: "프로필 정보를 저장했습니다.");
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text("프로필 설정"),
        actions: [
          TextButton(
            onPressed: () => _skip(context),
            child: const Text("나중에 입력"),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.14),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.person_add_alt_1_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "내 정보를 직접 입력할 수 있습니다",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "MPU 가져오기가 되지 않아도 이름, 학과, 학년, 학번을 직접 설정할 수 있습니다.",
                          style: TextStyle(
                            color: scheme.onSurface.withValues(alpha: 0.68),
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            ProfileForm(
              initialProfile: initialProfile,
              submitLabel: "저장하고 시작하기",
              onSaved: (MpuProfile profile) => _finish(context, profile),
            ),
          ],
        ),
      ),
    );
  }
}
