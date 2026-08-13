import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../core/auth/auth_notifier.dart';
import '../../core/theme/spacing.dart';
import '../../shared/widgets/app_navigation_drawer.dart';
import '../bootstrap/bootstrap_notifier.dart';

class FacultyScreen extends ConsumerStatefulWidget {
  const FacultyScreen({super.key});

  @override
  ConsumerState<FacultyScreen> createState() => _FacultyScreenState();
}

class _FacultyScreenState extends ConsumerState<FacultyScreen> {
  final _searchController = TextEditingController();
  List<dynamic> _facultyList = [];
  bool _isLoading = false;
  String? _errorMessage;
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

    _fetchFaculty();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchFaculty({String search = ''}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.dio.get(
        '/api/faculty',
        queryParameters: {
          if (search.isNotEmpty) 'search': search,
          'limit': 50,
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _facultyList = response.data['data']['faculty'] ?? [];
        });
      } else {
        setState(() {
          _errorMessage = response.data['message'] ?? 'Failed to load faculty';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading faculty records';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showFacultyProfile(dynamic faculty) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final profile = faculty['profile'] ?? {};

        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          maxChildSize: 0.8,
          minChildSize: 0.3,
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
                    'Employee ID: ${faculty['employeeId'] ?? ''}',
                    style: const TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  AppSpacing.heightL,
                  const Divider(),
                  _buildProfileRow('Designation', faculty['designation'] ?? 'N/A'),
                  _buildProfileRow('Qualification', faculty['qualification'] ?? 'N/A'),
                  _buildProfileRow('Email', profile['email'] ?? 'N/A'),
                  _buildProfileRow('Phone', profile['phone'] ?? 'N/A'),
                  _buildProfileRow(
                    'Joining Date',
                    faculty['joiningDate']?.toString().split('T').first ?? 'N/A',
                  ),
                  if (_isAdmin) ...[
                    AppSpacing.heightL,
                    const Divider(),
                    AppSpacing.heightS,
                    Text(
                      'Administrative Actions',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    AppSpacing.heightS,
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.send_outlined, size: 16),
                            label: const Text('Resend Invite', style: TextStyle(fontSize: 12)),
                            onPressed: () async {
                              final userId = faculty['profile']?['id'] ?? faculty['userId'];
                              if (userId == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('This faculty has no associated user account.')),
                                );
                                return;
                              }
                              try {
                                final apiClient = ref.read(apiClientProvider);
                                final response = await apiClient.dio.post(
                                  '/api/auth/invite/resend',
                                  data: {'userId': userId},
                                );
                                if (response.statusCode == 200) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Onboarding invitation resent successfully!')),
                                  );
                                }
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to resend: $e')),
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.block_outlined, size: 16, color: Colors.red),
                            label: const Text('Revoke / Suspend', style: TextStyle(fontSize: 12, color: Colors.red)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                            ),
                            onPressed: () async {
                              final userId = faculty['profile']?['id'] ?? faculty['userId'];
                              if (userId == null) return;
                              try {
                                final apiClient = ref.read(apiClientProvider);
                                await apiClient.dio.post(
                                  '/api/auth/invite/revoke',
                                  data: {'userId': userId},
                                );
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Invitation revoked / User suspended successfully.')),
                                );
                                _fetchFaculty();
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to revoke: $e')),
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
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

  void _showAddFacultyDialog() {
    final formKey = GlobalKey<FormState>();
    final empIdController = TextEditingController();
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final designationController = TextEditingController();
    final qualificationController = TextEditingController();
    DateTime? selectedJoiningDate;

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
                        'Add Faculty Profile',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: empIdController,
                        decoration: const InputDecoration(labelText: 'Employee ID *'),
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
                        decoration: const InputDecoration(labelText: 'Email Address *'),
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      TextFormField(
                        controller: phoneController,
                        decoration: const InputDecoration(labelText: 'Phone Number'),
                      ),
                      TextFormField(
                        controller: designationController,
                        decoration: const InputDecoration(labelText: 'Designation'),
                      ),
                      TextFormField(
                        controller: qualificationController,
                        decoration: const InputDecoration(labelText: 'Qualification'),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          selectedJoiningDate == null
                              ? 'Select Joining Date'
                              : 'Joining: ${selectedJoiningDate!.toLocal().toString().split(' ').first}',
                        ),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            setDialogState(() => selectedJoiningDate = date);
                          }
                        },
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
                                  final response = await apiClient.dio.post(
                                    '/api/faculty',
                                    data: {
                                      'employeeId': empIdController.text.trim(),
                                      'firstName': firstNameController.text.trim(),
                                      'lastName': lastNameController.text.trim(),
                                      'email': emailController.text.trim(),
                                      'phone': phoneController.text.trim(),
                                      'designation': designationController.text.trim(),
                                      'qualification': qualificationController.text.trim(),
                                      if (selectedJoiningDate != null)
                                        'joiningDate': selectedJoiningDate!.toIso8601String(),
                                    },
                                  );

                                  if (response.statusCode == 201 || response.data['success'] == true) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Faculty profile created successfully!')),
                                    );
                                    _fetchFaculty();
                                  }
                                } catch (err) {
                                  String msg = err.toString();
                                  if (err is DioException && err.response?.data != null) {
                                    msg = err.response!.data['message'] ?? msg;
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed to save faculty: $msg')),
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

  void _showBulkImportDialog() {
    final csvController = TextEditingController(
      text: "employeeid,firstname,lastname,email,phone,joiningdate\n"
          "EMP101,Jane,Smith,jane.smith@example.com,+918888888888,2024-01-15",
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Bulk Import Faculty'),
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
                        hintText: 'employeeid,firstname,lastname...',
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
                                filename: 'faculty.csv',
                              ),
                            });

                            final response = await apiClient.dio.post(
                              '/api/school/import/faculty',
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
                              _fetchFaculty();
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
        title: const Text('Faculty Directory'),
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
              onPressed: _showAddFacultyDialog,
              tooltip: 'Add Faculty',
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
                hintText: 'Search by employee name...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _fetchFaculty();
                  },
                ),
              ),
              onSubmitted: (value) => _fetchFaculty(search: value.trim()),
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
                              onPressed: () => _fetchFaculty(search: _searchController.text),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _facultyList.isEmpty
                        ? const Center(child: Text('No faculty members found.'))
                        : ListView.builder(
                            itemCount: _facultyList.length,
                            itemBuilder: (context, index) {
                              final faculty = _facultyList[index];
                              final profile = faculty['profile'] ?? {};

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
                                    faculty['designation'] ?? 'Faculty Member',
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => _showFacultyProfile(faculty),
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
