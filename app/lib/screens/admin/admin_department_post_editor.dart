import "package:file_picker/file_picker.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";
import "package:mjc_in_one/models/community_notice_media.dart";
import "package:mjc_in_one/screens/admin/admin_auth_service.dart";
import "package:mjc_in_one/screens/admin/admin_save_error_message.dart";
import "package:mjc_in_one/services/community_notice_file_policy.dart";
import "package:mjc_in_one/services/community_notice_service.dart";
import "package:mjc_in_one/utils/community_image_compressor.dart";
import "package:mjc_in_one/utils/snack_bar_utils.dart";
import "package:mjc_in_one/widgets/community_notice_image.dart";

/// 학과 공지 작성·수정.
class AdminDepartmentPostEditor extends StatefulWidget {
  const AdminDepartmentPostEditor({
    super.key,
    required this.deptSlug,
    required this.departmentName,
    this.existingPostId,
    this.initialData,
  });

  final String deptSlug;
  final String departmentName;
  final String? existingPostId;
  final Map<String, dynamic>? initialData;

  bool get isEditing => existingPostId != null;

  @override
  State<AdminDepartmentPostEditor> createState() =>
      _AdminDepartmentPostEditorState();
}

class _AdminDepartmentPostEditorState extends State<AdminDepartmentPostEditor> {
  final CommunityNoticeService _service = CommunityNoticeService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleCtrl;
  late final TextEditingController _authorCtrl;
  late final TextEditingController _bodyCtrl;
  late final TextEditingController _sourceNoteCtrl;
  late String _date;
  late String _status;

  List<CommunityNoticeMediaItem> _existingImages = [];
  final List<PlatformFile> _newImages = [];
  List<CommunityNoticeMediaItem> _existingAttachments = [];
  final List<PlatformFile> _newAttachments = [];
  bool _saving = false;

  int get _totalImages => _existingImages.length + _newImages.length;
  int get _totalAttachments =>
      _existingAttachments.length + _newAttachments.length;

  @override
  void initState() {
    super.initState();
    final Map<String, dynamic> data = widget.initialData ?? {};
    _titleCtrl = TextEditingController(text: (data["title"] as String?) ?? "");
    _authorCtrl = TextEditingController(text: _defaultAuthor(data));
    _bodyCtrl = TextEditingController(text: (data["body"] as String?) ?? "");
    _sourceNoteCtrl =
        TextEditingController(text: (data["source_note"] as String?) ?? "");
    _date = (data["date"] as String?) ?? _todayString();
    _status = (data["status"] as String?) ?? "published";
    _existingImages =
        List<CommunityNoticeMediaItem>.from(
          CommunityNoticePostMedia.imagesFromPost(data),
        );
    _existingAttachments =
        List<CommunityNoticeMediaItem>.from(
          CommunityNoticePostMedia.attachmentsFromPost(data),
        );
  }

  String _defaultAuthor(Map<String, dynamic> data) {
    final String fromData = (data["author"] as String?) ?? "";
    if (fromData.isNotEmpty) return fromData;
    final String? email = AdminAuthService.instance.currentUser?.email;
    if (email == null || !email.contains("@")) return "";
    return email.split("@").first;
  }

