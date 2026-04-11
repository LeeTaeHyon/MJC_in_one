import "package:flutter/material.dart";

/// figma MainNotices MUI Chip(높이 20, 작은 글꼴) 스타일.
class NewNoticeBadge extends StatelessWidget {
  const NewNoticeBadge({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        "NEW",
        style: TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
    );
  }
}
