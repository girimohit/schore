import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../core/auth/auth_notifier.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/radius.dart';
import '../../shared/widgets/app_navigation_drawer.dart';
import '../bootstrap/bootstrap_notifier.dart';

class NoticesScreen extends ConsumerStatefulWidget {
  const NoticesScreen({super.key});

  @override
  ConsumerState<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends ConsumerState<NoticesScreen> {
  List<dynamic> _notices = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Metadata for class-targeted notices
  List<dynamic> _classes = [];
  List<dynamic> _sections = [];

  bool _isFacultyOrAdmin = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    final bootstrap = ref.read(bootstrapProvider);
    final user = bootstrap.config?.user;
    _currentUserId = user?.id;
    _isFacultyOrAdmin = user != null && user.role.toUpperCase() != 'STUDENT';

    _fetchNotices();
    if (_isFacultyOrAdmin) {
      _fetchClasses();
    }
  }

  Future<void> _fetchClasses() async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.dio.get('/api/classes');
      if (response.statusCode == 200) {
        setState(() => _classes = response.data['data'] ?? []);
      }
    } catch (_) {}
  }

  Future<void> _fetchSections(String classId) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.dio.get('/api/sections', queryParameters: {'classId': classId});
      if (response.statusCode == 200) {
        setState(() => _sections = response.data['data'] ?? []);
      }
    } catch (_) {}
  }

  Future<void> _fetchNotices() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.dio.get('/api/notices');

      if (response.statusCode == 200) {
        setState(() {
          _notices = response.data['data'] ?? [];
        });
      }
    } catch (_) {
      setState(() => _errorMessage = 'Failed to load notices & announcements.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showNoticeDetails(dynamic notice) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final attachments = notice['attachments'] as List? ?? [];
        final theme = Theme.of(context);

        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
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
                    Text(
                      notice['title'] ?? 'Notice Announcement',
                      style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    AppSpacing.heightS,
                    Text(
                      'Published on: ${notice['createdAt']?.toString().split('T').first ?? ''} | Target: ${notice['audience'] ?? 'SCHOOL'}',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    AppSpacing.heightL,
                    Text(
                      notice['description'] ?? 'No content details provided.',
                      style: const TextStyle(fontSize: 16, height: 1.4),
                    ),
                    if (attachments.isNotEmpty) ...[
                      AppSpacing.heightL,
                      const Divider(),
                      AppSpacing.heightM,
                      const Text(
                        'Attachments',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      AppSpacing.heightS,
                      ...attachments.map((fileUrl) {
                        final filename = fileUrl.toString().split('/').last;
                        return ListTile(
                          leading: const Icon(Icons.insert_drive_file_outlined),
                          title: Text(filename),
                          trailing: const Icon(Icons.download),
                          onTap: () {},
                        );
                      }),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddOrEditNoticeDialog([dynamic existingNotice]) {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController(text: existingNotice?['title'] ?? '');
    final descController = TextEditingController(text: existingNotice?['description'] ?? '');
    String selectedAudience = existingNotice?['audience'] ?? 'SCHOOL';
    String? selectedClassId = existingNotice?['classId'];
    String? selectedSectionId = existingNotice?['sectionId'];

    if (selectedClassId != null) {
      _fetchSections(selectedClassId);
    }

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
                        existingNotice == null ? 'Publish Notice' : 'Edit Notice',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: 'Title *'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      TextFormField(
                        controller: descController,
                        maxLines: 4,
                        decoration: const InputDecoration(labelText: 'Description *'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      DropdownButtonFormField<String>(
                        value: selectedAudience,
                        decoration: const InputDecoration(labelText: 'Audience *'),
                        items: const [
                          DropdownMenuItem(value: 'SCHOOL', child: Text('School-wide')),
                          DropdownMenuItem(value: 'CLASS', child: Text('Specific Class')),
                          DropdownMenuItem(value: 'FACULTY', child: Text('Faculty-wide')),
                        ],
                        onChanged: (v) {
                          setDialogState(() {
                            selectedAudience = v!;
                            if (selectedAudience != 'CLASS') {
                              selectedClassId = null;
                              selectedSectionId = null;
                            }
                          });
                        },
                      ),
                      if (selectedAudience == 'CLASS') ...[
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
                          decoration: const InputDecoration(labelText: 'Section (Optional)'),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All Sections')),
                            ..._sections.map((s) => DropdownMenuItem(value: s['id'] as String, child: Text(s['name'] ?? ''))),
                          ],
                          onChanged: (v) => setDialogState(() => selectedSectionId = v),
                        ),
                      ],
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
                                  final data = {
                                    'title': titleController.text.trim(),
                                    'description': descController.text.trim(),
                                    'audience': selectedAudience,
                                    if (selectedClassId != null) 'classId': selectedClassId,
                                    if (selectedSectionId != null) 'sectionId': selectedSectionId,
                                  };

                                  if (existingNotice == null) {
                                    response = await apiClient.dio.post('/api/notices', data: data);
                                  } else {
                                    response = await apiClient.dio.put('/api/notices/${existingNotice['id']}', data: data);
                                  }

                                  if (response.statusCode == 200 || response.statusCode == 201) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          existingNotice == null
                                              ? 'Notice published successfully!'
                                              : 'Notice updated successfully!',
                                        ),
                                      ),
                                    );
                                    _fetchNotices();
                                  }
                                } catch (err) {
                                  String msg = err.toString();
                                  if (err is DioException && err.response?.data != null) {
                                    msg = err.response!.data['message'] ?? msg;
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed to publish notice: $msg')),
                                  );
                                }
                              }
                            },
                            child: const Text('Publish'),
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

  Future<void> _deleteNotice(String noticeId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Notice'),
        content: const Text('Are you sure you want to delete this notice announcement?'),
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
        final response = await apiClient.dio.delete('/api/notices/$noticeId');
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notice deleted successfully.')),
          );
          _fetchNotices();
        }
      } catch (err) {
        String msg = err.toString();
        if (err is DioException && err.response?.data != null) {
          msg = err.response!.data['message'] ?? msg;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete notice: $msg')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notices & News'),
      ),
      drawer: const AppNavigationDrawer(),
      floatingActionButton: _isFacultyOrAdmin
          ? FloatingActionButton(
              onPressed: () => _showAddOrEditNoticeDialog(),
              child: const Icon(Icons.campaign),
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
                        onPressed: _fetchNotices,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _notices.isEmpty
                  ? const Center(child: Text('No notices posted.'))
                  : RefreshIndicator(
                      onRefresh: _fetchNotices,
                      child: ListView.builder(
                        itemCount: _notices.length,
                        itemBuilder: (context, index) {
                          final notice = _notices[index];
                          final hasAttachments = (notice['attachments'] as List?)?.isNotEmpty ?? false;

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: theme.colorScheme.outlineVariant),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                child: const Icon(Icons.campaign),
                              ),
                              title: Text(
                                notice['title'] ?? 'Notice',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                notice['description'] ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (hasAttachments) const Icon(Icons.attach_file, size: 18),
                                  if (_isFacultyOrAdmin) ...[
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 18),
                                      onPressed: () => _showAddOrEditNoticeDialog(notice),
                                      constraints: const BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                      onPressed: () => _deleteNotice(notice['id']),
                                      constraints: const BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                    ),
                                  ],
                                ],
                              ),
                              onTap: () => _showNoticeDetails(notice),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
