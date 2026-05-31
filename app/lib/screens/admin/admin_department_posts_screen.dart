import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter/material.dart";
import "package:mjc_in_one/screens/admin/admin_department_post_editor.dart";
import "package:mjc_in_one/screens/admin/admin_responsive.dart";
import "package:mjc_in_one/services/community_notice_service.dart";
import "package:mjc_in_one/services/department_slug_registry.dart";
import "package:mjc_in_one/services/departments_list_service.dart";
import "package:mjc_in_one/utils/mjc_snack_bar.dart";

/// 관리자 — 학과 공지 목록·작성.
class AdminDepartmentPostsScreen extends StatefulWidget {
  const AdminDepartmentPostsScreen({super.key});

  @override
  State<AdminDepartmentPostsScreen> createState() =>
      _AdminDepartmentPostsScreenState();
}

class _AdminDepartmentPostsScreenState extends State<AdminDepartmentPostsScreen> {
  final DepartmentsListService _departmentsService = DepartmentsListService();
  final DepartmentSlugRegistry _slugRegistry = DepartmentSlugRegistry();
  final CommunityNoticeService _communityService = CommunityNoticeService();

  List<String> _departments = const [];
  String? _selectedDepartment;
  String? _deptSlug;
  String _statusFilter = "all";
  bool _loadingDepartments = true;

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  Future<void> _loadDepartments() async {
    final List<String> departments =
        await _departmentsService.loadSortedDepartments();
    if (!mounted) return;
    setState(() {
      _departments = departments;
      _selectedDepartment =
          departments.isNotEmpty ? departments.first : null;
      _loadingDepartments = false;
    });
    await _resolveSlug();
  }

  Future<void> _resolveSlug() async {
    final String name = _selectedDepartment?.trim() ?? "";
    if (name.isEmpty) {
      setState(() => _deptSlug = null);
      return;
    }
    final String? slug = await _slugRegistry.slugForDisplayName(name);
    if (!mounted) return;
    setState(() => _deptSlug = slug);
  }

  Future<void> _openEditor({String? postId, Map<String, dynamic>? data}) async {
    final String? slug = _deptSlug;
    final String? name = _selectedDepartment;
    if (slug == null || name == null) return;
    final bool? ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AdminDepartmentPostEditor(
          deptSlug: slug,
          departmentName: name,
          existingPostId: postId,
          initialData: data,
        ),
      ),
    );
    if (ok == true && mounted) {
      showMjcSnackBar(context, message: "저장했습니다.");
    }
  }

  Future<void> _deletePost(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final String? slug = _deptSlug;
    if (slug == null) return;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("학과 공지 삭제"),
        content: const Text("이 글을 삭제합니다. 되돌릴 수 없습니다."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("취소"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("삭제"),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _communityService.deletePost(
      deptSlug: slug,
      postId: doc.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isMobile = adminIsMobile(context);
    final String? slug = _deptSlug;
    final double safeBottom = MediaQuery.paddingOf(context).bottom;

    final bool canWrite = slug != null && _selectedDepartment != null;

    return ColoredBox(
      color: scheme.surface,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Material(
                color: scheme.surface,
                elevation: 1,
                shadowColor: scheme.shadow.withValues(alpha: 0.08),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    isMobile ? 12 : 16,
                    12,
                    isMobile ? 12 : 16,
                    8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "학과 공지",
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        key: ValueKey<String>(
                          _selectedDepartment ?? "admin_dept_empty",
                        ),
                        initialValue: _selectedDepartment,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: "학과",
                          isDense: true,
                          filled: true,
                          fillColor: scheme.surface,
                          border: const OutlineInputBorder(),
                          helperText: _loadingDepartments ? "불러오는 중…" : null,
                        ),
                        items: [
                          for (final String d in _departments)
                            DropdownMenuItem<String>(value: d, child: Text(d)),
                        ],
                        onChanged: _loadingDepartments
                            ? null
                            : (String? value) async {
                                setState(() => _selectedDepartment = value);
                                await _resolveSlug();
                              },
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: "all", label: Text("전체")),
                            ButtonSegment(
                              value: "published",
                              label: Text("게시"),
                            ),
                            ButtonSegment(value: "hidden", label: Text("숨김")),
                          ],
                          selected: {_statusFilter},
                          onSelectionChanged: (s) =>
                              setState(() => _statusFilter = s.first),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ClipRect(
                  child: ColoredBox(
                    color: scheme.surface,
                    child: slug == null
                    ? const Center(child: Text("학과 slug를 찾을 수 없습니다."))
                    : StreamBuilder<
                        List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
                        stream: _communityService.streamAdminPosts(
                          slug,
                          statusFilter: _statusFilter,
                        ),
                        builder: (context, snap) {
                          if (snap.hasError) {
                            return Center(
                              child: Text(
                                "불러오기 실패: ${snap.error}",
                                style: TextStyle(color: scheme.error),
                              ),
                            );
                          }
                          if (!snap.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          final docs = snap.data!;
                          if (docs.isEmpty) {
                            return const Center(child: Text("글이 없습니다."));
                          }
                          return ListView.separated(
                            padding: EdgeInsets.fromLTRB(
                              isMobile ? 12 : 16,
                              4,
                              isMobile ? 12 : 16,
                              canWrite ? (safeBottom + 88) : (safeBottom + 24),
                            ),
                            itemCount: docs.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final doc = docs[i];
                              final data = doc.data();
                              final String status =
                                  (data["status"] as String?) ?? "published";
                              return ListTile(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(color: scheme.outlineVariant),
                                ),
                                title: Text(
                                  (data["title"] as String?) ?? "",
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  "${data["author"] ?? ""} · ${data["date"] ?? ""} · $status",
                                ),
                                isThreeLine: true,
                                onTap: () => _openEditor(
                                  postId: doc.id,
                                  data: data,
                                ),
                                trailing: IconButton(
                                  icon: Icon(
                                    Icons.delete_outline,
                                    color: scheme.error,
                                  ),
                                  onPressed: () => _deletePost(doc),
                                ),
                              );
                            },
                          );
                        },
                      ),
                  ),
                ),
              ),
            ],
          ),
          if (canWrite)
            Positioned(
              right: 16,
              bottom: safeBottom + 16,
              child: FloatingActionButton.extended(
                onPressed: () => _openEditor(),
                icon: const Icon(Icons.add),
                label: const Text("글 작성"),
              ),
            ),
        ],
      ),
    );
  }
}
