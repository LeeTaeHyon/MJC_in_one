import "package:flutter/material.dart";

/// 관리자 콘솔: 이 너비 미만이면 모바일 레이아웃(하단 탭·풀스크린 편집 등).
const double kAdminMobileBreakpoint = 600;

bool adminIsMobile(BuildContext context) =>
    MediaQuery.sizeOf(context).width < kAdminMobileBreakpoint;
