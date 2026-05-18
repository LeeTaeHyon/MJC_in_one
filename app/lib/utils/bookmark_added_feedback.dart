import "package:flutter/material.dart";
import "package:mjc_in_one/screens/my_page_screen.dart";
import "package:mjc_in_one/utils/mjc_snack_bar.dart";
import "package:mjc_in_one/widgets/main_navigation_scope.dart";
import "package:mjc_in_one/widgets/scroll_to_top_scope.dart";

/// [MainNavigationScreen] 공지 서브메뉴를 잠시 숨길 때 사용합니다. 0보다 크면 숨김.
///
/// 고정·즐겨찾기 관련 스낵바 표시 시 증가·닫힐 때 감소합니다.
final ValueNotifier<int> bookmarkSnackBarSubnavSuppressionCount =
    ValueNotifier<int>(0);

void _showBookmarkPinFavoriteSnackBar(
  BuildContext context, {
  required String message,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  showMjcSnackBar(
    context,
    message: message,
    actionLabel: actionLabel,
    onAction: onAction,
    onShown: () => bookmarkSnackBarSubnavSuppressionCount.value++,
    onClosed: () {
      final int n = bookmarkSnackBarSubnavSuppressionCount.value;
      if (n > 0) {
        bookmarkSnackBarSubnavSuppressionCount.value = n - 1;
      }
    },
  );
}

/// 즐겨찾기·상단 고정을 **추가**한 뒤 안내 스낵바(마이페이지 이동 액션).
void _openMyPageFromBookmarkSnackBar(
  BuildContext context, {
  required bool openPinnedTab,
}) {
  final int bookmarkTabIndex = openPinnedTab ? 0 : 1;
  final MainNavigationNavigate? navigate =
      MainNavigationScope.maybeNavigate(context);
  if (navigate != null) {
    navigate(
      MainNavTabIndex.mypage,
      myPageBookmarkTabIndex: bookmarkTabIndex,
    );
    return;
  }
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => MyPageScreen(
        initialBookmarkTabIndex: bookmarkTabIndex,
      ),
    ),
  );
}

/// 즐겨찾기·상단 고정을 **추가**한 뒤 안내 스낵바(마이페이지 이동 액션).
void showBookmarkAddedSnackBar(
  BuildContext context, {
  required bool openPinnedTab,
}) {
  _showBookmarkPinFavoriteSnackBar(
    context,
    message: openPinnedTab ? "고정되었습니다." : "저장되었습니다.",
    actionLabel: "마이페이지에서 확인",
    onAction: () => _openMyPageFromBookmarkSnackBar(
      context,
      openPinnedTab: openPinnedTab,
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
  );
}
