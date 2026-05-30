import "package:flutter/material.dart";
import "package:mjc_in_one/services/user_data_repository.dart";
import "package:mjc_in_one/utils/bookmark_added_feedback.dart";
import "package:shared_preferences/shared_preferences.dart";

Future<Set<String>> loadCommunityNoticePinnedKeys(String boardId) async {
  final prefs = await SharedPreferences.getInstance();
  return (prefs.getStringList("pinned_notices_$boardId") ?? []).toSet();
}

Future<Set<String>> loadCommunityNoticeFavoriteKeys(String boardId) async {
  final prefs = await SharedPreferences.getInstance();
  return (prefs.getStringList("favorite_notices_$boardId") ?? []).toSet();
}

Future<Set<String>> toggleCommunityNoticePinned(
  BuildContext context,
  String boardId,
  String key,
) async {
  final prefs = await SharedPreferences.getInstance();
  final Set<String> cur =
      (prefs.getStringList("pinned_notices_$boardId") ?? []).toSet();
  final bool adding = !cur.contains(key);
  final Set<String> next = {...cur};
  if (next.contains(key)) {
    next.remove(key);
  } else {
    next.add(key);
  }
  await prefs.setStringList("pinned_notices_$boardId", next.toList());
  await UserDataRepository.instance.updateBookmarks(
    boardId,
    pinned: true,
    values: next.toList(),
  );
  if (context.mounted) {
    if (adding) {
      showBookmarkAddedSnackBar(context, openPinnedTab: true);
    } else {
      showBookmarkRemovedSnackBar(context, wasPinned: true);
    }
  }
  return next;
}

Future<Set<String>> toggleCommunityNoticeFavorite(
  BuildContext context,
  String boardId,
  String key,
) async {
  final prefs = await SharedPreferences.getInstance();
  final Set<String> cur =
      (prefs.getStringList("favorite_notices_$boardId") ?? []).toSet();
  final bool adding = !cur.contains(key);
  final Set<String> next = {...cur};
  if (next.contains(key)) {
    next.remove(key);
  } else {
    next.add(key);
  }
  await prefs.setStringList("favorite_notices_$boardId", next.toList());
  await UserDataRepository.instance.updateBookmarks(
    boardId,
    pinned: false,
    values: next.toList(),
  );
  if (context.mounted) {
    if (adding) {
      showBookmarkAddedSnackBar(context, openPinnedTab: false);
    } else {
      showBookmarkRemovedSnackBar(context, wasPinned: false);
    }
  }
  return next;
}
