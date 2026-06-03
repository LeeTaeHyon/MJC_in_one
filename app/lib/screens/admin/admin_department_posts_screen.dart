import "dart:async";

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
  List<QueryDocumentSnapshot<Map<String, dynamic>>>? _cachedPosts;
  Object? _postsError;
  StreamSubscription<List<QueryDocumentSnapshot<Map<String, dynamic>>>>?
      _postsSub;
  String? _streamSlug;
  String? _streamStatusFilter;

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  @override
  void dispose() {
    _postsSub?.cancel();
    super.dispose();
  }

  void _bindPostsStream() {
    final String? slug = _deptSlug;
    if (slug == null) {
      _postsSub?.cancel();
      _postsSub = null;
      _streamSlug = null;
      _streamStatusFilter = null;
      return;
    }
    if (_postsSub != null &&
        _streamSlug == slug &&
        _streamStatusFilter == _statusFilter) {
      return;
    }
    _streamSlug = slug;
    _streamStatusFilter = _statusFilter;
    _postsSub?.cancel();
    _postsSub = _communityService
        .streamAdminPosts(slug, statusFilter: _statusFilter)
        .listen(
          (docs) {
            if (!mounted) return;
            setState(() {
              _cachedPosts = docs;
              _postsError = null;
            });
          },
          onError: (Object e) {
            if (!mounted) return;
            setState(() => _postsError = e);
          },
        );
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
      setState(() {
        _deptSlug = null;
        _cachedPosts = null;
        _postsError = null;
        _bindPostsStream();
      });
      return;
    }
    final String? slug = await _slugRegistry.slugForDisplayName(name);
    if (!mounted) return;
    setState(() {
      _deptSlug = slug;
      _cachedPosts = null;
      _postsError = null;
      _bindPostsStream();
    });
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

  Widget _buildListBody({
    required ColorScheme scheme,
    required bool isMobile,
    required bool canWrite,
    required double safeBottom,
  }) {
    if (_deptSlug == null) {
      return const Center(child: Text("학과 slug를 찾을 수 없습니다."));
    }
    if (_postsError != null) {
      return Center(
        child: Text(
          "불러오기 실패: $_postsError",
          style: TextStyle(color: scheme.error),
        ),
      );
    }
    if (_cachedPosts == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final docs = _cachedPosts!;
    if (docs.isEmpty) {
      return const Center(child: Text("글이 없습니다."));
    }
    return ListView.separated(
      key: const PageStorageKey<String>("admin_dept_posts_list"),
      padding: EdgeInsets.fromLTRB(
        isMobile ? 12 : 16,
        4,
        isMobile ? 12 : 16,
        canWrite ? (safeBottom + 88) : (safeBottom + 24),
      ),
      itemCount: docs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final doc = docs[i];
        return _DepartmentPostRow(
          doc: doc,
          onTap: () => _openEditor(postId: doc.id, data: doc.data()),
          onDelete: () => _deletePost(doc),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isMobile = adminIsMobile(context);
    final double safeBottom = MediaQuery.paddingOf(context).bottom;
    final bool canWrite = _deptSlug != null && _selectedDepartment != null;

    return Stack(
      fit: StackFit.expand,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                isMobile ? 12 : 16,
                12,
                isMobile ? 12 : 16,
                8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMobile)
                    Text(
                      "학과 공지",
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  if (!isMobile) const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    key: ValueKey<String>(
                      _selectedDepartment ?? "admin_dept_empty",
                    ),
                    initialValue: _selectedDepartment,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: "학과",
                      isDense: true,
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
                        ButtonSegment(value: "published", label: Text("게시")),
                        ButtonSegment(value: "hidden", label: Text("숨김")),
                      ],
                      selected: {_statusFilter},
                      onSelectionChanged: (s) {
                        final String next = s.first;
                        if (_statusFilter == next) return;
                        setState(() {
                          _statusFilter = next;
                          _cachedPosts = null;
                          _postsError = null;
                          _bindPostsStream();
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _buildListBody(
                scheme: scheme,
                isMobile: isMobile,
                canWrite: canWrite,
                safeBottom: safeBottom,
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
    );
  }
}

class _DepartmentPostRow extends StatelessWidget {
  const _DepartmentPostRow({
    required this.doc,
    required this.onTap,
    required this.onDelete,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isMobile = adminIsMobile(context);
    final data = doc.data();
    final String status = (data["status"] as String?) ?? "published";
    final String title = (data["title"] as String?) ?? "";
    final String author = (data["author"] as String?) ?? "";
    final String date = (data["date"] as String?) ?? "";

    final bool isHidden = status == "hidden";
    final Color statusColor =
        isHidden ? scheme.onSurfaceVariant : Colors.green;
    final String statusLabel = isHidden ? "숨김" : "게시";

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: EdgeInsets.all(isMobile ? 12 : 14),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (date.isNotEmpty)
                          Text(
                            date,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    icon: Icon(Icons.delete_outline, color: scheme.error),
                    onPressed: onDelete,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (author.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  author,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
