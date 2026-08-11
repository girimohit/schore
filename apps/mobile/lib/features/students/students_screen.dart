import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_notifier.dart';
import '../../core/theme/spacing.dart';
import '../../shared/widgets/app_navigation_drawer.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchStudents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
          'limit': 20,
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
                      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
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
                  _buildProfileRow('Date of Birth', profile['dob']?.toString().split('T').first ?? 'N/A'),
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
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Students Directory'),
      ),
      drawer: const AppNavigationDrawer(),
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
                              final enrollment = (student['enrollments'] as List?)?.firstOrNull ?? {};
                              final activeClass = enrollment['class'] ?? {};
                              final section = enrollment['section'] ?? {};

                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    child: Text('${profile['firstName']?[0] ?? ''}${profile['lastName']?[0] ?? ''}'),
                                  ),
                                  title: Text('${profile['firstName'] ?? ''} ${profile['lastName'] ?? ''}'),
                                  subtitle: Text('Class: ${activeClass['name'] ?? ''} - ${section['name'] ?? ''}'),
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
