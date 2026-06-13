import "dart:convert";

import "package:flutter/material.dart";
import "package:mjc_in_one/mpu_profile_prefs.dart";
import "package:mjc_in_one/services/user_data_repository.dart";
import "package:mjc_in_one/utils/mjc_snack_bar.dart";
import "package:mjc_in_one/widgets/webview_navigation_overlay.dart";
import "package:webview_flutter/webview_flutter.dart";

class MpuProfileImportScreen extends StatefulWidget {
  const MpuProfileImportScreen({super.key});

  static const String initialUrl = "https://mpu.mjc.ac.kr/Main/default.aspx";

  @override
  State<MpuProfileImportScreen> createState() => _MpuProfileImportScreenState();
}

class _MpuProfileImportScreenState extends State<MpuProfileImportScreen> {
  static const String _profileChannelName = "MjcMpuProfile";

  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isExtracting = false;
  bool _canGoBack = false;
  bool _canGoForward = false;

  @override
  void initState() {
    super.initState();
    final WebViewController controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        _profileChannelName,
        onMessageReceived: _onProfileMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() => _isLoading = true);
            _syncNavigationHistory();
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() => _isLoading = false);
            _syncNavigationHistory();
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint("MPU profile webview error: ${error.description}");
          },
        ),
      )
      ..loadRequest(Uri.parse(MpuProfileImportScreen.initialUrl));

    _controller = controller;
  }

  Future<void> _syncNavigationHistory() async {
    final bool back = await _controller.canGoBack();
    final bool forward = await _controller.canGoForward();
    if (!mounted) return;
    setState(() {
      _canGoBack = back;
      _canGoForward = forward;
    });
  }

  Future<void> _onProfileMessage(JavaScriptMessage message) async {
    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(message.message) as Map<String, dynamic>;
    } catch (e) {
      debugPrint("MPU profile message parse failed: $e");
      if (mounted) {
        setState(() => _isExtracting = false);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        showMjcSnackBar(context, message: "마이페이지 정보를 읽지 못했습니다.");
      }
      return;
    }

    final String status = (payload["status"] ?? "").toString();
    if (status != "ok") {
      if (!mounted) return;
      setState(() => _isExtracting = false);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      showMjcSnackBar(context, message: "로그인 후 대시보드가 보이면 다시 눌러 주세요.");
      return;
    }

    final MpuProfile currentProfile = await loadMpuProfile();
    final MpuProfile profile = currentProfile.copyWith(
      name: (payload["name"] ?? currentProfile.name).toString(),
      grade: (payload["grade"] ?? currentProfile.grade).toString(),
      mileage: (payload["mileage"] ?? currentProfile.mileage).toString(),
    );

    if (!profile.hasAnyValue) {
      if (!mounted) return;
      setState(() => _isExtracting = false);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      showMjcSnackBar(context, message: "이름, 학년, 마일리지를 찾지 못했습니다.");
      return;
    }

    await saveMpuProfile(profile);
    await UserDataRepository.instance.pushSnapshotToCloud();
    if (!mounted) return;
    setState(() => _isExtracting = false);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    showMjcSnackBar(context, message: "마이페이지 정보를 가져왔습니다.");
    Navigator.of(context).pop(true);
  }

  Future<void> _extractProfile() async {
    if (_isExtracting) return;
    setState(() => _isExtracting = true);
    try {
      await _controller.runJavaScript(
        _profileScraperScript.replaceAll("__CHANNEL__", _profileChannelName),
      );
    } catch (e) {
      debugPrint("MPU profile scraper failed: $e");
      if (!mounted) return;
      setState(() => _isExtracting = false);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      showMjcSnackBar(context, message: "마이페이지 정보를 가져오지 못했습니다.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            elevation: 3,
            color: scheme.surface,
            shadowColor: Colors.black.withValues(alpha: isDark ? 0.45 : 0.26),
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: kToolbarHeight,
                child: Row(
                  children: [
                    IconButton(
                      tooltip: "닫기",
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close_rounded),
                    ),
                    const Expanded(
                      child: Text(
                        "MPU 마이페이지",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: TextButton.icon(
                        onPressed: _isExtracting ? null : _extractProfile,
                        icon: _isExtracting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.download_done_rounded, size: 20),
                        label: const Text("가져오기"),
                        style: TextButton.styleFrom(
                          foregroundColor:
                              Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_isLoading)
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
                WebViewNavigationOverlay(
                  canGoBack: _canGoBack,
                  canGoForward: _canGoForward,
                  onGoBack: () async {
                    await _controller.goBack();
                    await _syncNavigationHistory();
                  },
                  onGoForward: () async {
                    await _controller.goForward();
                    await _syncNavigationHistory();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const String _profileScraperScript = r'''
(function() {
  var channel = window.__CHANNEL__;
  var maxAttempts = 10;
  var delayMs = 400;

  function normalize(value) {
    return String(value || "")
      .replace(/\s+/g, " ")
      .replace(/[：:]/g, "")
      .trim();
  }

  function cleanValue(value) {
    return normalize(value)
      .replace(/^(성명|이름|학생명|학년|마이\s*마일리지|내\s*마일리지|마일리지)\s*/, "")
      .trim();
  }

  function textOf(node) {
    if (!node) return "";
    return normalize(node.innerText || node.textContent || "");
  }

  function firstText(selectors) {
    for (var i = 0; i < selectors.length; i += 1) {
      try {
        var node = document.querySelector(selectors[i]);
        var text = cleanValue(textOf(node));
        if (text) return text;
      } catch (e) {}
    }
    return "";
  }

  function siblingValue(node) {
    if (!node) return "";
    var current = node.nextElementSibling;
    while (current) {
      var text = cleanValue(textOf(current));
      if (text) return text;
      current = current.nextElementSibling;
    }
    return "";
  }

  function tableValue(node, labels) {
    var row = node && node.closest ? node.closest("tr") : null;
    if (!row) return "";
    var cells = Array.prototype.slice.call(row.children || []);
    var index = cells.indexOf(node);
    for (var i = index + 1; i < cells.length; i += 1) {
      var text = cleanValue(textOf(cells[i]));
      if (text && labels.indexOf(text) === -1) return text;
    }
    return "";
  }

  function valueNearLabel(labelTexts) {
    var labels = labelTexts.map(normalize);
    var nodes = Array.prototype.slice.call(
      document.querySelectorAll("th,td,dt,dd,label,span,div,p,li,strong,b")
    );

    for (var i = 0; i < nodes.length; i += 1) {
      var node = nodes[i];
      var text = textOf(node);
      if (!text) continue;

      for (var j = 0; j < labels.length; j += 1) {
        var label = labels[j];
        if (text === label || text.indexOf(label + " ") === 0) {
          var inlineValue = cleanValue(text.slice(label.length));
          if (inlineValue && inlineValue !== label) return inlineValue;

          var table = tableValue(node, labels);
          if (table) return table;

          var sibling = siblingValue(node);
          if (sibling) return sibling;

          var parentSibling = siblingValue(node.parentElement);
          if (parentSibling) return parentSibling;
        }
      }
    }
    return "";
  }

  function compactGrade(value) {
    var text = cleanValue(value);
    var m = text.match(/[1-6]\s*학년|[1-6]\s*년/);
    if (m) {
      var d = m[0].match(/[1-6]/);
      return d ? d[0] + "학년" : text;
    }
    var g = text.match(/grade\s*([1-6])/i);
    if (g) return g[1] + "학년";
    var digit = text.match(/^[1-6]$/);
    return digit ? digit[0] + "학년" : text;
  }

  function parseNameGradeLine(raw) {
    var text = cleanValue(raw);
    var name = "";
    var grade = "";
    var m = text.match(/^(.+?)\s*\(\s*([0-9])\s*학년\s*\)\s*$/);
    if (m) {
      name = cleanValue(m[1]);
      grade = compactGrade(m[2] + "학년");
      return {name: name, grade: grade};
    }
    m = text.match(/^(.+?)\s*\(\s*([0-9])\s*\)\s*$/);
    if (m) {
      name = cleanValue(m[1]);
      grade = compactGrade(m[2] + "학년");
      return {name: name, grade: grade};
    }
    return {name: "", grade: ""};
  }

  function scanNameGradeInDocument() {
    var candidates = Array.prototype.slice.call(
      document.querySelectorAll("h1,h2,h3,h4,h5,h6,span,div,p,strong,b,a")
    );
    for (var i = 0; i < candidates.length; i += 1) {
      var t = textOf(candidates[i]);
      if (!t || t.length > 40) continue;
      if (t.indexOf("학년") === -1 && t.indexOf("(") === -1) continue;
      var parsed = parseNameGradeLine(t);
      if (parsed.name && parsed.grade) return parsed;
    }
    var bodyLine = textOf(document.body);
    var bm = bodyLine.match(/([가-힣·\s]{2,12})\s*\(\s*([0-9])\s*학년\s*\)/);
    if (bm) {
      return {
        name: cleanValue(bm[1]),
        grade: compactGrade(bm[2] + "학년")
      };
    }
    return {name: "", grade: ""};
  }

  function extractLeadingNumber(text) {
    var m = String(text || "").match(/(\d+(?:\.\d+)?)/);
    return m ? m[1] : "";
  }

  function findMileage() {
    var labeled = valueNearLabel([
      "마이 마일리지",
      "내 마일리지",
      "마일리지",
      "My Mileage",
      "Mileage"
    ]);
    if (labeled) {
      var n = extractLeadingNumber(labeled);
      if (n) return n;
    }

    var direct = firstText([
      "[class*='mileage']",
      "[class*='Mileage']",
      "[id*='mileage']",
      "[id*='Mileage']",
      "[data-mileage]",
      "[data-milage]"
    ]);
    if (direct) {
      var dn = extractLeadingNumber(direct);
      if (dn) return dn;
    }

    var nodes = Array.prototype.slice.call(
      document.querySelectorAll("span,div,p,strong,b,li,td,h3,h4")
    );
    for (var i = 0; i < nodes.length; i += 1) {
      var t = textOf(nodes[i]);
      if (!t || t.length > 80) continue;
      if (t.indexOf("마일리지") === -1 && t.toLowerCase().indexOf("mileage") === -1) {
        continue;
      }
      var hit = extractLeadingNumber(t);
      if (hit && Number(hit) <= 100000) return hit;
    }

    var body = textOf(document.body);
    var km = body.match(/(\d+(?:\.\d+)?)\s*(?:마이\s*)?마일리지/);
    if (km) return km[1];
    var em = body.match(/(\d+(?:\.\d+)?)\s*my\s*mileage/i);
    if (em) return em[1];
    return "";
  }

  function readProfile() {
    var scanned = scanNameGradeInDocument();
    var name =
      firstText([
        "#lblUserName",
        "#lblName",
        "#userName",
        "#studentName",
        "[id*='UserName']",
        "[id*='StudentName']",
        "[class*='user-name']",
        "[class*='student-name']"
      ]) ||
      valueNearLabel(["성명", "이름", "학생명"]) ||
      scanned.name;

    var grade =
      firstText([
        "#lblGrade",
        "#grade",
        "[id*='Grade']",
        "[class*='grade']"
      ]) ||
      valueNearLabel(["학년"]) ||
      scanned.grade;

    if (name && name.indexOf("(") !== -1 && !grade) {
      var parsed = parseNameGradeLine(name);
      if (parsed.name) name = parsed.name;
      if (parsed.grade) grade = parsed.grade;
    }

    var englishGrade = textOf(document.body).match(/grade\s*([1-6])/i);
    if (!grade && englishGrade) {
      grade = compactGrade(englishGrade[1] + "학년");
    }

    var mileage = findMileage();

    return {
      name: cleanValue(name),
      grade: compactGrade(grade),
      mileage: cleanValue(mileage)
    };
  }

  function send(status, profile) {
    try {
      channel.postMessage(JSON.stringify(Object.assign({status: status}, profile || {})));
    } catch (e) {}
  }

  function attempt(remaining) {
    var profile = readProfile();
    if (profile.name || profile.grade || profile.mileage) {
      send("ok", profile);
      return;
    }
    if (remaining <= 0) {
      send("empty", {url: location.href, title: document.title});
      return;
    }
    setTimeout(function() {
      attempt(remaining - 1);
    }, delayMs);
  }

  attempt(maxAttempts);
})();
''';