  String _todayString() {
    final DateTime now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, "0");
    return "${now.year}-${two(now.month)}-${two(now.day)}";
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _authorCtrl.dispose();
    _bodyCtrl.dispose();
    _sourceNoteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (_totalImages >= CommunityNoticeFilePolicy.maxImages) {
      _showSnack("사진은 최대 ${CommunityNoticeFilePolicy.maxImages}장입니다.");
      return;
    }
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    final List<PlatformFile> accepted = <PlatformFile>[];
    for (final PlatformFile file in result.files) {
      if (_totalImages + accepted.length >= CommunityNoticeFilePolicy.maxImages) {
        break;
      }
      final String? err = CommunityNoticeFilePolicy.validateImagePick(file);
      if (err != null) {
        _showSnack(err);
        continue;
      }
      accepted.add(file);
    }
    if (accepted.isEmpty) return;
    setState(() => _newImages.addAll(accepted));
  }

  Future<void> _pickAttachments() async {
    if (_totalAttachments >= CommunityNoticeFilePolicy.maxAttachments) {
      _showSnack(
        "첨부는 최대 ${CommunityNoticeFilePolicy.maxAttachments}개입니다.",
      );
      return;
    }
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: CommunityNoticeFilePolicy.attachmentExtensions,
      withData: true,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    final List<PlatformFile> accepted = <PlatformFile>[];
    for (final PlatformFile file in result.files) {
      if (_totalAttachments + accepted.length >=
          CommunityNoticeFilePolicy.maxAttachments) {
        break;
      }
      final String? err = CommunityNoticeFilePolicy.validateAttachmentPick(file);
      if (err != null) {
        _showSnack(err);
        continue;
      }
      accepted.add(file);
    }
    if (accepted.isEmpty) return;
    setState(() => _newAttachments.addAll(accepted));
  }

  void _showSnack(String message) {
    SnackBarUtils.showUnique(
      context,
      key: "admin_dept_editor_hint",
      snackBar: SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 8),
        content: Text(message),
      ),
    );
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final User? user = AdminAuthService.instance.currentUser;
    if (user == null) return;

    setState(() => _saving = true);
    try {
      final String postId = widget.existingPostId ??
          await _service.createPostId(widget.deptSlug);

      final Map<String, dynamic> initial = widget.initialData ?? {};
      final List<String> pathsToDelete = <String>[];

      final Set<String> keepImagePaths =
          _existingImages.map((e) => e.storagePath).toSet();
      for (final CommunityNoticeMediaItem old
          in CommunityNoticePostMedia.imagesFromPost(initial)) {
        if (old.storagePath.isNotEmpty &&
            !keepImagePaths.contains(old.storagePath)) {
          pathsToDelete.add(old.storagePath);
        }
      }

      final Set<String> keepAttachmentPaths =
          _existingAttachments.map((e) => e.storagePath).toSet();
      for (final CommunityNoticeMediaItem old
          in CommunityNoticePostMedia.attachmentsFromPost(initial)) {
        if (old.storagePath.isNotEmpty &&
            !keepAttachmentPaths.contains(old.storagePath)) {
          pathsToDelete.add(old.storagePath);
        }
      }

      await _service.deleteStoragePaths(pathsToDelete);

      final List<CommunityNoticeMediaItem> finalImages =
          List<CommunityNoticeMediaItem>.from(_existingImages);
      for (int i = 0; i < _newImages.length; i++) {
        final int index = finalImages.length;
        finalImages.add(
          await _service.uploadImageAtIndex(
            deptSlug: widget.deptSlug,
            postId: postId,
            index: index,
            file: _newImages[i],
          ),
        );
      }

      final List<CommunityNoticeMediaItem> finalAttachments =
          List<CommunityNoticeMediaItem>.from(_existingAttachments);
      for (final PlatformFile file in _newAttachments) {
        finalAttachments.add(
          await _service.uploadAttachment(
            deptSlug: widget.deptSlug,
            postId: postId,
            file: file,
          ),
        );
      }

      await _service.savePost(
        deptSlug: widget.deptSlug,
        postId: postId,
        departmentName: widget.departmentName,
        title: _titleCtrl.text,
        author: _authorCtrl.text,
        body: _bodyCtrl.text,
        date: _date,
        status: _status,
        createdByUid: user.uid,
        sourceNote: _sourceNoteCtrl.text,
        images: finalImages,
        attachments: finalAttachments,
        isNew: !widget.isEditing,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showSnack(
        adminSaveErrorMessage(e, uid: user.uid),
      );
    } on CommunityImageCompressException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showSnack(e.message);
    } on CommunityNoticeException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showSnack(e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showSnack("저장 실패: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? "학과 공지 수정" : "학과 공지 작성"),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              widget.departmentName,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: "제목",
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v ?? "").trim().isEmpty ? "제목을 입력해 주세요." : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _authorCtrl,
              decoration: const InputDecoration(
                labelText: "작성자",
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v ?? "").trim().isEmpty ? "작성자를 입력해 주세요." : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bodyCtrl,
              minLines: 5,
              maxLines: 12,
              decoration: const InputDecoration(
                labelText: "본문",
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: (v) =>
                  (v ?? "").trim().isEmpty ? "본문을 입력해 주세요." : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _sourceNoteCtrl,
              decoration: const InputDecoration(
                labelText: "출처 메모 (선택)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("게시일"),
              subtitle: Text(_date),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () async {
                final DateTime initial =
                    DateTime.tryParse(_date) ?? DateTime.now();
                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: initial,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked == null) return;
                String two(int n) => n.toString().padLeft(2, "0");
                setState(() {
                  _date =
                      "${picked.year}-${two(picked.month)}-${two(picked.day)}";
                });
              },
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: "published", label: Text("게시")),
                ButtonSegment(value: "hidden", label: Text("숨김")),
              ],
              selected: {_status},
              onSelectionChanged: (s) =>
                  setState(() => _status = s.isEmpty ? "published" : s.first),
            ),
            const SizedBox(height: 16),
            _buildImagesCard(theme),
            const SizedBox(height: 12),
            _buildAttachmentsCard(theme),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.isEditing ? "저장" : "등록"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagesCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "사진 (선택, 최대 ${CommunityNoticeFilePolicy.maxImages}장)",
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              "JPG·PNG만 등록됩니다. "
              "업로드 전 자동 압축 (긴 변 최대 ${CommunityImageCompressor.maxLongEdge}px, "
              "목표 ${CommunityImageCompressor.targetMaxBytes ~/ 1024}KB 이하).",
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            ..._existingImages.asMap().entries.map(
              (e) => _existingImageRow(theme, e.key, e.value),
            ),
            ..._newImages.asMap().entries.map(
              (e) => _newImageRow(theme, e.key, e.value),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _saving || _totalImages >= CommunityNoticeFilePolicy.maxImages
                  ? null
                  : _pickImages,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text("사진 추가 ($_totalImages/${CommunityNoticeFilePolicy.maxImages})"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _existingImageRow(
    ThemeData theme,
    int index,
    CommunityNoticeMediaItem item,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: CommunityNoticeImage(
              imageUrl: item.url,
              imageStoragePath: item.storagePath,
              height: 80,
              fit: BoxFit.contain,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          IconButton(
            tooltip: "삭제",
            onPressed: _saving
                ? null
                : () => setState(() => _existingImages.removeAt(index)),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _newImageRow(ThemeData theme, int index, PlatformFile file) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              "새 사진: ${file.name}",
              style: theme.textTheme.bodySmall,
            ),
          ),
          IconButton(
            tooltip: "삭제",
            onPressed: _saving
                ? null
                : () => setState(() => _newImages.removeAt(index)),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentsCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "첨부파일 (선택, 최대 ${CommunityNoticeFilePolicy.maxAttachments}개)",
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              CommunityNoticeFilePolicy.attachmentPickerHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            ..._existingAttachments.asMap().entries.map(
              (e) => _fileRow(
                theme,
                e.value.name,
                onRemove: _saving
                    ? null
                    : () => setState(() => _existingAttachments.removeAt(e.key)),
              ),
            ),
            ..._newAttachments.asMap().entries.map(
              (e) => _fileRow(
                theme,
                e.value.name,
                onRemove: _saving
                    ? null
                    : () => setState(() => _newAttachments.removeAt(e.key)),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _saving ||
                      _totalAttachments >= CommunityNoticeFilePolicy.maxAttachments
                  ? null
                  : _pickAttachments,
              icon: const Icon(Icons.attach_file_outlined),
              label: Text(
                "첨부 추가 ($_totalAttachments/${CommunityNoticeFilePolicy.maxAttachments})",
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fileRow(
    ThemeData theme,
    String name, {
    VoidCallback? onRemove,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(Icons.insert_drive_file_outlined,
              size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
          IconButton(
            tooltip: "삭제",
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 20),
          ),
        ],
      ),
    );
  }
}
