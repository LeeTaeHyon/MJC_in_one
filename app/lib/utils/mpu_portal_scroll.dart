import "dart:convert";

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:mjc_in_one/notification_sources.dart";
import "package:mjc_in_one/screens/common_webview_screen.dart";
import "package:url_launcher/url_launcher.dart";

/// MPU 포털 메인 페이지에서 프로그램 카드(`#tab1 li.ex_slide2_li`)까지 스크롤하는 JS.
String buildMpuProgramScrollScript({
  String? programId,
  String? title,
}) {
  final String id = programId?.trim() ?? "";
  final String t = title?.trim() ?? "";
  if (id.isEmpty && t.isEmpty) return "";

  final String idJson = jsonEncode(id);
  final String titleJson = jsonEncode(t);

  return """
(function() {
  var progId = $idJson;
  var title = $titleJson;
  var maxAttempts = 20;
  var delayMs = 250;
  var topOffset = 72;

  function normalize(value) {
    return String(value || "").replace(/\\s+/g, " ").trim();
  }

  function ensureTab1Visible() {
    try {
      var tab1 = document.querySelector("#tab1");
      if (tab1 && tab1.offsetParent !== null) return;
      var tabLink =
        document.querySelector("a[href='#tab1'], a[data-target='#tab1'], [data-tab='tab1']") ||
        document.querySelector("#tab1-tab, .tab1, [aria-controls='tab1']");
      if (tabLink && typeof tabLink.click === "function") tabLink.click();
    } catch (e) {}
  }

  function findItem() {
    ensureTab1Visible();
    var root = document.querySelector("#tab1") || document;
    var items = root.querySelectorAll("li.ex_slide2_li:not(.all-list)");
    if (!items.length) {
      items = root.querySelectorAll("li.ex_slide2_li");
    }

    if (progId) {
      for (var i = 0; i < items.length; i += 1) {
        var img = items[i].querySelector("img");
        var src = img ? (img.getAttribute("src") || img.src || "") : "";
        if (
          src.indexOf("/" + progId + "_") !== -1 ||
          src.indexOf(progId + "_") === 0 ||
          src.indexOf("/" + progId + ".") !== -1
        ) {
          return items[i];
        }
      }
    }

    var titleNorm = normalize(title);
    if (titleNorm) {
      for (var j = 0; j < items.length; j += 1) {
        var h6 = items[j].querySelector(".p-15 h6, h6");
        if (h6 && normalize(h6.textContent) === titleNorm) return items[j];
      }
    }
    return null;
  }

  function scrollToItem(el) {
    try {
      var rect = el.getBoundingClientRect();
      var y = (window.scrollY || window.pageYOffset || 0) + rect.top - topOffset;
      window.scrollTo({ top: Math.max(0, y), behavior: "smooth" });
    } catch (e) {
      try {
        el.scrollIntoView({ behavior: "smooth", block: "center" });
      } catch (e2) {}
    }
  }

  function attempt(remaining) {
    var el = findItem();
    if (el) {
      scrollToItem(el);
      return;
    }
    if (remaining <= 0) return;
    setTimeout(function() {
      attempt(remaining - 1);
    }, delayMs);
  }

  attempt(maxAttempts);
})();
""";
}

/// 앱 MPU 공지 카드와 동일하게 포털을 열고, 가능하면 해당 프로그램 위치로 스크롤합니다.
Future<void> openMpuPortalForProgram(
  BuildContext context,
  Map<String, dynamic> program, {
  String webViewTitle = "핵심역량 관리 (MPU)",
}) async {
  final String url = await loadMpuPortalWebUrl();
  final String scrollScript = buildMpuProgramScrollScript(
    programId: (program["id"] ?? "").toString(),
    title: (program["title"] ?? "").toString(),
  );

  if (kIsWeb) {
    await launchUrl(Uri.parse(url), webOnlyWindowName: "_blank");
    return;
  }
  if (!context.mounted) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => CommonWebViewScreen(
        url: url,
        title: webViewTitle,
        postLoadJavaScript:
            scrollScript.isEmpty ? null : scrollScript,
      ),
    ),
  );
}
