import "dart:ui_web" as ui_web;

import "package:flutter/material.dart";
import "package:web/web.dart" as web;

void registerNoticeBodyHtmlPlatformFrame({
  required String viewType,
  required String html,
}) {
  ui_web.platformViewRegistry.registerViewFactory(
    viewType,
    (int _) {
      final web.HTMLIFrameElement iframe = web.HTMLIFrameElement()
        ..style.border = "0"
        ..style.width = "100%"
        ..style.height = "100%";
      iframe.setAttribute("srcdoc", html);
      return iframe;
    },
  );
}

Widget noticeBodyHtmlPlatformFrame({
  required String viewType,
  required double height,
}) {
  return SizedBox(
    height: height,
    width: double.infinity,
    child: HtmlElementView(viewType: viewType),
  );
}
