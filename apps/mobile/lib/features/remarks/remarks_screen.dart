import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_notifier.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/radius.dart';
import '../../shared/widgets/app_navigation_drawer.dart';

class RemarksScreen extends ConsumerStatefulWidget {
  const RemarksScreen({super.key});

  @override
  ConsumerState<RemarksScreen> createState() => _RemarksScreenState();
}

class _RemarksScreenState extends ConsumerState<RemarksScreen> {
  List<dynamic> _remarks = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchRemarks();
  }

  Future<void> _fetchRemarks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      // Student logs queries their own profile remarks feed
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Remarks'),
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
                        onPressed: _fetchRemarks,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _remarks.isEmpty
                  ? const Center(child: Text('No teacher remarks recorded.'))
                  : RefreshIndicator(
                      onRefresh: _fetchRemarks,
                      child: ListView.builder(
                        padding: AppSpacing.paddingM,
                        itemCount: _remarks.length,
                        itemBuilder: (context, index) {
                          final remark = _remarks[index];
                          final category = remark['category'] ?? 'GENERAL';
                          final author = remark['author']?.toString() ?? 'Teacher';
                          final color = _getCategoryColor(category);

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
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
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        remark['createdAt']?.toString().split('T').first ?? '',
                                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  AppSpacing.heightM,
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
    );
  }
}
