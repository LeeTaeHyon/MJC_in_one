import "package:flutter/material.dart";

/// MPU 대분류 화면 (추후 확장)
class MpuScreen extends StatelessWidget {
  const MpuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("MPU")),
      body: const Center(
        child: Text("준비 중입니다."),
      ),
    );
  }
}
