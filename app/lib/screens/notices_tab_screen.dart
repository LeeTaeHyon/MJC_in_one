import "package:flutter/material.dart";
import "package:mjc_in_one/screens/ctl_screen.dart";
import "package:mjc_in_one/screens/department_notices_screen.dart";
import "package:mjc_in_one/screens/main_website_screen.dart";
import "package:mjc_in_one/screens/mpu_screen.dart";
import "package:mjc_in_one/widgets/mjc_directional_screen_transition.dart";

enum NoticesSubTab {
  main,
  ctl,
  mpu,
  dept,
}

extension NoticesSubTabLabel on NoticesSubTab {
  String get label {
    switch (this) {
      case NoticesSubTab.main:
        return "본교";
      case NoticesSubTab.ctl:
        return "교수학습";
      case NoticesSubTab.mpu:
        return "역량관리";
      case NoticesSubTab.dept:
        return "학과";
    }
  }

  IconData get icon {
    switch (this) {
      case NoticesSubTab.main:
        return Icons.school_rounded;
      case NoticesSubTab.ctl:
        return Icons.menu_book_rounded;
      case NoticesSubTab.mpu:
        return Icons.emoji_events_rounded;
      case NoticesSubTab.dept:
        return Icons.groups_outlined;
    }
  }
}

class NoticesTabScreen extends StatefulWidget {
  const NoticesTabScreen({
    super.key,
    required this.subTabNotifier,
  });

  final ValueNotifier<NoticesSubTab> subTabNotifier;

  @override
  State<NoticesTabScreen> createState() => _NoticesTabScreenState();
}

class _NoticesTabScreenState extends State<NoticesTabScreen> {
  NoticesSubTab _current = NoticesSubTab.main;
  int _slideDirection = 1;

  @override
  void initState() {
    super.initState();
    _current = widget.subTabNotifier.value;
    widget.subTabNotifier.addListener(_handleRequestedSubTab);
  }

  @override
  void didUpdateWidget(covariant NoticesTabScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.subTabNotifier, widget.subTabNotifier)) {
      oldWidget.subTabNotifier.removeListener(_handleRequestedSubTab);
      _current = widget.subTabNotifier.value;
      widget.subTabNotifier.addListener(_handleRequestedSubTab);
    }
  }

  @override
  void dispose() {
    widget.subTabNotifier.removeListener(_handleRequestedSubTab);
    super.dispose();
  }

  void _handleRequestedSubTab() {
    final NoticesSubTab next = widget.subTabNotifier.value;
    if (next == _current || !mounted) return;
    setState(() {
      _slideDirection = MjcDirectionalScreenTransition.directionForStep(
        _current.index,
        next.index,
      );
      _current = next;
    });
  }

  Widget _buildCurrent() {
    switch (_current) {
      case NoticesSubTab.main:
        return MainWebsiteScreen(
          activeInNoticesTab: true,
          noticeSubTabNotifier: widget.subTabNotifier,
        );
      case NoticesSubTab.ctl:
        return const CtlScreen(activeInNoticesTab: true);
      case NoticesSubTab.mpu:
        return const MpuScreen(activeInNoticesTab: true);
      case NoticesSubTab.dept:
        return const DepartmentNoticesScreen(activeInNoticesTab: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // NOTE: `IndexedStack`는 각 화면 상태(스크롤/탭)를 유지합니다.
    // 공지 플로팅 서브탭 전환 시마다 초기화되게 하려면, 선택된 화면만 빌드하고
    // 전환 시 이전 화면이 dispose 되도록 구성합니다.
    return MjcDirectionalScreenTransition.animatedSwitcher(
      activeKey: _current,
      direction: _slideDirection,
      child: _buildCurrent(),
    );
  }
}
