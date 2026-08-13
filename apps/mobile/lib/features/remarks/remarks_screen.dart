import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../core/auth/auth_notifier.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/radius.dart';
import '../../shared/widgets/app_navigation_drawer.dart';
import '../bootstrap/bootstrap_notifier.dart';

class RemarksScreen extends ConsumerStatefulWidget {
  const RemarksScreen({super.key});

  @override
  ConsumerState<RemarksScreen> createState() => _RemarksScreenState();
}

class _RemarksScreenState extends ConsumerState<RemarksScreen> {
  List<dynamic> _remarks = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Metadata for filtering & adding
  List<dynamic> _classes = [];
  List<dynamic> _sections = [];
  List<dynamic> _students = [];

  String? _filterClassId;
  String? _filterSectionId;
  String? _filterStudentId;

  bool _isFacultyOrAdmin = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    final bootstrap = ref.read(bootstrapProvider);
    final user = bootstrap.config?.user;
    _currentUserId = user?.id;
    _isFacultyOrAdmin = user != null && user.role.toUpperCase() != 'STUDENT';

    _fetchRemarks();
    if (_isFacultyOrAdmin) {
      _fetchMetadata();
    }
  }

  Future<void> _fetchMetadata() async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final classesRes = await apiClient.dio.get('/api/classes');
      final studentsRes = await apiClient.dio.get('/api/students', queryParameters: {'limit': 100});

      if (classesRes.statusCode == 200) {
        setState(() => _classes = classesRes.data['data'] ?? []);
      }
      if (studentsRes.statusCode == 200) {
        setState(() => _students = studentsRes.data['data']['students'] ?? []);
      }
    } catch (_) {}
  }

  Future<void> _fetchSections(String classId) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final sectionsRes = await apiClient.dio.get('/api/sections', queryParameters: {'classId': classId});
      if (sectionsRes.statusCode == 200) {
        setState(() => _sections = sectionsRes.data['data'] ?? []);
      }
    } catch (_) {}
  }

  Future<void> _fetchRemarks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.dio.get('/api/remarks');

      if (response.statusCode == 200) {
        setState(() {
          _remarks = response.data['data'] ?? [];
        });
      }
    } catch (_) {
      setState(() => _errorMessage = 'Failed to load remarks history.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toUpperCase()) {
      case 'DISCIPLINE':
        return Colors.red;
      case 'BEHAVIOR':
        return Colors.orange;
      case 'ACHIEVEMENT':
        return Colors.green;
      case 'ACADEMIC':
        return Colors.blue;
      case 'GENERAL':
      default:
        return Colors.blueGrey;
    }
  }

  // Local filtering helper
  List<dynamic> _getFilteredRemarks() {
    if (!_isFacultyOrAdmin) return _remarks;

    return _remarks.filter((r) {
      final student = r['student'] ?? {};
      final enrollment = (student['enrollments'] as List?)?.firstOrNull ?? {};

      if (_filterStudentId != null && r['studentId'] != _filterStudentId) {
        return false;
      }
      if (_filterSectionId != null && enrollment['sectionId'] != _filterSectionId) {
        return false;
      }
      if (_filterClassId != null && enrollment['classId'] != _filterClassId) {
        return false;
      }
      return true;
    }).toList();
  }

  void _showAddOrEditRemarkDialog([dynamic existingRemark]) {
    final formKey = GlobalKey<FormState>();
    final contentController = TextEditingController(text: existingRemark?['content'] ?? '');
    String? selectedStudentId = existingRemark?['studentId'];
    String selectedCategory = existingRemark?['category'] ?? 'GENERAL';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Container(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Text(
                        existingRemark == null ? 'Add Student Remark' : 'Edit Student Remark',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      if (existingRemark == null)
                        DropdownButtonFormField<String>(
                          value: selectedStudentId,
                          decoration: const InputDecoration(labelText: 'Select Student *'),
                          validator: (v) => v == null ? 'Required' : null,
                          items: _students.map((s) {
                            return DropdownMenuItem(
                              value: s['id'] as String,
                              child: Text('${s['firstName'] ?? ''} ${s['lastName'] ?? ''}'),
                            );
                          }).toList(),
                          onChanged: (v) => setDialogState(() => selectedStudentId = v),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            'Student: ${existingRemark['student']?['firstName'] ?? ''} ${existingRemark['student']?['lastName'] ?? ''}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                      DropdownButtonFormField<String>(
                        value: selectedCategory,
                        decoration: const InputDecoration(labelText: 'Category *'),
                        items: const [
                          DropdownMenuItem(value: 'ACADEMIC', child: Text('Academic')),
                          DropdownMenuItem(value: 'BEHAVIOR', child: Text('Behavior')),
                          DropdownMenuItem(value: 'DISCIPLINE', child: Text('Discipline')),
                          DropdownMenuItem(value: 'ACHIEVEMENT', child: Text('Achievement')),
                          DropdownMenuItem(value: 'GENERAL', child: Text('General')),
                        ],
                        onChanged: (v) => setDialogState(() => selectedCategory = v!),
                      ),
                      TextFormField(
                        controller: contentController,
                        maxLines: 4,
                        decoration: const InputDecoration(labelText: 'Remark Details *'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () async {
                              if (formKey.currentState!.validate()) {
                                try {
                                  final apiClient = ref.read(apiClientProvider);
                                  Response response;
                                  if (existingRemark == null) {
                                    response = await apiClient.dio.post(
                                      '/api/remarks',
                                      data: {
                                        'studentId': selectedStudentId,
                                        'category': selectedCategory,
                                        'content': contentController.text.trim(),
                                      },
                                    );
                                  } else {
                                    response = await apiClient.dio.put(
                                      '/api/remarks/${existingRemark['id']}',
                                      data: {
                                        'category': selectedCategory,
                                        'content': contentController.text.trim(),
                                      },
                                    );
                                  }

                                  if (response.statusCode == 200 || response.statusCode == 201) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          existingRemark == null
                                              ? 'Remark added successfully!'
                                              : 'Remark updated successfully!',
                                        ),
                                      ),
                                    );
                                    _fetchRemarks();
                                  }
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed to save remark: $e')),
                                  );
                                }
                              }
                            },
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteRemark(String remarkId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Remark'),
        content: const Text('Are you sure you want to permanently remove this remark?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final apiClient = ref.read(apiClientProvider);
        final response = await apiClient.dio.delete('/api/remarks/$remarkId');
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Remark deleted successfully.')),
          );
          _fetchRemarks();
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete remark: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredRemarks = _getFilteredRemarks();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Remarks'),
      ),
      drawer: const AppNavigationDrawer(),
      floatingActionButton: _isFacultyOrAdmin
          ? FloatingActionButton(
              onPressed: () => _showAddOrEditRemarkDialog(),
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isFacultyOrAdmin) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _filterClassId,
                      decoration: const InputDecoration(labelText: 'Class', contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All Classes')),
                        ..._classes.map((c) => DropdownMenuItem(value: c['id'] as String, child: Text(c['name'] ?? ''))),
                      ],
                      onChanged: (v) {
                        setState(() {
                          _filterClassId = v;
                          _filterSectionId = null;
                          _sections = [];
                        });
                        if (v != null) {
                          _fetchSections(v);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _filterSectionId,
                      decoration: const InputDecoration(labelText: 'Section', contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All Sections')),
                        ..._sections.map((s) => DropdownMenuItem(value: s['id'] as String, child: Text(s['name'] ?? ''))),
                      ],
                      onChanged: (v) => setState(() => _filterSectionId = v),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: DropdownButtonFormField<String>(
                value: _filterStudentId,
                decoration: const InputDecoration(labelText: 'Filter by Student', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4)),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Students')),
                  ..._students.map((s) => DropdownMenuItem(
                        value: s['id'] as String,
                        child: Text('${s['firstName'] ?? ''} ${s['lastName'] ?? ''} (${s['admissionNumber'] ?? ''})'),
                      )),
                ],
                onChanged: (v) => setState(() => _filterStudentId = v),
              ),
            ),
            const Divider(height: 16),
          ],
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
                              onPressed: _fetchRemarks,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : filteredRemarks.isEmpty
                        ? const Center(child: Text('No remarks found matching criteria.'))
                        : RefreshIndicator(
                            onRefresh: _fetchRemarks,
                            child: ListView.builder(
                              padding: AppSpacing.paddingM,
                              itemCount: filteredRemarks.length,
                              itemBuilder: (context, index) {
                                final remark = filteredRemarks[index];
                                final category = remark['category'] ?? 'GENERAL';
                                final author = remark['author']?.toString() ?? 'Teacher';
                                final color = _getCategoryColor(category);
                                final studentName = remark['student'] != null
                                    ? '${remark['student']['firstName'] ?? ''} ${remark['student']['lastName'] ?? ''}'
                                    : 'Student';
                                final isAuthor = remark['teacherId'] == _currentUserId || remark['authorId'] == _currentUserId;

                                return Card(
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                                  ),
                                  child: Padding(
                                    padding: AppSpacing.paddingM,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: color.withOpacity(0.1),
                                                borderRadius: AppRadius.borderS,
                                              ),
                                              child: Text(
                                                category,
                                                style: TextStyle(
                                                  color: color,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                Text(
                                                  remark['createdAt']?.toString().split('T').first ?? '',
                                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                                ),
                                                if (isAuthor) ...[
                                                  const SizedBox(width: 8),
                                                  IconButton(
                                                    icon: const Icon(Icons.edit_outlined, size: 18),
                                                    onPressed: () => _showAddOrEditRemarkDialog(remark),
                                                    constraints: const BoxConstraints(),
                                                    padding: EdgeInsets.zero,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  IconButton(
                                                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                                    onPressed: () => _deleteRemark(remark['id']),
                                                    constraints: const BoxConstraints(),
                                                    padding: EdgeInsets.zero,
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                        AppSpacing.heightM,
                                        if (_isFacultyOrAdmin) ...[
                                          Text(
                                            'For: $studentName',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                          const SizedBox(height: 4),
                                        ],
                                        Text(
                                          remark['content'] ?? '',
                                          style: const TextStyle(fontSize: 15, height: 1.3),
                                        ),
                                        AppSpacing.heightM,
                                        Row(
                                          children: [
                                            const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                                            AppSpacing.widthXS,
                                            Text(
                                              'By: $author',
                                              style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
extension filterExtension<E> on Iterable<E> {
  Iterable<E> filter(bool Function(E element) test) => where(test);
}
