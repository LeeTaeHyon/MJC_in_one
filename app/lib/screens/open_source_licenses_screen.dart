import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:mio_notice/theme/app_colors.dart";
import "package:mio_notice/widgets/scroll_to_top_scope.dart";

/// 동일 라이선스 전문은 [LicenseRegistry]에서 여러 번 올 수 있어 본문 기준으로 묶습니다.
class _MergedLicense {
  _MergedLicense({required this.paragraphSource, required this.sortedNames});

  final LicenseEntry paragraphSource;
  final List<String> sortedNames;
}

List<_MergedLicense> _mergeDuplicateLicenseBodies(List<LicenseEntry> raw) {
  final byBody = <String, ({LicenseEntry source, Set<String> names})>{};
  for (final e in raw) {
    final key = e.paragraphs
        .map((p) => "${p.indent}\u{001F}${p.text}")
        .join("\u{001E}");
    final cur = byBody[key];
    if (cur == null) {
      byBody[key] = (source: e, names: {...e.packages});
    } else {
      cur.names.addAll(e.packages);
    }
  }
  final merged = byBody.values.map((v) {
    final names = v.names.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return _MergedLicense(paragraphSource: v.source, sortedNames: names);
  }).toList();
  merged.sort((a, b) {
    final an = a.sortedNames.isEmpty ? "" : a.sortedNames.first;
    final bn = b.sortedNames.isEmpty ? "" : b.sortedNames.first;
    return an.toLowerCase().compareTo(bn.toLowerCase());
  });
  return merged;
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
  late final Future<List<_MergedLicense>> _licensesFuture;
  final ScrollController _scrollController = ScrollController();
  ScrollToTopCoordinator? _scrollRouteCoordinator;
  bool _registeredScrollRoute = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onLicenseListScroll);
    _licensesFuture =
        LicenseRegistry.licenses.toList().then(_mergeDuplicateLicenseBodies);
  }

  void _onLicenseListScroll() {
    if (!mounted) return;
    final double viewportHeight = _scrollController.hasClients
        ? _scrollController.position.viewportDimension
        : MediaQuery.sizeOf(context).height;
    _scrollRouteCoordinator?.reportRouteScroll(
      _scrollController.offset,
      viewportHeight,
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
          _scrollController.position.viewportDimension,
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
      body: FutureBuilder<List<_MergedLicense>>(
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
          final merged = snapshot.data!;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted || !_scrollController.hasClients) return;
            _scrollRouteCoordinator?.reportRouteScroll(
              _scrollController.offset,
              _scrollController.position.viewportDimension,
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
              ...merged.map(
                (m) => ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                  collapsedShape: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                  shape: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                  title: Text(
                    _compactTitle(m.sortedNames),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: m.sortedNames.length > 1
                      ? Text(
                          m.sortedNames.length <= 6
                              ? "포함: ${m.sortedNames.join(", ")}"
                              : "포함: ${m.sortedNames.take(4).join(", ")} "
                                    "외 ${m.sortedNames.length - 4}개",
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
                          if (m.sortedNames.length > 6) ...[
                            SelectableText(
                              "적용 구성요소:\n${m.sortedNames.join(", ")}",
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          for (final p in m.paragraphSource.paragraphs)
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
