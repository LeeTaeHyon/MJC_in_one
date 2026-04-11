import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter/material.dart";
import "package:url_launcher/url_launcher.dart";

import "package:mio_notice/theme/app_colors.dart";

/// CTL 대분류 화면: 프로그램 및 공지사항 탭
class CtlScreen extends StatelessWidget {
  const CtlScreen({super.key});

  static const Color _barColor = AppColors.teaching;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: _barColor,
              elevation: 0,
              child: SafeArea(
                bottom: false,
                child: SizedBox(
                  height: kToolbarHeight,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        "CTL 교수학습센터",
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ) ??
                            const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Material(
              color: Colors.white,
              child: TabBar(
                labelColor: _barColor,
                unselectedLabelColor: Colors.grey.shade600,
                indicatorColor: _barColor,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Theme.of(context).dividerColor,
                tabs: const [
                  Tab(text: "프로그램 목록"),
                  Tab(text: "공지사항"),
                ],
              ),
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  _CtlCollectionList(collectionPath: "programs"),
                  _CtlCollectionList(collectionPath: "notices"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CtlCollectionList extends StatelessWidget {
  const _CtlCollectionList({required this.collectionPath});

  final String collectionPath;

  Future<void> _openUrl(BuildContext context, String urlString) async {
    final uri = Uri.tryParse(urlString);
    if (uri == null || !uri.hasScheme) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("유효하지 않은 링크입니다.")),
        );
      }
      return;
    }
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("링크를 열 수 없습니다.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("ctl_data")
          .doc(collectionPath)
          .collection("items")
          .orderBy("created_at", descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.teaching),
          );
        }
        if (snapshot.hasError) {
          return const Center(child: Text("데이터를 불러오는데 실패했습니다."));
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text("등록된 데이터가 없습니다."));
        }

        return ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: docs.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final title = data["title"]?.toString() ?? "제목 없음";
            final link = data["link"]?.toString() ?? "";

            String subtitleText = "";
            if (collectionPath == "programs") {
              final date = data["reg_date"]?.toString() ?? "";
              final status = data["status"]?.toString() ?? "";
              subtitleText = status.isNotEmpty ? "[$status] $date" : date;
            } else {
              final date = data["date"]?.toString() ?? "";
              final author = data["author"]?.toString() ?? "";
              subtitleText = author.isNotEmpty ? "$author | $date" : date;
            }

            return ListTile(
              onTap: () => _openUrl(context, link),
              title: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              subtitle: subtitleText.isNotEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        subtitleText,
                        style: const TextStyle(
                          color: AppColors.mutedForeground,
                          fontSize: 13,
                        ),
                      ),
                    )
                  : null,
              trailing: const Icon(Icons.open_in_browser, size: 20),
            );
          },
        );
      },
    );
  }
}
