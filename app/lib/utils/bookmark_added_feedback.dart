import "package:flutter/material.dart";
import "package:mjc_in_one/screens/my_page_screen.dart";

/// [MainNavigationScreen] 공지 서브메뉴를 잠시 숨길 때 사용합니다. 0보다 크면 숨김.
///
/// 고정·즐겨찾기 관련 스낵바 표시 시 증가·닫힐 때 감소합니다.
final ValueNotifier<int> bookmarkSnackBarSubnavSuppressionCount =
    ValueNotifier<int>(0);

void _showBookmarkPinFavoriteSnackBar(
  BuildContext context, {
  required String message,
  SnackBarAction? action,
}) {
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  bookmarkSnackBarSubnavSuppressionCount.value++;
  messenger.hideCurrentSnackBar();
  final ScaffoldFeatureController<SnackBar, SnackBarClosedReason> controller =
      messenger.showSnackBar(
    SnackBar(
      duration: const Duration(milliseconds: 1500),
      persist: false,
      content: Text(message),
      action: action,
    ),
  );
  controller.closed.then((_) {
    final int n = bookmarkSnackBarSubnavSuppressionCount.value;
    if (n > 0) {
      bookmarkSnackBarSubnavSuppressionCount.value = n - 1;
    }
  });
}

/// 즐겨찾기·상단 고정을 **추가**한 뒤 안내 스낵바(마이페이지 이동 액션).
void showBookmarkAddedSnackBar(
  BuildContext context, {
  required bool openPinnedTab,
}) {
  final NavigatorState nav = Navigator.of(context);
  _showBookmarkPinFavoriteSnackBar(
    context,
    message: openPinnedTab
        ? "상단 고정에 추가되었습니다."
        : "즐겨찾기에 추가되었습니다.",
    action: SnackBarAction(
      label: "마이페이지에서 보기",
      onPressed: () {
        nav.push<void>(
          MaterialPageRoute<void>(
            builder: (_) => MyPageScreen(
              initialBookmarkTabIndex: openPinnedTab ? 0 : 1,
            ),
          ),
        );
      },
    ),
  );
}

/// 즐겨찾기·상단 고정을 **해제**한 뒤 안내 스낵바.
void showBookmarkRemovedSnackBar(
  BuildContext context, {
  required bool wasPinned,
}) {
  _showBookmarkPinFavoriteSnackBar(
    context,
    message: wasPinned ? "상단 고정을 해제했습니다." : "즐겨찾기를 해제했습니다.",
    action: null,
  );
}
