import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter/material.dart";
import "package:url_launcher/url_launcher.dart";

/// MPU 대분류 화면: 핵심역량 프로그램 목록 조회
class MpuScreen extends StatelessWidget {
  const MpuScreen({super.key});

  Future<void> _openMpuWebsite(BuildContext context) async {
    final uri = Uri.parse("https://mpu.mjc.ac.kr/Main/default.aspx");
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("링크를 열 수 없습니다.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("MPU 핵심역량 프로그램")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("core_competencies")
            .doc("all")
            .collection("programs")
            .orderBy("created_at", descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text("데이터를 불러오는데 실패했습니다."));
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text("현재 등록된 프로그램이 없습니다."));
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: docs.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final title = data["title"]?.toString() ?? "제목 없음";
              final dDay = data["d_day"]?.toString() ?? "";
              final tags = List<String>.from(data["tags"] ?? []);

              return ListTile(
                onTap: () => _openMpuWebsite(context),
                title: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: tags.isNotEmpty
                    ? Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          tags.map((e) => "#$e").join(" "),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 12,
                          ),
                        ),
                      )
                    : null,
                trailing: dDay.isNotEmpty
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          dDay,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onErrorContainer,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      )
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}
