import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../core/auth/auth_notifier.dart';
import '../../core/theme/spacing.dart';
import '../../shared/widgets/app_navigation_drawer.dart';
import '../bootstrap/bootstrap_notifier.dart';

class StudentsScreen extends ConsumerStatefulWidget {
  const StudentsScreen({super.key});

  @override
  ConsumerState<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends ConsumerState<StudentsScreen> {
  final _searchController = TextEditingController();
  List<dynamic> _students = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Metadata for forms
  List<dynamic> _academicYears = [];
  List<dynamic> _classes = [];
  List<dynamic> _sections = [];
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    final bootstrap = ref.read(bootstrapProvider);
    final user = bootstrap.config?.user;
    _isAdmin = user != null &&
        (user.role.toUpperCase() == 'SCHOOL_ADMIN' ||
            user.role.toUpperCase() == 'ADMIN' ||
            user.role.toUpperCase() == 'SUPERADMIN');

    _fetchStudents();
    if (_isAdmin) {
      _fetchMetadata();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchMetadata() async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final yearsRes = await apiClient.dio.get('/api/academic-years');
      final classesRes = await apiClient.dio.get('/api/classes');
      if (yearsRes.statusCode == 200 && yearsRes.data['success'] == true) {
        setState(() => _academicYears = yearsRes.data['data'] ?? []);
      }
      if (classesRes.statusCode == 200 && classesRes.data['success'] == true) {
        setState(() => _classes = classesRes.data['data'] ?? []);
      }
    } catch (_) {}
  }

