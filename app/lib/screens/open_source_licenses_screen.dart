import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "dart:convert";
import "package:mio_notice/theme/app_colors.dart";
import "package:mio_notice/widgets/scroll_to_top_scope.dart";

class _LicenseParagraph {
  const _LicenseParagraph({required this.indent, required this.text});

  final int indent;
  final String text;
}

/// 동일 라이선스 전문은 여러 번 올 수 있어 본문 기준으로 묶습니다.
class _MergedLicense {
  _MergedLicense({required this.paragraphs, required this.sortedNames});

  final List<_LicenseParagraph> paragraphs;
  final List<String> sortedNames;
}

class _LicenseTile {
  _LicenseTile({required this.sortedNames, required this.sections});

  final List<String> sortedNames;

  /// 하나의 타일 안에 여러 라이선스 본문(섹션)이 들어갈 수 있습니다.
  final List<List<_LicenseParagraph>> sections;
}

String _normalizeParagraphText(String s) {
  // 라이선스 원문에서 공백/개행 차이로 같은 본문이 여러 개 뜨는 케이스가 있어
  // 본문 키 생성 시에만 보수적으로 정규화합니다(표시 텍스트는 원문 그대로 유지).
  return s.replaceAll(RegExp(r"\s+"), " ").trim();
}

String _bodyKeyFromParagraphs(Iterable<_LicenseParagraph> paragraphs) {
  return paragraphs
      .map((p) => "${p.indent}\u{001F}${_normalizeParagraphText(p.text)}")
      .join("\u{001E}");
}

List<_MergedLicense> _mergeDuplicateLicenseBodiesFromRegistry(
  List<LicenseEntry> raw,
) {
  final byBody = <String, ({List<_LicenseParagraph> source, Set<String> names})>{};
  for (final e in raw) {
    final paragraphs = e.paragraphs
        .map((p) => _LicenseParagraph(indent: p.indent, text: p.text))
        .toList(growable: false);
    final key = _bodyKeyFromParagraphs(paragraphs);
    final cur = byBody[key];
    if (cur == null) {
      byBody[key] = (source: paragraphs, names: {...e.packages});
    } else {
      cur.names.addAll(e.packages);
    }
  }
  return _finalizeMerged(byBody.values.map((v) {
    return _MergedLicense(
      paragraphs: v.source,
      sortedNames: (v.names.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()))),
    );
  }).toList());
}

List<_MergedLicense> _mergeDuplicateLicenseBodiesFromJson(List<dynamic> raw) {
  final byBody = <String, ({List<_LicenseParagraph> source, Set<String> names})>{};
  for (final item in raw) {
    if (item is! Map) continue;

    final packages = (item["packages"] is List)
        ? (item["packages"] as List).whereType<String>().toList()
        : const <String>[];
    final paragraphsRaw = (item["paragraphs"] is List)
        ? (item["paragraphs"] as List).whereType<Map>().toList()
        : const <Map>[];
    final paragraphs = paragraphsRaw
        .map((p) {
          final indent = p["indent"];
          final text = p["text"];
          return _LicenseParagraph(
            indent: indent is int ? indent : int.tryParse("$indent") ?? 0,
            text: text is String ? text : "$text",
          );
        })
        .toList(growable: false);

    final key = _bodyKeyFromParagraphs(paragraphs);
    final cur = byBody[key];
    if (cur == null) {
      byBody[key] = (source: paragraphs, names: {...packages});
    } else {
      cur.names.addAll(packages);
    }
  }

  return _finalizeMerged(byBody.values.map((v) {
    return _MergedLicense(
      paragraphs: v.source,
      sortedNames: (v.names.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()))),
    );
  }).toList());
}

List<_MergedLicense> _finalizeMerged(List<_MergedLicense> merged) {
  merged.sort((a, b) {
    final an = a.sortedNames.isEmpty ? "" : a.sortedNames.first;
    final bn = b.sortedNames.isEmpty ? "" : b.sortedNames.first;
    return an.toLowerCase().compareTo(bn.toLowerCase());
  });
  return merged;
}

List<_LicenseTile> _toTiles(List<_MergedLicense> mergedBodies) {
  // 핵심: 같은 패키지명이 여러 라이선스 본문(서로 다른 chunk)으로 반복 등장할 수 있어
  // 단일 패키지 항목은 "패키지명 기준"으로 한 번 더 묶어서 타일 1개로 보여줍니다.
  final singleByName = <String, List<_MergedLicense>>{};
  final multi = <_MergedLicense>[];

  for (final m in mergedBodies) {
    if (m.sortedNames.length == 1) {
      (singleByName[m.sortedNames.single] ??= []).add(m);
    } else {
      multi.add(m);
    }
  }

  final tiles = <_LicenseTile>[];

  for (final entry in singleByName.entries) {
    final name = entry.key;
    final items = entry.value;

    // 같은 패키지 안에서도 동일 본문이 중복으로 들어올 수 있어 섹션 키로 제거합니다.
    final byBody = <String, List<_LicenseParagraph>>{};
    for (final i in items) {
      byBody[_bodyKeyFromParagraphs(i.paragraphs)] = i.paragraphs;
    }

    final sections = byBody.values.toList();
    sections.sort((a, b) {
      final at = a.isEmpty ? "" : _normalizeParagraphText(a.first.text);
      final bt = b.isEmpty ? "" : _normalizeParagraphText(b.first.text);
      return at.toLowerCase().compareTo(bt.toLowerCase());
    });

    tiles.add(_LicenseTile(sortedNames: [name], sections: sections));
  }

  for (final m in multi) {
    tiles.add(_LicenseTile(sortedNames: m.sortedNames, sections: [m.paragraphs]));
  }

  tiles.sort((a, b) {
    final an = a.sortedNames.isEmpty ? "" : a.sortedNames.first;
    final bn = b.sortedNames.isEmpty ? "" : b.sortedNames.first;
    return an.toLowerCase().compareTo(bn.toLowerCase());
  });

  return tiles;
}

