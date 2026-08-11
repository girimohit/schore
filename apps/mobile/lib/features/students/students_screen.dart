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
      builder: (context) {
        final profile = student['profile'] ?? {};
        final enrollment = (student['enrollments'] as List?)?.firstOrNull ?? {};
        final activeClass = enrollment['class'] ?? {};
        final section = enrollment['section'] ?? {};

        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: AppSpacing.paddingL,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor:
                          Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      child: Text(
                        '${profile['firstName']?[0] ?? ''}${profile['lastName']?[0] ?? ''}',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  AppSpacing.heightM,
                  Text(
                    '${profile['firstName'] ?? ''} ${profile['lastName'] ?? ''}',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    'Admission No: ${student['admissionNumber'] ?? ''}',
                    style: const TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  AppSpacing.heightL,
                  const Divider(),
                  _buildProfileRow('Class', activeClass['name'] ?? 'N/A'),
                  _buildProfileRow('Section', section['name'] ?? 'N/A'),
                  _buildProfileRow('Email', profile['email'] ?? 'N/A'),
                  _buildProfileRow('Phone', profile['phone'] ?? 'N/A'),
                  _buildProfileRow(
                    'Date of Birth',
                    profile['dob']?.toString().split('T').first ?? 'N/A',
                  ),
                  _buildProfileRow('Parent Name', student['parentName'] ?? 'N/A'),
                  _buildProfileRow('Parent Phone', student['parentPhone'] ?? 'N/A'),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProfileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
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
                              final profile = student['profile'] ?? {};
                              final enrollment =
                                  (student['enrollments'] as List?)?.firstOrNull ??
                                      {};
                              final activeClass = enrollment['class'] ?? {};
                              final section = enrollment['section'] ?? {};

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    child: Text(
                                      '${profile['firstName']?[0] ?? ''}${profile['lastName']?[0] ?? ''}',
                                    ),
                                  ),
                                  title: Text(
                                    '${profile['firstName'] ?? ''} ${profile['lastName'] ?? ''}',
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