  Future<void> _fetchSections(String classId) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final sectionsRes = await apiClient.dio.get(
        '/api/sections',
        queryParameters: {'classId': classId},
      );
      if (sectionsRes.statusCode == 200 && sectionsRes.data['success'] == true) {
        setState(() => _sections = sectionsRes.data['data'] ?? []);
      }
    } catch (_) {}
  }

  Future<void> _fetchStudents({String search = ''}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.dio.get(
        '/api/students',
        queryParameters: {
          if (search.isNotEmpty) 'search': search,
          'limit': 50,
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _students = response.data['data']['students'] ?? [];
        });
      } else {
        setState(() {
          _errorMessage = response.data['message'] ?? 'Failed to load students';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading student records';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showStudentProfile(dynamic student) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final enrollment = (student['enrollments'] as List?)?.firstOrNull ?? {};
        final activeClass = enrollment['class'] ?? {};
        final section = enrollment['section'] ?? {};

        final firstName = student['firstName'] ?? '';
        final lastName = student['lastName'] ?? '';
        final email = student['email'] ?? 'N/A';
        final phone = student['phone'] ?? 'N/A';
        final dob = student['dateOfBirth']?.toString().split('T').first ?? 'N/A';
        final parentName = student['parentName'] ?? 'N/A';
        final parentPhone = student['parentPhone'] ?? 'N/A';

        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            final theme = Theme.of(context);
            return Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                padding: AppSpacing.paddingL,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    AppSpacing.heightL,
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: theme.colorScheme.surface,
                          child: Text(
                            '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    AppSpacing.heightM,
                    Text(
                      '$firstName $lastName',
                      style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      'Admission No: ${student['admissionNumber'] ?? ''}',
                      style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                    AppSpacing.heightL,
                    
                    // Academic Information Card
                    Text('Academic Info', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    AppSpacing.heightS,
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: theme.colorScheme.outlineVariant),
                      ),
                      child: Padding(
                        padding: AppSpacing.paddingM,
                        child: Column(
                          children: [
                            _buildProfileRow(Icons.school_outlined, 'Class', activeClass['name'] ?? 'N/A'),
                            const Divider(height: 20),
                            _buildProfileRow(Icons.grid_view_outlined, 'Section', section['name'] ?? 'N/A'),
                          ],
                        ),
                      ),
                    ),
                    AppSpacing.heightM,

                    // Personal Details Card
                    Text('Personal & Contact Info', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    AppSpacing.heightS,
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: theme.colorScheme.outlineVariant),
                      ),
                      child: Padding(
                        padding: AppSpacing.paddingM,
                        child: Column(
                          children: [
                            _buildProfileRow(Icons.email_outlined, 'Email', email),
                            const Divider(height: 20),
                            _buildProfileRow(Icons.phone_outlined, 'Phone', phone),
                            const Divider(height: 20),
                            _buildProfileRow(Icons.cake_outlined, 'Date of Birth', dob),
                          ],
                        ),
                      ),
                    ),
                    AppSpacing.heightM,

                    // Parent / Guardian Card
                    Text('Parent / Guardian Details', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    AppSpacing.heightS,
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: theme.colorScheme.outlineVariant),
                      ),
                      child: Padding(
                        padding: AppSpacing.paddingM,
                        child: Column(
                          children: [
                            _buildProfileRow(Icons.family_restroom_outlined, 'Parent Name', parentName),
                            const Divider(height: 20),
                            _buildProfileRow(Icons.phone_android_outlined, 'Parent Phone', parentPhone),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProfileRow(IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 22),
          AppSpacing.widthM,
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface.withOpacity(0.6)),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _showAddStudentDialog() {
    final formKey = GlobalKey<FormState>();
    final admnNoController = TextEditingController();
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    
    String? selectedYearId;
    String? selectedClassId;
    String? selectedSectionId;
    String selectedGender = 'MALE';
    DateTime? selectedDob;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Student Profile'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: admnNoController,
                        decoration: const InputDecoration(labelText: 'Admission Number *'),
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      TextFormField(
                        controller: firstNameController,
                        decoration: const InputDecoration(labelText: 'First Name *'),
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      TextFormField(
                        controller: lastNameController,
                        decoration: const InputDecoration(labelText: 'Last Name'),
                      ),
                      TextFormField(
                        controller: emailController,
                        decoration: const InputDecoration(labelText: 'Email Address'),
                      ),
                      TextFormField(
                        controller: phoneController,
                        decoration: const InputDecoration(labelText: 'Phone Number'),
                      ),
                      DropdownButtonFormField<String>(
                        value: selectedGender,
                        decoration: const InputDecoration(labelText: 'Gender'),
                        items: const [
                          DropdownMenuItem(value: 'MALE', child: Text('Male')),
                          DropdownMenuItem(value: 'FEMALE', child: Text('Female')),
                          DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                        ],
                        onChanged: (v) => setDialogState(() => selectedGender = v!),
                      ),
                      ListTile(
                        title: Text(
                          selectedDob == null
                              ? 'Select Date of Birth *'
                              : 'DOB: ${selectedDob!.toLocal().toString().split(' ').first}',
                        ),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime(2010),
                            firstDate: DateTime(1990),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setDialogState(() => selectedDob = date);
                          }
                        },
                      ),
                      DropdownButtonFormField<String>(
                        value: selectedYearId,
                        decoration: const InputDecoration(labelText: 'Academic Year *'),
                        validator: (v) => v == null ? 'Required' : null,
                        items: _academicYears.map((y) {
                          return DropdownMenuItem(value: y['id'] as String, child: Text(y['name'] ?? ''));
                        }).toList(),
                        onChanged: (v) => setDialogState(() => selectedYearId = v),
                      ),
                      DropdownButtonFormField<String>(
                        value: selectedClassId,
                        decoration: const InputDecoration(labelText: 'Class *'),
                        validator: (v) => v == null ? 'Required' : null,
                        items: _classes.map((c) {
                          return DropdownMenuItem(value: c['id'] as String, child: Text(c['name'] ?? ''));
                        }).toList(),
                        onChanged: (v) async {
                          setDialogState(() {
                            selectedClassId = v;
                            selectedSectionId = null;
                            _sections = [];
                          });
                          if (v != null) {
                            await _fetchSections(v);
                            setDialogState(() {});
                          }
                        },
                      ),
                      DropdownButtonFormField<String>(
                        value: selectedSectionId,
                        decoration: const InputDecoration(labelText: 'Section *'),
                        validator: (v) => v == null ? 'Required' : null,
                        items: _sections.map((s) {
                          return DropdownMenuItem(value: s['id'] as String, child: Text(s['name'] ?? ''));
                        }).toList(),
                        onChanged: (v) => setDialogState(() => selectedSectionId = v),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate() && selectedDob != null) {
                      try {
                        final apiClient = ref.read(apiClientProvider);
                        final response = await apiClient.dio.post(
                          '/api/students',
                          data: {
                            'admissionNumber': admnNoController.text.trim(),
                            'firstName': firstNameController.text.trim(),
                            'lastName': lastNameController.text.trim(),
                            'email': emailController.text.trim(),
                            'phone': phoneController.text.trim(),
                            'gender': selectedGender,
                            'dateOfBirth': selectedDob!.toIso8601String(),
                            'academicYearId': selectedYearId,
                            'classId': selectedClassId,
                            'sectionId': selectedSectionId,
                          },
                        );

                        if (response.statusCode == 201 || response.data['success'] == true) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Student profile created successfully!')),
                          );
                          _fetchStudents();
                        }
                      } catch (err) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to save student: ${err.toString()}')),
                        );
                      }
                    } else if (selectedDob == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please pick a date of birth')),
                      );
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showBulkImportDialog() {
    final csvController = TextEditingController(
      text: "firstname,lastname,email,phone,admissionnumber,gender,dateofbirth,classid,sectionid,academicyearid\n"
          "John,Doe,john.doe@example.com,+919999999999,ADM001,MALE,2012-05-10,${_classes.firstOrNull?['id'] ?? ''},${_sections.firstOrNull?['id'] ?? ''},${_academicYears.firstOrNull?['id'] ?? ''}",
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Bulk Import Students'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Paste CSV records directly below (including headers):',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    AppSpacing.heightS,
                    TextField(
                      controller: csvController,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'firstname,lastname,email...',
                      ),
                      enabled: !isSaving,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final text = csvController.text.trim();
                          if (text.isEmpty) return;

                          setDialogState(() => isSaving = true);
                          try {
                            final apiClient = ref.read(apiClientProvider);
                            final formData = FormData.fromMap({
                              'file': MultipartFile.fromString(
                                text,
                                filename: 'students.csv',
                              ),
                            });

                            final response = await apiClient.dio.post(
                              '/api/school/import/students',
                              data: formData,
                            );

                            if (response.statusCode == 200 ||
                                response.data['success'] == true) {
                              Navigator.pop(context);
                              final results = response.data['data'] ?? {};
                              final successes = results['successCount'] ?? 0;
                              final failures = results['failureCount'] ?? 0;

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Import complete. Success: $successes, Failures: $failures',
                                  ),
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                              _fetchStudents();
                            }
                          } catch (err) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Import failed: ${err.toString()}')),
                            );
                          } finally {
                            setDialogState(() => isSaving = false);
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Import CSV'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Students Directory'),
        actions: [
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.upload_file),
              tooltip: 'Bulk Import CSV',
              onPressed: _showBulkImportDialog,
            ),
        ],
      ),
      drawer: const AppNavigationDrawer(),
      floatingActionButton: _isAdmin
          ? FloatingActionButton(
              onPressed: _showAddStudentDialog,
              tooltip: 'Add Student',
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: AppSpacing.paddingM,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or admission no...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _fetchStudents();
                  },
                ),
              ),
              onSubmitted: (value) => _fetchStudents(search: value.trim()),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_errorMessage!),
                            AppSpacing.heightM,
                            ElevatedButton(
                              onPressed: () => _fetchStudents(search: _searchController.text),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _students.isEmpty
                        ? const Center(child: Text('No students found.'))
                        : ListView.builder(
                            itemCount: _students.length,
                            itemBuilder: (context, index) {
                              final student = _students[index];
                              final enrollment =
                                  (student['enrollments'] as List?)?.firstOrNull ??
                                      {};
                              final activeClass = enrollment['class'] ?? {};
                              final section = enrollment['section'] ?? {};

                              final firstName = student['firstName'] ?? '';
                              final lastName = student['lastName'] ?? '';

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    child: Text(
                                      '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}',
                                    ),
                                  ),
                                  title: Text(
                                    '$firstName $lastName',
                                  ),
                                  subtitle: Text(
                                    'Class: ${activeClass['name'] ?? ''} - ${section['name'] ?? ''}',
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => _showStudentProfile(student),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