String _compactTitle(List<String> names) {
  if (names.isEmpty) return "기타";
  if (names.length == 1) return names.single;
  if (names.length == 2) return "${names[0]}, ${names[1]}";
  return "${names.first} 외 ${names.length - 1}개";
}

/// [LicenseRegistry] 고지를 한 화면에서 [ExpansionTile]로만 표시합니다.
class OpenSourceLicensesScreen extends StatefulWidget {
  const OpenSourceLicensesScreen({super.key});

  @override
  State<OpenSourceLicensesScreen> createState() =>
      _OpenSourceLicensesScreenState();
}

class _OpenSourceLicensesScreenState extends State<OpenSourceLicensesScreen> {
  late final Future<List<_LicenseTile>> _licensesFuture;
  final ScrollController _scrollController = ScrollController();
  ScrollToTopCoordinator? _scrollRouteCoordinator;
  bool _registeredScrollRoute = false;

  Future<List<_LicenseTile>> _loadMergedLicenses() async {
    // 1) JSON 에셋(정제본) 우선. (비워져있거나 없으면 2)로 폴백)
    try {
      final s = await rootBundle.loadString("assets/licenses/licenses.json");
      final decoded = jsonDecode(s);
      if (decoded is List) {
        final mergedBodies = _mergeDuplicateLicenseBodiesFromJson(decoded);
        if (mergedBodies.isNotEmpty) return _toTiles(mergedBodies);
      }
    } catch (_) {
      // ignore: fall back to registry
    }

    // 2) Flutter LicenseRegistry에서 동적 수집(기본 폴백)
    final raw = await LicenseRegistry.licenses.toList();
    return _toTiles(_mergeDuplicateLicenseBodiesFromRegistry(raw));
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onLicenseListScroll);
    _licensesFuture = _loadMergedLicenses();
  }

  void _onLicenseListScroll() {
    if (!mounted) return;
    _scrollRouteCoordinator?.reportRouteScroll(
      _scrollController.offset,
      ScrollFabMetrics.viewportHeightInScrollListener(_scrollController),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_registeredScrollRoute) return;
    final ScrollToTopCoordinator? c = ScrollToTopScope.maybeOf(context);
    if (c != null) {
      _scrollRouteCoordinator = c;
      c.pushRouteHandler(_scrollContentToTop);
      _registeredScrollRoute = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        c.reportRouteScroll(
          _scrollController.offset,
          ScrollFabMetrics.viewportHeightForThreshold(_scrollController, context),
        );
      });
    }
  }

  void _scrollContentToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onLicenseListScroll);
    if (_registeredScrollRoute) {
      _scrollRouteCoordinator?.popRouteHandler();
    }
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: const Text(
          "오픈소스 라이선스",
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
      body: FutureBuilder<List<_LicenseTile>>(
        future: _licensesFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  "라이선스 정보를 불러오지 못했습니다.\n${snapshot.error}",
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final tiles = snapshot.data!;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted || !_scrollController.hasClients) return;
            _scrollRouteCoordinator?.reportRouteScroll(
              _scrollController.offset,
              ScrollFabMetrics.viewportHeightForThreshold(
                _scrollController,
                context,
              ),
            );
          });

          return ListView(
            controller: _scrollController,
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Text(
                  "Flutter·플러그인·기타 구성요소의 라이선스입니다. "
                  "항목을 펼치면 전문을 볼 수 있습니다.",
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
              ...tiles.map(
                (t) => ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                  collapsedShape: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                  shape: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                  title: Text(
                    _compactTitle(t.sortedNames),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: t.sortedNames.length > 1
                      ? Text(
                          t.sortedNames.length <= 6
                              ? "포함: ${t.sortedNames.join(", ")}"
                              : "포함: ${t.sortedNames.take(4).join(", ")} "
                                    "외 ${t.sortedNames.length - 4}개",
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.3,
                            color: Colors.grey.shade600,
                          ),
                        )
                      : null,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (t.sortedNames.length > 6) ...[
                            SelectableText(
                              "적용 구성요소:\n${t.sortedNames.join(", ")}",
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          for (var si = 0; si < t.sections.length; si++) ...[
                            if (t.sections.length > 1 && si > 0) ...[
                              const SizedBox(height: 10),
                              Divider(color: Colors.grey.shade200),
                              const SizedBox(height: 10),
                            ],
                            for (final p in t.sections[si])
                              Padding(
                                padding: EdgeInsets.only(
                                  left: (p.indent * 12).toDouble(),
                                  bottom: 6,
                                ),
                                child: SelectableText(
                                  p.text,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    height: 1.45,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
