import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_notifier.dart';
import '../../features/bootstrap/bootstrap_notifier.dart';
import '../../core/theme/spacing.dart';
import '../../shared/widgets/app_navigation_drawer.dart';

class TimetableScreen extends ConsumerStatefulWidget {
  const TimetableScreen({super.key});

  @override
  ConsumerState<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends ConsumerState<TimetableScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _days = [
    'MONDAY',
    'TUESDAY',
    'WEDNESDAY',
    'THURSDAY',
    'FRIDAY',
    'SATURDAY'
  ];

  List<dynamic> _timetableSlots = [];
  List<dynamic> _classes = [];
  List<dynamic> _sections = [];
  String? _selectedClassFilter;
  String? _selectedSectionFilter;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _days.length, vsync: this);
    _fetchTimetable();
    _fetchClasses();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchClasses() async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.dio.get('/api/classes');
      if (response.statusCode == 200) {
        setState(() {
          _classes = response.data['data'] ?? [];
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchSections(String classId) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.dio
          .get('/api/sections', queryParameters: {'classId': classId});
      if (response.statusCode == 200) {
        setState(() {
          _sections = response.data['data'] ?? [];
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchTimetable() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      final bootstrap = ref.read(bootstrapProvider);
      final role = bootstrap.config?.user?.role.toUpperCase() ?? '';

      Map<String, dynamic> queryParams = {};
      if (role == 'SCHOOL_ADMIN' || role == 'SUPER_ADMIN' || role == 'ADMIN') {
        if (_selectedClassFilter != null && _selectedSectionFilter != null) {
          queryParams = {
            'type': 'class',
            'classId': _selectedClassFilter,
            'sectionId': _selectedSectionFilter,
          };
        }
      }

      final response = await apiClient.dio
          .get('/api/timetable', queryParameters: queryParams.isEmpty ? null : queryParams);

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

  List<dynamic> _getSlotsForDayIndex(int dayIndex) {
    final dayNum = dayIndex + 1; // 1 = Monday, 6 = Saturday
    final dayName = _days[dayIndex];

    return _timetableSlots.where((slot) {
      final slotDay = slot['dayOfWeek'];
      if (slotDay is int) {
        return slotDay == dayNum;
      }
      return slotDay?.toString().toUpperCase() == dayName ||
          slotDay?.toString() == dayNum.toString();
    }).toList()
      ..sort((a, b) {
        final aPeriod = (a['period'] as num?)?.toInt() ?? 0;
        final bPeriod = (b['period'] as num?)?.toInt() ?? 0;
        if (aPeriod != bPeriod) return aPeriod.compareTo(bPeriod);
        final aTime = a['startTime']?.toString() ?? '';
        final bTime = b['startTime']?.toString() ?? '';
        return aTime.compareTo(bTime);
      });
  }

  Future<void> _deleteSlot(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Timetable Slot'),
        content: const Text('Are you sure you want to remove this timetable slot?'),
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
      final res = await apiClient.dio.delete('/api/timetable/$id');
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Timetable slot deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchTimetable();
      }
    } catch (err: any) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            err?.response?.data?['message'] ?? 'Failed to delete timetable slot.',
          ),
        ),
      );
    }
  }

  void _showCreateOrEditSlotDialog({dynamic existingSlot}) async {
    final apiClient = ref.read(apiClientProvider);
    List<dynamic> classes = [];
    List<dynamic> sections = [];
    List<dynamic> subjects = [];
    List<dynamic> facultyList = [];

    try {
      final classRes = await apiClient.dio.get('/api/classes');
      if (classRes.statusCode == 200) classes = classRes.data['data'] ?? [];
      final subjRes = await apiClient.dio.get('/api/subjects');
      if (subjRes.statusCode == 200) subjects = subjRes.data['data'] ?? [];
      final facRes = await apiClient.dio.get('/api/faculty');
      if (facRes.statusCode == 200) facultyList = facRes.data['data'] ?? [];
    } catch (_) {}

    if (!mounted) return;

    final isEditing = existingSlot != null;
    String? selectedClassId = existingSlot?['classId'] ?? _selectedClassFilter;
    String? selectedSectionId = existingSlot?['sectionId'] ?? _selectedSectionFilter;
    String? selectedSubjectId = existingSlot?['subjectId'];
    String? selectedFacultyId = existingSlot?['facultyId'];
    int selectedDayOfWeek = existingSlot != null
        ? (existingSlot['dayOfWeek'] is int
            ? existingSlot['dayOfWeek']
            : int.tryParse(existingSlot['dayOfWeek'].toString()) ?? (_tabController.index + 1))
        : (_tabController.index + 1);

    final periodController = TextEditingController(
      text: existingSlot?['period']?.toString() ?? '1',
    );
    final startTimeController = TextEditingController(
      text: existingSlot?['startTime'] ?? '09:00',
    );
    final endTimeController = TextEditingController(
      text: existingSlot?['endTime'] ?? '09:45',
    );
    final roomController = TextEditingController(
      text: existingSlot?['room'] ?? '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            void loadSections(String classId) async {
              try {
                final secRes = await apiClient.dio
                    .get('/api/sections', queryParameters: {'classId': classId});
                if (secRes.statusCode == 200) {
                  setModalState(() {
                    sections = secRes.data['data'] ?? [];
                    if (!sections.any((s) => s['id'] == selectedSectionId)) {
                      selectedSectionId =
                          sections.isNotEmpty ? sections.first['id'] : null;
                    }
                  });
                }
              } catch (_) {}
            }

            if (selectedClassId != null && sections.isEmpty) {
              loadSections(selectedClassId!);
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
                      isEditing ? 'Edit Schedule Slot' : 'Add Timetable Slot',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
                        if (val != null) loadSections(val);
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
                      onChanged: (val) =>
                          setModalState(() => selectedSectionId = val),
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
                      onChanged: (val) =>
                          setModalState(() => selectedSubjectId = val),
                    ),
                    AppSpacing.heightM,
                    DropdownButtonFormField<String>(
                      value: selectedFacultyId,
                      decoration: const InputDecoration(
                        labelText: 'Teacher / Faculty (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Unassigned'),
                        ),
                        ...facultyList.map<DropdownMenuItem<String>>((f) {
                          final name =
                              '${f['user']?['firstName'] ?? ''} ${f['user']?['lastName'] ?? ''}'
                                  .trim();
                          return DropdownMenuItem<String>(
                            value: f['id'],
                            child: Text(name.isNotEmpty ? name : (f['employeeId'] ?? 'Faculty')),
                          );
                        }),
                      ],
                      onChanged: (val) =>
                          setModalState(() => selectedFacultyId = val),
                    ),
                    AppSpacing.heightM,
                    DropdownButtonFormField<int>(
                      value: selectedDayOfWeek,
                      decoration: const InputDecoration(
                        labelText: 'Day of Week *',
                        border: OutlineInputBorder(),
                      ),
                      items: List.generate(_days.length, (idx) {
                        final num = idx + 1;
                        final name = _days[idx];
                        return DropdownMenuItem<int>(
                          value: num,
                          child: Text(
                              name[0] + name.substring(1).toLowerCase()),
                        );
                      }),
                      onChanged: (val) =>
                          setModalState(() => selectedDayOfWeek = val ?? 1),
                    ),
                    AppSpacing.heightM,
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: periodController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Period # *',
                              hintText: '1',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        AppSpacing.widthM,
                        Expanded(
                          child: TextField(
                            controller: roomController,
                            decoration: const InputDecoration(
                              labelText: 'Room / Lab',
                              hintText: 'e.g. 101',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.heightM,
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: startTimeController,
                            decoration: const InputDecoration(
                              labelText: 'Start Time *',
                              hintText: '09:00',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        AppSpacing.widthM,
                        Expanded(
                          child: TextField(
                            controller: endTimeController,
                            decoration: const InputDecoration(
                              labelText: 'End Time *',
                              hintText: '09:45',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.heightL,
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        if (selectedClassId == null ||
                            selectedSectionId == null ||
                            selectedSubjectId == null) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Class, Section, and Subject are required'),
                            ),
                          );
                          return;
                        }

                        final period = int.tryParse(periodController.text.trim()) ?? 1;
                        final startTime = startTimeController.text.trim();
                        final endTime = endTimeController.text.trim();

                        if (startTime.isEmpty || endTime.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Start and end times are required'),
                            ),
                          );
                          return;
                        }

                        final payload = {
                          'classId': selectedClassId,
                          'sectionId': selectedSectionId,
                          'subjectId': selectedSubjectId,
                          'facultyId': selectedFacultyId,
                          'dayOfWeek': selectedDayOfWeek,
                          'period': period,
                          'startTime': startTime,
                          'endTime': endTime,
                          'room': roomController.text.trim().isEmpty
                              ? null
                              : roomController.text.trim(),
                        };

                        try {
                          if (isEditing) {
                            await apiClient.dio.put(
                              '/api/timetable/${existingSlot['id']}',
                              data: payload,
                            );
                          } else {
                            await apiClient.dio.post(
                              '/api/timetable',
                              data: payload,
                            );
                          }

                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isEditing
                                  ? 'Timetable slot updated!'
                                  : 'Timetable slot created successfully!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          _fetchTimetable();
                        } catch (err: any) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(
                                err?.response?.data?['message'] ??
                                    'Failed to save timetable slot',
                              ),
                            ),
                          );
                        }
                      },
                      child: Text(isEditing ? 'Save Changes' : 'Add Slot'),
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

  @override
  Widget build(BuildContext context) {
    final bootstrap = ref.watch(bootstrapProvider);
    final user = bootstrap.config?.user;
    final role = user?.role.toUpperCase() ?? '';
    final canManage = role == 'SCHOOL_ADMIN' ||
        role == 'SUPER_ADMIN' ||
        role == 'ADMIN';

    return Scaffold(
      appBar: AppBar(
        title: const Text('School Timetable'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _days
              .map((day) =>
                  Tab(text: day[0] + day.substring(1).toLowerCase()))
              .toList(),
        ),
      ),
      drawer: const AppNavigationDrawer(),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateOrEditSlotDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add Slot'),
            )
          : null,
      body: Column(
        children: [
          // Class/Section filter bar for Admin
          if (canManage && _classes.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButton<String?>(
                      isExpanded: true,
                      value: _selectedClassFilter,
                      hint: const Text('All Classes'),
                      underline: const SizedBox(),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All Classes'),
                        ),
                        ..._classes.map((c) => DropdownMenuItem<String?>(
                              value: c['id'],
                              child: Text(c['name'] ?? 'Class'),
                            )),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedClassFilter = val;
                          _selectedSectionFilter = null;
                          _sections = [];
                        });
                        if (val != null) _fetchSections(val);
                        _fetchTimetable();
                      },
                    ),
                  ),
                  if (_selectedClassFilter != null && _sections.isNotEmpty) ...[
                    AppSpacing.widthM,
                    Expanded(
                      child: DropdownButton<String?>(
                        isExpanded: true,
                        value: _selectedSectionFilter,
                        hint: const Text('All Sections'),
                        underline: const SizedBox(),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('All Sections'),
                          ),
                          ..._sections.map((s) => DropdownMenuItem<String?>(
                                value: s['id'],
                                child: Text('Sec: ${s['name']}'),
                              )),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedSectionFilter = val);
                          _fetchTimetable();
                        },
                      ),
                    ),
                  ],
                ],
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
                              onPressed: _fetchTimetable,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: List.generate(_days.length, (dayIndex) {
                          final slots = _getSlotsForDayIndex(dayIndex);

                          if (slots.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.schedule_outlined,
                                      size: 56, color: Colors.grey.shade400),
                                  AppSpacing.heightM,
                                  const Text('No classes scheduled for this day.'),
                                  if (canManage) ...[
                                    AppSpacing.heightS,
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.add),
                                      label: const Text('Add Period Slot'),
                                      onPressed: () => _showCreateOrEditSlotDialog(),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }

                          return RefreshIndicator(
                            onRefresh: _fetchTimetable,
                            child: ListView.builder(
                              padding: const EdgeInsets.only(
                                  left: 16, right: 16, top: 12, bottom: 80),
                              itemCount: slots.length,
                              itemBuilder: (context, index) {
                                final slot = slots[index];
                                final subject = slot['subject'] ?? {};
                                final faculty = slot['faculty'] ?? {};
                                final teacherUser = faculty['user'];
                                final teacherName = teacherUser != null
                                    ? '${teacherUser['firstName'] ?? ''} ${teacherUser['lastName'] ?? ''}'.trim()
                                    : (slot['teacher']?.toString() ?? 'Faculty');
                                final className = slot['class']?['name'] ?? '';
                                final sectionName = slot['section']?['name'] ?? '';

                                return Card(
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: AppSpacing.paddingM,
                                    child: Row(
                                      children: [
                                        // Period badge & times
                                        Container(
                                          width: 76,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8, horizontal: 6),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primaryContainer
                                                .withOpacity(0.5),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                'Period ${slot['period'] ?? (index + 1)}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                slot['startTime'] ?? '',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              Text(
                                                slot['endTime'] ?? '',
                                                style: const TextStyle(
                                                    color: Colors.grey,
                                                    fontSize: 11),
                                              ),
                                            ],
                                          ),
                                        ),
                                        AppSpacing.widthM,
                                        // Slot details
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                subject['name'] ?? 'Class Slot',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              if (className.isNotEmpty) ...[
                                                AppSpacing.heightXS,
                                                Text(
                                                  'Class: $className - $sectionName',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .secondary,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                              AppSpacing.heightXS,
                                              Row(
                                                children: [
                                                  const Icon(
                                                      Icons.person_outline,
                                                      size: 14,
                                                      color: Colors.grey),
                                                  AppSpacing.widthXS,
                                                  Expanded(
                                                    child: Text(
                                                      teacherName.isNotEmpty
                                                          ? teacherName
                                                          : 'Unassigned',
                                                      style: const TextStyle(
                                                          color: Colors.grey,
                                                          fontSize: 12),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (slot['room'] != null &&
                                                      slot['room']
                                                          .toString()
                                                          .isNotEmpty) ...[
                                                    AppSpacing.widthM,
                                                    const Icon(
                                                        Icons
                                                            .meeting_room_outlined,
                                                        size: 14,
                                                        color: Colors.grey),
                                                    AppSpacing.widthXS,
                                                    Text(
                                                      slot['room'],
                                                      style: const TextStyle(
                                                          color: Colors.grey,
                                                          fontSize: 12),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Admin actions
                                        if (canManage) ...[
                                          IconButton(
                                            icon: const Icon(
                                                Icons.edit_outlined,
                                                size: 20),
                                            onPressed: () =>
                                                _showCreateOrEditSlotDialog(
                                                    existingSlot: slot),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                                Icons.delete_outline,
                                                size: 20,
                                                color: Colors.redAccent),
                                            onPressed: () =>
                                                _deleteSlot(slot['id']),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        }).toList(),
                      ),
          ),
        ],
      ),
    );
  }
}
