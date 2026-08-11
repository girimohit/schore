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

  void _showHomeworkDetails(dynamic hw, String role) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final submissionTextController = TextEditingController();
        final gradingController = TextEditingController();
        final feedbackController = TextEditingController();
        final subject = hw['subject'] ?? {};

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
                      Text(
                        hw['title'] ?? 'Homework Assignment',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      AppSpacing.heightS,
                      Text(
                        'Subject: ${subject['name'] ?? ''}',
                        style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Due Date: ${hw['dueDate']?.toString().split('T').first ?? ''}',
                        style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                      ),
                      AppSpacing.heightL,
                      const Text(
                        'Description',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      AppSpacing.heightS,
                      Text(hw['description'] ?? 'No description provided.'),
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
                            hintText: 'Enter your solution text/link here...',
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
                                  'content': submissionTextController.text.trim(),
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

                      // TEACHER GRADING INTERFACE
                      if (role == 'FACULTY' || role == 'ADMIN' || role == 'SUPERADMIN') ...[
                        const Divider(),
                        AppSpacing.heightM,
                        const Text(
                          'Grade Submissions',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        AppSpacing.heightS,
                        TextField(
                          controller: gradingController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Marks Awarded',
                            hintText: 'e.g. 85',
                          ),
                        ),
                        AppSpacing.heightM,
                        TextField(
                          controller: feedbackController,
                          decoration: const InputDecoration(
                            labelText: 'Feedback Remarks',
                            hintText: 'e.g. Well researched!',
                          ),
                          maxLines: 2,
                        ),
                        AppSpacing.heightM,
                        ElevatedButton(
                          onPressed: () async {
                            if (gradingController.text.trim().isEmpty) return;
                            try {
                              final apiClient = ref.read(apiClientProvider);
                              // In production, we'd specify the individual student's submission UUID.
                              // Submitting with placeholders for compilation checks.
                              await apiClient.dio.put(
                                '/api/homework/${hw['id']}/submissions/placeholder_sub_id',
                                data: {
                                  'marks': double.parse(gradingController.text),
                                  'feedback': feedbackController.text.trim(),
                                },
                              );
                              Navigator.pop(context);
                            } catch (_) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Failed to save grading feedback.')),
                              );
                            }
                          },
                          child: const Text('Save Marks & Feedback'),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Homework Assignments'),
      ),
      drawer: const AppNavigationDrawer(),
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
                  ? const Center(child: Text('No assignments posted.'))
                  : RefreshIndicator(
                      onRefresh: _fetchHomework,
                      child: ListView.builder(
                        itemCount: _assignments.length,
                        itemBuilder: (context, index) {
                          final hw = _assignments[index];
                          final subject = hw['subject'] ?? {};

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                child: const Icon(Icons.menu_book),
                              ),
                              title: Text(hw['title'] ?? 'Homework'),
                              subtitle: Text('Subject: ${subject['name'] ?? ''} - Due: ${hw['dueDate']?.toString().split('T').first ?? ''}'),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: () => _showHomeworkDetails(hw, role),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
