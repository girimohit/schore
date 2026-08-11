import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_notifier.dart';
import '../../core/theme/spacing.dart';
import '../../shared/widgets/app_navigation_drawer.dart';

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

  @override
  void initState() {
    super.initState();
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
          'limit': 20,
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
                    'Employee ID: ${faculty['employeeId'] ?? ''}',
                    style: const TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  AppSpacing.heightL,
                  const Divider(),
                  _buildProfileRow('Designation', faculty['designation'] ?? 'Faculty'),
                  _buildProfileRow('Email', profile['email'] ?? 'N/A'),
                  _buildProfileRow('Phone', profile['phone'] ?? 'N/A'),
                  _buildProfileRow('Date of Joining', faculty['joiningDate']?.toString().split('T').first ?? 'N/A'),
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
        title: const Text('Faculty Directory'),
      ),
      drawer: const AppNavigationDrawer(),
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
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    child: Text('${profile['firstName']?[0] ?? ''}${profile['lastName']?[0] ?? ''}'),
                                  ),
                                  title: Text('${profile['firstName'] ?? ''} ${profile['lastName'] ?? ''}'),
                                  subtitle: Text(faculty['designation'] ?? 'Faculty Member'),
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
