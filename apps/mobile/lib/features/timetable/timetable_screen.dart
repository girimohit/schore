import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_notifier.dart';
import '../../core/theme/spacing.dart';

class TimetableScreen extends ConsumerStatefulWidget {
  const TimetableScreen({super.key});

  @override
  ConsumerState<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends ConsumerState<TimetableScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _days = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY'];
  List<dynamic> _timetableSlots = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _days.length, vsync: this);
    _fetchTimetable();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchTimetable() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.dio.get('/api/timetable');

      if (response.statusCode == 200) {
        setState(() {
          _timetableSlots = response.data['data'] ?? [];
        });
      }
    } catch (_) {
      setState(() => _errorMessage = 'Failed to load timetable schedules.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<dynamic> _getSlotsForDay(String day) {
    return _timetableSlots.where((slot) => slot['dayOfWeek']?.toString().toUpperCase() == day).toList()
      ..sort((a, b) {
        final aTime = a['startTime']?.toString() ?? '';
        final bTime = b['startTime']?.toString() ?? '';
        return aTime.compareTo(bTime);
      });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('School Timetable'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _days.map((day) => Tab(text: day[0] + day.substring(1).toLowerCase())).toList(),
        ),
      ),
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
                        onPressed: _fetchTimetable,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: _days.map((day) {
                    final slots = _getSlotsForDay(day);

                    if (slots.isEmpty) {
                      return const Center(
                        child: Text('No classes scheduled for this day.'),
                      );
                    }

                    return ListView.builder(
                      padding: AppSpacing.paddingM,
                      itemCount: slots.length,
                      itemBuilder: (context, index) {
                        final slot = slots[index];
                        final subject = slot['subject'] ?? {};
                        final teacher = slot['teacher']?.toString() ?? 'Faculty';

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: Padding(
                            padding: AppSpacing.paddingM,
                            child: Row(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      slot['startTime'] ?? '',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                    Text(
                                      'to ${slot['endTime'] ?? ''}',
                                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                                    ),
                                  ],
                                ),
                                AppSpacing.widthL,
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        subject['name'] ?? 'Class slot',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      AppSpacing.heightXS,
                                      Row(
                                        children: [
                                          const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                                          AppSpacing.widthXS,
                                          Text(teacher, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                          AppSpacing.widthM,
                                          const Icon(Icons.meeting_room_outlined, size: 14, color: Colors.grey),
                                          AppSpacing.widthXS,
                                          Text(slot['room'] ?? 'N/A', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
    );
  }
}
