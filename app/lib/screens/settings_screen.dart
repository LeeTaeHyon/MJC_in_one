import "package:flutter/material.dart";
import "package:mio_notice/theme/app_colors.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:url_launcher/url_launcher.dart";

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _allNoticesEnabled = true;
  List<String> _keywords = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// 설정값 로드
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _allNoticesEnabled = prefs.getBool("allNoticesEnabled") ?? true;
      _keywords = prefs.getStringList("keywords") ?? [];
    });
  }

  /// 전체 알림 스위치 저장
  Future<void> _toggleAllNotices(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("allNoticesEnabled", value);
    setState(() {
      _allNoticesEnabled = value;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(value ? "전체 알림이 활성화되었습니다." : "키워드 알림 모드로 전환되었습니다.")),
      );
    }
  }

  /// 키워드 관리 다이얼로그
  void _showKeywordDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("맞춤 키워드 관리"),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("등록한 키워드가 포함된 공지만 알림이 옵니다.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        hintText: "예: 장학, 기숙사, 성적",
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () async {
                            final text = controller.text.trim();
                            if (text.isNotEmpty && !_keywords.contains(text)) {
                              final prefs = await SharedPreferences.getInstance();
                              _keywords.add(text);
                              await prefs.setStringList("keywords", _keywords);
                              controller.clear();
                              setDialogState(() {}); // 다이얼로그 UI 갱신
                              setState(() {}); // 배경 설정창 UI 갱신
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      children: _keywords.map((kw) {
                        return Chip(
                          label: Text(kw),
                          onDeleted: () async {
                            final prefs = await SharedPreferences.getInstance();
                            _keywords.remove(kw);
                            await prefs.setStringList("keywords", _keywords);
                            setDialogState(() {});
                            setState(() {});
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("닫기"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 개발자 이메일 문의
  Future<void> _contactDeveloper() async {
    final Uri emailLaunchUri = Uri(
      scheme: "mailto",
      path: "dlxogudd@gmail.com",
      queryParameters: {"subject": "[MJC In One] 앱 관련 문의"},
    );
    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("메일 앱을 열 수 없습니다.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: const Text(
          "설정",
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              "알림 설정",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          SwitchListTile(
            activeColor: AppColors.primary,
            title: const Text("전체 공지사항 새글 알림"),
            subtitle: Text(_allNoticesEnabled ? "모든 새로운 공지 알림을 받습니다." : "키워드 알림 모드 작동 중"),
            value: _allNoticesEnabled,
            onChanged: _toggleAllNotices,
          ),
          ListTile(
            title: const Text("맞춤 키워드 알림 관리"),
            subtitle: Text(_keywords.isEmpty ? "등록된 키워드가 없습니다." : "현재 ${_keywords.length}개의 키워드 감시 중"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _showKeywordDialog,
          ),
          const Divider(height: 1),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              "앱 정보",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const ListTile(
            title: Text("앱 버전"),
            trailing: Text("1.0.0 (Build 1)"),
          ),
          ListTile(
            title: const Text("개발자에게 문의하기"),
            subtitle: const Text("불편한 점이나 건의사항을 보내주세요."),
            onTap: _contactDeveloper,
          ),
          ListTile(
            title: const Text("오픈소스 라이선스"),
            onTap: () {
              showLicensePage(
                context: context,
                applicationName: "MJC In One",
                applicationVersion: "1.0.0",
              );
            },
          ),
        ],
      ),
    );
  }
}
