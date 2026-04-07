import "package:flutter/material.dart";
import "package:mio_notice/models/notice_model.dart";
import "package:mio_notice/services/firestore_service.dart";
import "package:mio_notice/widgets/notice_card.dart";

/// 메인홈페이지 소분류 탭 설정 (라벨 + Firestore category_id)
class MainWebsiteTabConfig {
  const MainWebsiteTabConfig({
    required this.label,
    required this.categoryId,
  });

  final String label;
  final String categoryId;
}

/// 하드코딩 최소화: 소분류 추가 시 이 리스트만 수정하면 됩니다.
const List<MainWebsiteTabConfig> kMainWebsiteTabs = [
  MainWebsiteTabConfig(label: "공지사항", categoryId: "main_notice"),
  MainWebsiteTabConfig(label: "학사공지", categoryId: "main_academic"),
  MainWebsiteTabConfig(label: "장학공지", categoryId: "main_scholarship"),
];

class MainWebsiteScreen extends StatelessWidget {
  MainWebsiteScreen({
    super.key,
    FirestoreService? firestoreService,
  }) : _firestoreService = firestoreService ?? FirestoreService();

  final FirestoreService _firestoreService;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: kMainWebsiteTabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("메인홈페이지"),
          bottom: TabBar(
            isScrollable: true,
            tabs: kMainWebsiteTabs
                .map((e) => Tab(text: e.label))
                .toList(growable: false),
          ),
        ),
        body: TabBarView(
          children: kMainWebsiteTabs
              .map(
                (tab) => _NoticeTabBody(
                  firestoreService: _firestoreService,
                  categoryId: tab.categoryId,
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _NoticeTabBody extends StatelessWidget {
  const _NoticeTabBody({
    required this.firestoreService,
    required this.categoryId,
  });

  final FirestoreService firestoreService;
  final String categoryId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Notice>>(
      stream: firestoreService.streamNotices(categoryId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                "데이터를 불러오지 못했습니다.\n${snapshot.error}",
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return const Center(child: Text("등록된 공지가 없습니다."));
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: items.length,
          itemBuilder: (context, index) {
            return NoticeCard(notice: items[index]);
          },
        );
      },
    );
  }
}
