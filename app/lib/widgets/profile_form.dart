import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:mjc_in_one/mpu_profile_prefs.dart";
import "package:mjc_in_one/services/departments_list_service.dart";
import "package:mjc_in_one/services/user_data_repository.dart";

class ProfileForm extends StatefulWidget {
  const ProfileForm({
    super.key,
    required this.initialProfile,
    this.submitLabel = "저장",
    this.onSaved,
  });

  final MpuProfile initialProfile;
  final String submitLabel;
  final Future<void> Function(MpuProfile profile)? onSaved;

  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<ProfileForm> {
  final DepartmentsListService _departmentsService = DepartmentsListService();

  static const String _customDepartmentValue = "__custom_department__";
  static const List<String> _gradeOptions = [
    "1학년",
    "2학년",
    "3학년",
    "전공심화",
    "졸업",
  ];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _departmentController;
  late final TextEditingController _studentIdController;
  List<String> _departments = const [];
  String? _selectedDepartment;
  String? _selectedGrade;
  bool _loadingDepartments = true;
  bool _saving = false;

  bool get _isCustomDepartment => _selectedDepartment == _customDepartmentValue;

  @override
  void initState() {
    super.initState();
    final MpuProfile profile = widget.initialProfile;
    _nameController = TextEditingController(text: profile.name);
    _departmentController = TextEditingController(text: profile.department);
    _studentIdController = TextEditingController(text: profile.studentId);
    _selectedGrade =
        _gradeOptions.contains(profile.grade) ? profile.grade : null;
    _loadDepartments();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _departmentController.dispose();
    _studentIdController.dispose();
    super.dispose();
  }

  Future<void> _loadDepartments() async {
    try {
      final List<String> departments =
          await _departmentsService.loadSortedDepartments();
      if (departments.isNotEmpty) {
        _applyDepartments(departments);
        return;
      }
    } catch (_) {
      // Fall through.
    }
    if (!mounted) return;
    setState(() {
      _selectedDepartment = widget.initialProfile.department.trim().isEmpty
          ? null
          : _customDepartmentValue;
      _loadingDepartments = false;
    });
  }

  void _applyDepartments(List<String> departments) {
    final List<String> sorted = [...departments]..sort();
    if (!mounted) return;
    setState(() {
      _departments = sorted;
      _selectedDepartment = sorted.contains(widget.initialProfile.department)
          ? widget.initialProfile.department
          : (widget.initialProfile.department.trim().isEmpty
              ? null
              : _customDepartmentValue);
      _loadingDepartments = false;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);

    final String department = _isCustomDepartment
        ? _departmentController.text.trim()
        : (_selectedDepartment ?? "").trim();
    final MpuProfile profile = MpuProfile(
      name: _nameController.text.trim(),
      department: department,
      grade: (_selectedGrade ?? "").trim(),
      studentId: _studentIdController.text.trim(),
      mileage: widget.initialProfile.mileage.trim(),
    );

    try {
      await saveMpuProfile(profile);
      await UserDataRepository.instance.pushSnapshotToCloud();
      await widget.onSaved?.call(profile);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _nameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: "이름",
              hintText: "홍길동",
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey<String>(_selectedDepartment ?? "department_empty"),
            initialValue: _selectedDepartment,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: "학과",
              prefixIcon: const Icon(Icons.school_outlined),
              helperText: _loadingDepartments ? "학과 목록을 불러오는 중입니다." : null,
            ),
            items: [
              for (final String department in _departments)
                DropdownMenuItem<String>(
                  value: department,
                  child: Text(department),
                ),
              const DropdownMenuItem<String>(
                value: _customDepartmentValue,
                child: Text("직접 입력"),
              ),
            ],
            onChanged: _loadingDepartments
                ? null
                : (String? value) {
                    setState(() => _selectedDepartment = value);
                  },
          ),
          if (_isCustomDepartment) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _departmentController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: "학과 직접 입력",
                hintText: "학과명을 입력하세요",
                prefixIcon: Icon(Icons.edit_outlined),
              ),
            ),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey<String>(_selectedGrade ?? "grade_empty"),
            initialValue: _selectedGrade,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: "학년",
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            items: [
              for (final String grade in _gradeOptions)
                DropdownMenuItem<String>(
                  value: grade,
                  child: Text(grade),
                ),
            ],
            onChanged: (String? value) {
              setState(() => _selectedGrade = value);
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _studentIdController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: "학번",
              hintText: "학번을 입력하세요",
              prefixIcon: Icon(Icons.numbers_rounded),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: scheme.primary,
            ),
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    widget.submitLabel,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
          ),
        ],
      ),
    );
  }
}
