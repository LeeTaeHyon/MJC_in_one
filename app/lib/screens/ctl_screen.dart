import "package:flutter/material.dart";

/// CTL 대분류 화면 (추후 확장)
class CtlScreen extends StatelessWidget {
  const CtlScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("CTL")),
      body: const Center(
        child: Text("준비 중입니다."),
      ),
    );
  }
}
