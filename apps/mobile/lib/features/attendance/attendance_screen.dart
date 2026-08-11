import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_notifier.dart';
import '../../features/bootstrap/bootstrap_notifier.dart';
import '../../core/theme/spacing.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  // Faculty State
  String? _selectedClassId;
  String? _selectedSectionId;
  DateTime _selectedDate = DateTime.now();
  List<dynamic> _studentRegister = [];
  Map<String, String> _attendanceMap = {}; // studentId -> status (PRESENT, ABSENT, LATE, EXCUSED)
  bool _isLoading = false;
  String? _message;

  // Student State
  List<dynamic> _studentLogs = [];
  double _attendanceRate = 0.0;

  @override
  void initState() {
    super.initState();
    final bootstrap = ref.read(bootstrapProvider);
    final user = bootstrap.config?.user;
    if (user != null) {
      if (user.role.toUpperCase() == 'STUDENT') {
        _fetchStudentAttendance();
      } else {
        // Teacher/Admin defaults - Fetch classes
        _fetchClassList();
      }
    }
  }

  Future<void> _fetchStudentAttendance() async {
    setState(() => _isLoading = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.dio.get('/api/attendance');
      if (response.statusCode == 200) {
        setState(() {
          _studentLogs = response.data['data']['records'] ?? [];
          _attendanceRate = (response.data['data']['percentage'] as num?)?.toDouble() ?? 0.0;
        });
      }
    } catch (_) {
      setState(() => _message = 'Failed to load attendance logs.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchClassList() async {
    // In production we would query class listings; for now we initialize defaults from bootstrap
  }

  Future<void> _loadStudentRegister() async {
    if (_selectedClassId == null || _selectedSectionId == null) return;
    setState(() => _isLoading = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      // Fetch students enrolled in this class/section
      final response = await apiClient.dio.get(
        '/api/students',
        queryParameters: {
          'classId': _selectedClassId,
          'sectionId': _selectedSectionId,
          'limit': 100,
        },
      );

      if (response.statusCode == 200) {
        final students = response.data['data']['students'] as List;
        setState(() {
          _studentRegister = students;
          _attendanceMap = {
            for (var s in students) s['id']: 'PRESENT',
          };
        });
      }
    } catch (_) {
      setState(() => _message = 'Failed to load class register.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitAttendance() async {
    if (_attendanceMap.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      final logs = _attendanceMap.entries.map((e) => {
            'studentId': e.key,
            'status': e.value,
          }).toList();

      final response = await apiClient.dio.post(
        '/api/attendance',
        data: {
          'date': _selectedDate.toIso8601String().split('T').first,
          'classId': _selectedClassId,
          'sectionId': _selectedSectionId,
          'records': logs,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance recorded successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to submit attendance register.')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bootstrap = ref.watch(bootstrapProvider);
    final user = bootstrap.config?.user;
    final role = user?.role.toUpperCase() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : role == 'STUDENT'
              ? _buildStudentView(context)
              : _buildFacultyView(context),
    );
  }

  // ─────────────────────────────────────────────
  // STUDENT VIEW (Attendance Summary & logs)
  // ─────────────────────────────────────────────
  Widget _buildStudentView(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _fetchStudentAttendance,
      child: ListView(
        padding: AppSpacing.paddingM,
        children: [
          if (_message != null) ...[
            Card(
              color: Theme.of(context).colorScheme.error.withOpacity(0.1),
              child: Padding(
                padding: AppSpacing.paddingM,
                child: Text(
                  _message!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            AppSpacing.heightM,
          ],
          Card(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
            child: Padding(
              padding: AppSpacing.paddingL,
              child: Column(
                children: [
                  Text(
                    'Overall Attendance',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  AppSpacing.heightS,
                  Text(
                    '${_attendanceRate.toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          ),
          AppSpacing.heightL,
          Text(
            'Attendance History',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          AppSpacing.heightS,
          if (_studentLogs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(child: Text('No attendance records logged.')),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _studentLogs.length,
              itemBuilder: (context, index) {
                final log = _studentLogs[index];
                final status = log['status'] ?? 'PRESENT';
                Color statusColor = Colors.green;
                if (status == 'ABSENT') statusColor = Colors.red;
                if (status == 'LATE') statusColor = Colors.orange;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: Icon(
                      status == 'PRESENT'
                          ? Icons.check_circle
                          : status == 'LATE'
                              ? Icons.alarm
                              : Icons.cancel,
                      color: statusColor,
                    ),
                    title: Text(log['date']?.toString().split('T').first ?? ''),
                    trailing: Text(
                      status,
                      style: TextStyle(fontWeight: FontWeight.bold, color: statusColor),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // FACULTY VIEW (Select class + mark students)
  // ─────────────────────────────────────────────
  Widget _buildFacultyView(BuildContext context) {
    return Padding(
      padding: AppSpacing.paddingM,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Basic selection rows (Simulating class selectors using inputs for compilation safety)
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Class ID',
                    hintText: 'e.g. class_uuid',
                  ),
                  onChanged: (val) => setState(() => _selectedClassId = val.trim()),
                ),
              ),
              AppSpacing.widthM,
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Section ID',
                    hintText: 'e.g. section_uuid',
                  ),
                  onChanged: (val) => setState(() => _selectedSectionId = val.trim()),
                ),
              ),
            ],
          ),
          AppSpacing.heightM,
          ElevatedButton(
            onPressed: _loadStudentRegister,
            child: const Text('Load Student Register'),
          ),
          AppSpacing.heightL,
          if (_studentRegister.isNotEmpty) ...[
            Expanded(
              child: ListView.builder(
                itemCount: _studentRegister.length,
                itemBuilder: (context, index) {
                  final student = _studentRegister[index];
                  final profile = student['profile'] ?? {};
                  final studentId = student['id'];
                  final currentStatus = _attendanceMap[studentId] ?? 'PRESENT';

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Text('${profile['firstName'] ?? ''} ${profile['lastName'] ?? ''}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildStatusToggle(studentId, 'PRESENT', currentStatus, Colors.green),
                          _buildStatusToggle(studentId, 'ABSENT', currentStatus, Colors.red),
                          _buildStatusToggle(studentId, 'LATE', currentStatus, Colors.orange),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            AppSpacing.heightM,
            ElevatedButton(
              onPressed: _submitAttendance,
              child: const Text('Submit Attendance Register'),
            ),
          ] else
            const Expanded(
              child: Center(
                child: Text('Enter Class & Section ID to retrieve register.'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusToggle(String studentId, String status, String currentStatus, Color activeColor) {
    final isSelected = currentStatus == status;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: ChoiceChip(
        label: Text(status[0]),
        selected: isSelected,
        selectedColor: activeColor.withOpacity(0.2),
        labelStyle: TextStyle(
          color: isSelected ? activeColor : Colors.grey,
          fontWeight: FontWeight.bold,
        ),
        onSelected: (selected) {
          if (selected) {
            setState(() {
              _attendanceMap[studentId] = status;
            });
          }
        },
      ),
    );
  }
}
