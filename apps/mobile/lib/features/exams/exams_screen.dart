import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_notifier.dart';
import '../../core/theme/spacing.dart';
import '../../shared/widgets/app_navigation_drawer.dart';

class ExamsScreen extends ConsumerStatefulWidget {
  const ExamsScreen({super.key});

  @override
  ConsumerState<ExamsScreen> createState() => _ExamsScreenState();
}

class _ExamsScreenState extends ConsumerState<ExamsScreen> {
  List<dynamic> _examTerms = [];
  Map<String, dynamic>? _selectedTermResults;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchExams();
  }

  Future<void> _fetchExams() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.dio.get('/api/exams');

      if (response.statusCode == 200) {
        setState(() {
          _examTerms = response.data['data'] ?? [];
        });
        if (_examTerms.isNotEmpty) {
          _fetchTermResults(_examTerms.first['id']);
        }
      }
    } catch (_) {
      setState(() => _errorMessage = 'Failed to load exam terms configuration.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchTermResults(String examId) async {
    setState(() => _isLoading = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      // Fetches results sheet
      final response = await apiClient.dio.get('/api/exams/$examId/results');
      if (response.statusCode == 200) {
        setState(() {
          _selectedTermResults = response.data['data'];
        });
      }
    } catch (_) {
      setState(() => _errorMessage = 'Failed to load term report card.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exams & Report Cards'),
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
                        onPressed: _fetchExams,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _examTerms.isEmpty
                  ? const Center(child: Text('No exam configurations posted.'))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Horizontal dropdown select selector
                        Padding(
                          padding: AppSpacing.paddingM,
                          child: DropdownButtonFormField<String>(
                            value: _selectedTermResults?['exam']?['id'] ?? _examTerms.first['id'],
                            decoration: const InputDecoration(
                              labelText: 'Select Exam Term',
                            ),
                            items: _examTerms.map<DropdownMenuItem<String>>((term) {
                              return DropdownMenuItem<String>(
                                value: term['id'],
                                child: Text(term['name'] ?? 'Exam'),
                              );
                            }).toList(),
                            onChanged: (examId) {
                              if (examId != null) {
                                _fetchTermResults(examId);
                              }
                            },
                          ),
                        ),

                        // Active Card Result Summary
                        if (_selectedTermResults != null)
                          Expanded(
                            child: ListView(
                              padding: AppSpacing.paddingM,
                              children: [
                                _buildPerformanceCard(context, _selectedTermResults!),
                                AppSpacing.heightL,
                                Text(
                                  'Subject-Wise Scores',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                AppSpacing.heightS,
                                ...(_selectedTermResults!['scores'] as List? ?? []).map((score) {
                                  final subject = score['subject'] ?? {};
                                  final status = score['status'] ?? 'PASS';
                                  final marks = score['marks'] ?? 0.0;
                                  final maxMarks = score['maxMarks'] ?? 100.0;
                                  final passing = score['passingMarks'] ?? 33.0;

                                  Color statusColor = Colors.green;
                                  if (status == 'FAIL') statusColor = Colors.red;
                                  if (status == 'ABSENT') statusColor = Colors.orange;

                                  return Card(
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    child: Padding(
                                      padding: AppSpacing.paddingM,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                subject['name'] ?? 'Subject',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                              ),
                                              Text(
                                                status,
                                                style: TextStyle(fontWeight: FontWeight.bold, color: statusColor),
                                              ),
                                            ],
                                          ),
                                          AppSpacing.heightS,
                                          LinearProgressIndicator(
                                            value: maxMarks > 0 ? marks / maxMarks : 0,
                                            color: statusColor,
                                            backgroundColor: Colors.grey.withOpacity(0.2),
                                          ),
                                          AppSpacing.heightS,
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('Scored: $marks / $maxMarks', style: const TextStyle(fontSize: 12)),
                                              Text('Passing threshold: $passing', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          )
                        else
                          const Expanded(
                            child: Center(child: Text('Select an exam term to fetch results.')),
                          ),
                      ],
                    ),
    );
  }

  Widget _buildPerformanceCard(BuildContext context, Map<String, dynamic> results) {
    final status = results['status'] ?? 'PASS';
    final percentage = (results['percentage'] as num?)?.toDouble() ?? 0.0;
    final grade = results['grade'] ?? 'N/A';

    Color cardColor = Colors.green;
    if (status == 'FAIL') cardColor = Colors.red;

    return Card(
      color: cardColor.withOpacity(0.08),
      child: Padding(
        padding: AppSpacing.paddingL,
        child: Column(
          children: [
            Text(
              'Result Status',
              style: TextStyle(fontWeight: FontWeight.bold, color: cardColor, fontSize: 14),
            ),
            AppSpacing.heightS,
            Text(
              status,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 32, color: cardColor),
            ),
            AppSpacing.heightM,
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    const Text('Percentage', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    Text('${percentage.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
                Column(
                  children: [
                    const Text('Grade Point', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    Text(grade, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
