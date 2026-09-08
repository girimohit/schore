import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_notifier.dart';
import '../../features/bootstrap/bootstrap_notifier.dart';
import '../../core/theme/spacing.dart';
import '../../shared/widgets/app_navigation_drawer.dart';

class HomeworkScreen extends ConsumerStatefulWidget {
  const HomeworkScreen({super.key});

  @override
  ConsumerState<HomeworkScreen> createState() => _HomeworkScreenState();
}

class _HomeworkScreenState extends ConsumerState<HomeworkScreen> {
  List<dynamic> _assignments = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchHomework();
  }

  Future<void> _fetchHomework() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.dio.get('/api/homework');
      if (response.statusCode == 200) {
        setState(() {
          _assignments = response.data['data']['assignments'] ?? [];
        });
      }
    } catch (_) {
      setState(() => _errorMessage = 'Failed to load homework assignments.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteHomework(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Homework'),
        content: const Text('Are you sure you want to delete this homework assignment? This will also remove any student submissions.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final apiClient = ref.read(apiClientProvider);
      final res = await apiClient.dio.delete('/api/homework/$id');
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Homework deleted successfully'), backgroundColor: Colors.green),
        );
        _fetchHomework();
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete homework.')),
      );
    }
  }

  void _showCreateOrEditDialog({dynamic existingHw}) async {
    final apiClient = ref.read(apiClientProvider);
    List<dynamic> classes = [];
    List<dynamic> sections = [];
    List<dynamic> subjects = [];

    // Fetch classes and subjects for dropdown
    try {
      final classRes = await apiClient.dio.get('/api/classes');
      if (classRes.statusCode == 200) {
        classes = classRes.data['data'] ?? [];
      }
      final subjRes = await apiClient.dio.get('/api/subjects');
      if (subjRes.statusCode == 200) {
        subjects = subjRes.data['data'] ?? [];
      }
    } catch (_) {}

    if (!mounted) return;

    final isEditing = existingHw != null;
    final titleController = TextEditingController(text: existingHw?['title'] ?? '');
    final descController = TextEditingController(text: existingHw?['description'] ?? '');
    final attachmentController = TextEditingController(text: existingHw?['attachmentUrl'] ?? '');
    String? selectedClassId = existingHw?['classId'];
    String? selectedSectionId = existingHw?['sectionId'];
    String? selectedSubjectId = existingHw?['subjectId'];
    DateTime selectedDueDate = existingHw != null && existingHw['dueDate'] != null
        ? DateTime.tryParse(existingHw['dueDate']) ?? DateTime.now().add(const Duration(days: 3))
        : DateTime.now().add(const Duration(days: 3));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            void fetchSectionsForClass(String classId) async {
              try {
                final secRes = await apiClient.dio.get('/api/sections', queryParameters: {'classId': classId});
                if (secRes.statusCode == 200) {
                  setModalState(() {
                    sections = secRes.data['data'] ?? [];
                    if (!sections.any((s) => s['id'] == selectedSectionId)) {
                      selectedSectionId = sections.isNotEmpty ? sections.first['id'] : null;
                    }
                  });
                }
              } catch (_) {}
            }

            // Initial section load if editing or first class selected
            if (selectedClassId != null && sections.isEmpty) {
              fetchSectionsForClass(selectedClassId!);
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      isEditing ? 'Edit Homework' : 'Create Homework Assignment',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    AppSpacing.heightM,
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title *',
                        hintText: 'e.g. Chapter 4 Exercises',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    AppSpacing.heightM,
                    TextField(
                      controller: descController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Instructions / Description',
                        hintText: 'Detailed instructions for students...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (!isEditing) ...[
                      AppSpacing.heightM,
                      DropdownButtonFormField<String>(
                        value: selectedClassId,
                        decoration: const InputDecoration(
                          labelText: 'Class *',
                          border: OutlineInputBorder(),
                        ),
                        items: classes.map<DropdownMenuItem<String>>((c) {
                          return DropdownMenuItem<String>(
                            value: c['id'],
                            child: Text(c['name'] ?? 'Class'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setModalState(() {
                            selectedClassId = val;
                            selectedSectionId = null;
                            sections = [];
                          });
                          if (val != null) fetchSectionsForClass(val);
                        },
                      ),
                      AppSpacing.heightM,
                      DropdownButtonFormField<String>(
                        value: selectedSectionId,
                        decoration: const InputDecoration(
                          labelText: 'Section *',
                          border: OutlineInputBorder(),
                        ),
                        items: sections.map<DropdownMenuItem<String>>((s) {
                          return DropdownMenuItem<String>(
                            value: s['id'],
                            child: Text(s['name'] ?? 'Section'),
                          );
                        }).toList(),
                        onChanged: (val) => setModalState(() => selectedSectionId = val),
                      ),
                      AppSpacing.heightM,
                      DropdownButtonFormField<String>(
                        value: selectedSubjectId,
                        decoration: const InputDecoration(
                          labelText: 'Subject *',
                          border: OutlineInputBorder(),
                        ),
                        items: subjects.map<DropdownMenuItem<String>>((s) {
                          return DropdownMenuItem<String>(
                            value: s['id'],
                            child: Text('${s['name']} (${s['code'] ?? ''})'),
                          );
                        }).toList(),
                        onChanged: (val) => setModalState(() => selectedSubjectId = val),
                      ),
                    ],
                    AppSpacing.heightM,
                    ListTile(
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      title: const Text('Due Date'),
                      subtitle: Text(
                        '${selectedDueDate.year}-${selectedDueDate.month.toString().padLeft(2, '0')}-${selectedDueDate.day.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      trailing: const Icon(Icons.calendar_month),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: selectedDueDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 1)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setModalState(() => selectedDueDate = picked);
                        }
                      },
                    ),
                    AppSpacing.heightM,
                    TextField(
                      controller: attachmentController,
                      decoration: const InputDecoration(
                        labelText: 'Attachment URL (Optional)',
                        hintText: 'https://...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    AppSpacing.heightL,
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        if (titleController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Please enter a title')),
                          );
                          return;
                        }

                        if (!isEditing &&
                            (selectedClassId == null ||
                                selectedSectionId == null ||
                                selectedSubjectId == null)) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Please select class, section, and subject')),
                          );
                          return;
                        }

                        try {
                          if (isEditing) {
                            await apiClient.dio.put(
                              '/api/homework/${existingHw['id']}',
                              data: {
                                'title': titleController.text.trim(),
                                'description': descController.text.trim(),
                                'dueDate': selectedDueDate.toIso8601String(),
                                'attachmentUrl': attachmentController.text.trim().isEmpty
                                    ? null
                                    : attachmentController.text.trim(),
                              },
                            );
                          } else {
                            await apiClient.dio.post(
                              '/api/homework',
                              data: {
                                'classId': selectedClassId,
                                'sectionId': selectedSectionId,
                                'subjectId': selectedSubjectId,
                                'title': titleController.text.trim(),
                                'description': descController.text.trim(),
                                'dueDate': selectedDueDate.toIso8601String(),
                                'attachmentUrl': attachmentController.text.trim().isEmpty
                                    ? null
                                    : attachmentController.text.trim(),
                              },
                            );
                          }

                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isEditing ? 'Homework updated!' : 'Homework created successfully!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          _fetchHomework();
                        } catch (err: any) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text(err?.response?.data?['message'] ?? 'Failed to save homework')),
                          );
                        }
                      },
                      child: Text(isEditing ? 'Save Changes' : 'Create Assignment'),
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

  void _showHomeworkDetails(dynamic hw, String role) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final submissionTextController = TextEditingController();
        final subject = hw['subject'] ?? {};
        final className = hw['class']?['name'] ?? '';
        final sectionName = hw['section']?['name'] ?? '';

        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return StatefulBuilder(
              builder: (context, setSheetState) {
                return SingleChildScrollView(
                  controller: scrollController,
                  padding: AppSpacing.paddingL,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              hw['title'] ?? 'Homework Assignment',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                          if (role == 'FACULTY' || role == 'SCHOOL_ADMIN' || role == 'SUPER_ADMIN' || role == 'ADMIN') ...[
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                              onPressed: () {
                                Navigator.pop(context);
                                _showCreateOrEditDialog(existingHw: hw);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () {
                                Navigator.pop(context);
                                _deleteHomework(hw['id']);
                              },
                            ),
                          ],
                        ],
                      ),
                      AppSpacing.heightS,
                      Wrap(
                        spacing: 8,
                        children: [
                          Chip(
                            label: Text(subject['name'] ?? 'Subject'),
                            avatar: const Icon(Icons.book, size: 16),
                          ),
                          if (className.isNotEmpty)
                            Chip(
                              label: Text('$className - $sectionName'),
                              avatar: const Icon(Icons.class_outlined, size: 16),
                            ),
                        ],
                      ),
                      AppSpacing.heightS,
                      Text(
                        'Due Date: ${hw['dueDate']?.toString().split('T').first ?? ''}',
                        style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      AppSpacing.heightL,
                      const Text(
                        'Description',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      AppSpacing.heightS,
                      Text(hw['description'] ?? 'No description provided.'),
                      if (hw['attachmentUrl'] != null && hw['attachmentUrl'].toString().isNotEmpty) ...[
                        AppSpacing.heightM,
                        OutlinedButton.icon(
                          icon: const Icon(Icons.attach_file),
                          label: const Text('View Attachment'),
                          onPressed: () {},
                        ),
                      ],
                      AppSpacing.heightL,

                      // STUDENT SOLUTION UPLOAD
                      if (role == 'STUDENT') ...[
                        const Divider(),
                        AppSpacing.heightM,
                        const Text(
                          'Submit Assignment',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        AppSpacing.heightS,
                        TextField(
                          controller: submissionTextController,
                          decoration: const InputDecoration(
                            hintText: 'Enter your solution text or public link...',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                        AppSpacing.heightM,
                        ElevatedButton(
                          onPressed: () async {
                            if (submissionTextController.text.trim().isEmpty) return;
                            try {
                              final apiClient = ref.read(apiClientProvider);
                              await apiClient.dio.post(
                                '/api/homework/${hw['id']}/submissions',
                                data: {
                                  'contentUrl': submissionTextController.text.trim(),
                                },
                              );
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Homework submitted successfully!'), backgroundColor: Colors.green),
                              );
                            } catch (_) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Failed to upload submission.')),
                              );
                            }
                          },
                          child: const Text('Upload Submission'),
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bootstrap = ref.watch(bootstrapProvider);
    final user = bootstrap.config?.user;
    final role = user?.role.toUpperCase() ?? '';
    final canManage = role == 'FACULTY' || role == 'ADMIN' || role == 'SUPERADMIN' || role == 'SUPER_ADMIN' || role == 'SCHOOL_ADMIN';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Homework Assignments'),
      ),
      drawer: const AppNavigationDrawer(),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateOrEditDialog(),
              icon: const Icon(Icons.add),
              label: const Text('New Homework'),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!),
                      AppSpacing.heightM,
                      ElevatedButton(
                        onPressed: _fetchHomework,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _assignments.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade400),
                          AppSpacing.heightM,
                          const Text('No homework assignments found.'),
                          if (canManage) ...[
                            AppSpacing.heightS,
                            ElevatedButton(
                              onPressed: () => _showCreateOrEditDialog(),
                              child: const Text('Create First Assignment'),
                            ),
                          ],
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchHomework,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80, top: 8),
                        itemCount: _assignments.length,
                        itemBuilder: (context, index) {
                          final hw = _assignments[index];
                          final subject = hw['subject'] ?? {};
                          final className = hw['class']?['name'] ?? '';
                          final sectionName = hw['section']?['name'] ?? '';

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                child: const Icon(Icons.menu_book),
                              ),
                              title: Text(hw['title'] ?? 'Homework', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                '${subject['name'] ?? 'Subject'} ${className.isNotEmpty ? "($className-$sectionName)" : ""} • Due: ${hw['dueDate']?.toString().split('T').first ?? ''}',
                              ),
                              trailing: canManage
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 20),
                                          onPressed: () => _showCreateOrEditDialog(existingHw: hw),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                          onPressed: () => _deleteHomework(hw['id']),
                                        ),
                                      ],
                                    )
                                  : const Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: () => _showHomeworkDetails(hw, role),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
