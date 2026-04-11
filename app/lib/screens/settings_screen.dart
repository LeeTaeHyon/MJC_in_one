import "package:flutter/material.dart";

import "package:mio_notice/theme/app_colors.dart";

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _allNoticesEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "설정",
          style: TextStyle(fontWeight: FontWeight.w600),
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
            title: const Text("전체 공지사항 새글 알림"),
            subtitle: const Text("모든 새로운 공지/프로그램 알림을 받습니다."),
            value: _allNoticesEnabled,
            onChanged: (value) {
              setState(() {
                _allNoticesEnabled = value;
              });
              // TODO: FCM 서버 토픽 구독/취소 연동
            },
          ),
          ListTile(
            title: const Text("맞춤 키워드 알림 관리"),
            subtitle: const Text("원하는 키워드(예: 장학, 기숙사)만 쏙쏙 골라 받기"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // TODO: 키워드 설정 모달 띄우기
            },
          ),
          const Divider(height: 1),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              "화면 설정",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          ListTile(
            title: const Text("다크 모드"),
            trailing: const Text(
              "시스템 설정 사용",
              style: TextStyle(
                fontSize: 14,
                color: AppColors.mutedForeground,
              ),
            ),
            onTap: () {
              // TODO: 다크모드 설정 기능
            },
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
            trailing: Text("1.0.0"),
          ),
          ListTile(
            title: const Text("개발자에게 문의하기"),
            onTap: () {
              // 의견 보내기 UI
            },
          ),
          ListTile(
            title: const Text("오픈소스 라이선스"),
            onTap: () {
              showLicensePage(context: context, applicationName: "MJC In One");
            },
          ),
        ],
      ),
    );
  }
}
