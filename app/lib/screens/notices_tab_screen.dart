import "package:flutter/material.dart";
import "package:mio_notice/screens/ctl_screen.dart";
import "package:mio_notice/screens/main_website_screen.dart";
import "package:mio_notice/screens/mpu_screen.dart";

enum NoticesSubTab {
  main,
  ctl,
  mpu,
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
    setState(() => _current = next);
  }

  int get _currentIndex => NoticesSubTab.values.indexOf(_current);

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: _currentIndex,
      children: [
        MainWebsiteScreen(
          activeInNoticesTab: _current == NoticesSubTab.main,
        ),
        CtlScreen(activeInNoticesTab: _current == NoticesSubTab.ctl),
        MpuScreen(activeInNoticesTab: _current == NoticesSubTab.mpu),
      ],
    );
  }
}
