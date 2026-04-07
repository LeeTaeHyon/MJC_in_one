import "package:flutter/material.dart";

/// 도서관 대분류 화면 (추후 확장)
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("도서관")),
      body: const Center(
        child: Text("준비 중입니다."),
      ),
    );
  }
}
