import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../core/auth/auth_notifier.dart';
import '../../core/theme/spacing.dart';
import '../../shared/widgets/app_navigation_drawer.dart';

class AcademicSettingsScreen extends ConsumerStatefulWidget {
  const AcademicSettingsScreen({super.key});

  @override
  ConsumerState<AcademicSettingsScreen> createState() => _AcademicSettingsScreenState();
}

class _AcademicSettingsScreenState extends ConsumerState<AcademicSettingsScreen> {
  List<dynamic> _classes = [];
  List<dynamic> _subjects = [];
  List<dynamic> _sections = [];
  List<dynamic> _academicYears = [];
  
  bool _isLoading = false;
  String? _selectedClassIdForSections;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      
      final classesRes = await apiClient.dio.get('/api/classes');
      final subjectsRes = await apiClient.dio.get('/api/subjects');
      final yearsRes = await apiClient.dio.get('/api/academic-years');

      if (classesRes.statusCode == 200) {
        setState(() {
          _classes = classesRes.data['data'] ?? [];
          if (_classes.isNotEmpty && _selectedClassIdForSections == null) {
            _selectedClassIdForSections = _classes.first['id'];
          }
        });
      }
      if (subjectsRes.statusCode == 200) {
        setState(() => _subjects = subjectsRes.data['data'] ?? []);
      }
      if (yearsRes.statusCode == 200) {
        setState(() => _academicYears = yearsRes.data['data'] ?? []);
      }

      if (_selectedClassIdForSections != null) {
        await _fetchSections(_selectedClassIdForSections!);
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load configuration parameters.')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchSections(String classId) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final sectionsRes = await apiClient.dio.get(
        '/api/sections',
        queryParameters: {'classId': classId},
      );
      if (sectionsRes.statusCode == 200) {
        setState(() => _sections = sectionsRes.data['data'] ?? []);
      }
    } catch (_) {}
  }

  // --- Quick Setup Wizard (Indian / CBSE Curriculum) ---
  void _runCBSEQuickSetup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isProvisioning = false;
        double progress = 0.0;
        String statusText = 'Starting setup...';

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('CBSE Quick Setup Wizard'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'This wizard will automatically provision standard Indian School structures:\n\n'
                    '• Classes: 1st to 10th Standard\n'
                    '• Streams: 11th & 12th (Science, Commerce, Humanities)\n'
                    '• Standard Subjects: Hindi, English, Maths, Science, Social Studies, Physics, Chemistry, Accountancy, Economics, History, Geography, and more.\n'
                    '• Class-Subject mappings and default Sections (A & B).',
                    style: TextStyle(fontSize: 13),
                  ),
                  AppSpacing.heightM,
                  if (isProvisioning) ...[
                    LinearProgressIndicator(value: progress),
                    AppSpacing.heightS,
                    Text(
                      statusText,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
              actions: [
                if (!isProvisioning)
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                if (!isProvisioning)
                  ElevatedButton(
                    onPressed: () async {
                      setDialogState(() {
                        isProvisioning = true;
                        progress = 0.05;
                        statusText = 'Checking active academic years...';
                      });

                      try {
                        final apiClient = ref.read(apiClientProvider);
                        if (_academicYears.isEmpty) {
                          throw Exception('Please create an active Academic Year first in your super-admin panel.');
                        }
                        
                        final String activeYearId = _academicYears.first['id'];

                        // 1. Define CBSE Classes & Streams
                        final List<Map<String, String>> classTemplates = [];
                        for (int i = 1; i <= 10; i++) {
                          classTemplates.add({'name': 'Class $i', 'code': 'CL$i'});
                        }
                        classTemplates.addAll([
                          {'name': 'Class 11 - Science', 'code': '11-SCI'},
                          {'name': 'Class 11 - Commerce', 'code': '11-COM'},
                          {'name': 'Class 11 - Humanities', 'code': '11-HUM'},
                          {'name': 'Class 12 - Science', 'code': '12-SCI'},
                          {'name': 'Class 12 - Commerce', 'code': '12-COM'},
                          {'name': 'Class 12 - Humanities', 'code': '12-HUM'},
                        ]);

                        // 2. Define CBSE Subjects
                        final List<Map<String, String>> subjectTemplates = [
                          {'name': 'English Core', 'code': 'ENG'},
                          {'name': 'Hindi Literature', 'code': 'HIN'},
                          {'name': 'Mathematics', 'code': 'MAT'},
                          {'name': 'Science & Tech', 'code': 'SCI'},
                          {'name': 'Social Studies', 'code': 'SST'},
                          {'name': 'Physics', 'code': 'PHY'},
                          {'name': 'Chemistry', 'code': 'CHE'},
                          {'name': 'Biology', 'code': 'BIO'},
                          {'name': 'Accountancy', 'code': 'ACC'},
                          {'name': 'Business Studies', 'code': 'BST'},
                          {'name': 'Economics', 'code': 'ECO'},
                          {'name': 'History', 'code': 'HIS'},
                          {'name': 'Geography', 'code': 'GEO'},
                          {'name': 'Political Science', 'code': 'POL'},
                          {'name': 'Computer Science', 'code': 'CS'},
                        ];

                        // 3. Create Subjects
                        final Map<String, String> createdSubjects = {};
                        int itemIndex = 0;
                        for (final sub in subjectTemplates) {
                          itemIndex++;
                          setDialogState(() {
                            progress = 0.05 + (0.25 * (itemIndex / subjectTemplates.length));
                            statusText = 'Creating Subject: ${sub['name']}...';
                          });

                          try {
                            final res = await apiClient.dio.post('/api/subjects', data: sub);
                            if (res.statusCode == 201 || res.data['success'] == true) {
                              createdSubjects[sub['name']!] = res.data['data']['id'];
                            }
                          } catch (_) {
                            // If subject already exists, fetch it from existing
                            final exist = _subjects.firstWhere((s) => s['name'] == sub['name'], orElse: () => null);
                            if (exist != null) {
                              createdSubjects[sub['name']!] = exist['id'];
                            }
                          }
                        }

                        // 4. Create Classes
                        final Map<String, String> createdClasses = {};
                        itemIndex = 0;
                        for (final cls in classTemplates) {
                          itemIndex++;
                          setDialogState(() {
                            progress = 0.3 + (0.3 * (itemIndex / classTemplates.length));
                            statusText = 'Creating Class: ${cls['name']}...';
                          });

                          try {
                            final res = await apiClient.dio.post('/api/classes', data: cls);
                            if (res.statusCode == 201 || res.data['success'] == true) {
                              createdClasses[cls['name']!] = res.data['data']['id'];
                            }
                          } catch (_) {
                            final exist = _classes.firstWhere((c) => c['name'] == cls['name'], orElse: () => null);
                            if (exist != null) {
                              createdClasses[cls['name']!] = exist['id'];
                            }
                          }
                        }

                        // 5. Create Sections A and B for all classes
                        itemIndex = 0;
                        for (final clsName in createdClasses.keys) {
                          itemIndex++;
                          setDialogState(() {
                            progress = 0.6 + (0.2 * (itemIndex / createdClasses.length));
                            statusText = 'Creating sections for $clsName...';
                          });

                          final classId = createdClasses[clsName]!;
                          for (final secName in ['A', 'B']) {
                            try {
                              await apiClient.dio.post('/api/sections', data: {
                                'classId': classId,
                                'name': secName,
                              });
                            } catch (_) {}
                          }
                        }

                        // 6. Map Subjects to Classes
                        setDialogState(() {
                          progress = 0.85;
                          statusText = 'Mapping subjects to classes...';
                        });

                        for (final clsName in createdClasses.keys) {
                          final classId = createdClasses[clsName]!;
                          final List<String> subjectsToMap = [];

                          if (clsName.startsWith('Class 11 - Science') || clsName.startsWith('Class 12 - Science')) {
                            subjectsToMap.addAll(['English Core', 'Physics', 'Chemistry', 'Mathematics', 'Biology', 'Computer Science']);
                          } else if (clsName.startsWith('Class 11 - Commerce') || clsName.startsWith('Class 12 - Commerce')) {
                            subjectsToMap.addAll(['English Core', 'Accountancy', 'Business Studies', 'Economics', 'Mathematics']);
                          } else if (clsName.startsWith('Class 11 - Humanities') || clsName.startsWith('Class 12 - Humanities')) {
                            subjectsToMap.addAll(['English Core', 'Hindi Literature', 'History', 'Geography', 'Political Science', 'Economics']);
                          } else {
                            // Class 1 to 10
                            subjectsToMap.addAll(['English Core', 'Hindi Literature', 'Mathematics', 'Science & Tech', 'Social Studies']);
                          }

                          for (final subName in subjectsToMap) {
                            final subjectId = createdSubjects[subName];
                            if (subjectId != null) {
                              try {
                                await apiClient.dio.post('/api/academic/assignments', data: {
                                  'type': 'class-subject',
                                  'classId': classId,
                                  'subjectId': subjectId,
                                });
                              } catch (_) {}
                            }
                          }
                        }

                        setDialogState(() {
                          progress = 1.0;
                          statusText = 'Curriculum set up successfully!';
                        });

                        await Future.delayed(const Duration(seconds: 1));
                        Navigator.pop(context);
                        _loadAllData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Indian school curriculum set up successfully!')),
                        );
                      } catch (e) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Wizard failed: ${e.toString()}')),
                        );
                      }
                    },
                    child: const Text('Confirm Setup'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Add Class Dialog ---
  void _showAddClassDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Class'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Class Name (e.g. Class 10) *'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                TextFormField(
                  controller: codeController,
                  decoration: const InputDecoration(labelText: 'Short Code (e.g. CL10)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  try {
                    final apiClient = ref.read(apiClientProvider);
                    final res = await apiClient.dio.post('/api/classes', data: {
                      'name': nameController.text.trim(),
                      'code': codeController.text.trim(),
                    });
                    if (res.statusCode == 201 || res.data['success'] == true) {
                      Navigator.pop(context);
                      _loadAllData();
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to create class')),
                    );
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  // --- Add Section Dialog ---
  void _showAddSectionDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    String? selectedClassId = _selectedClassIdForSections;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Section'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedClassId,
                      decoration: const InputDecoration(labelText: 'Class *'),
                      items: _classes.map((c) {
                        return DropdownMenuItem(value: c['id'] as String, child: Text(c['name'] ?? ''));
                      }).toList(),
                      onChanged: (v) => setDialogState(() => selectedClassId = v),
                    ),
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Section Name (e.g. A) *'),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate() && selectedClassId != null) {
                      try {
                        final apiClient = ref.read(apiClientProvider);
                        final res = await apiClient.dio.post('/api/sections', data: {
                          'classId': selectedClassId,
                          'name': nameController.text.trim().toUpperCase(),
                        });
                        if (res.statusCode == 201 || res.data['success'] == true) {
                          Navigator.pop(context);
                          _loadAllData();
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Failed to create section')),
                        );
                      }
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Add Subject Dialog ---
  void _showAddSubjectDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Subject'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Subject Name (e.g. English) *'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                TextFormField(
                  controller: codeController,
                  decoration: const InputDecoration(labelText: 'Subject Code (e.g. ENG101)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  try {
                    final apiClient = ref.read(apiClientProvider);
                    final res = await apiClient.dio.post('/api/subjects', data: {
                      'name': nameController.text.trim(),
                      'code': codeController.text.trim(),
                    });
                    if (res.statusCode == 201 || res.data['success'] == true) {
                      Navigator.pop(context);
                      _loadAllData();
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to create subject')),
                    );
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  // --- Map Class Subject Dialog ---
  void _showMapSubjectDialog() {
    String? selectedClassId;
    String? selectedSubjectId;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Map Subject to Class'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedClassId,
                    decoration: const InputDecoration(labelText: 'Select Class *'),
                    items: _classes.map((c) {
                      return DropdownMenuItem(value: c['id'] as String, child: Text(c['name'] ?? ''));
                    }).toList(),
                    onChanged: (v) => setDialogState(() => selectedClassId = v),
                  ),
                  DropdownButtonFormField<String>(
                    value: selectedSubjectId,
                    decoration: const InputDecoration(labelText: 'Select Subject *'),
                    items: _subjects.map((s) {
                      return DropdownMenuItem(value: s['id'] as String, child: Text(s['name'] ?? ''));
                    }).toList(),
                    onChanged: (v) => setDialogState(() => selectedSubjectId = v),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedClassId != null && selectedSubjectId != null) {
                      try {
                        final apiClient = ref.read(apiClientProvider);
                        final res = await apiClient.dio.post(
                          '/api/academic/assignments',
                          data: {
                            'type': 'class-subject',
                            'classId': selectedClassId,
                            'subjectId': selectedSubjectId,
                          },
                        );
                        if (res.statusCode == 201 || res.data['success'] == true) {
                          Navigator.pop(context);
                          _loadAllData();
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Failed to map subject (already mapped?)')),
                        );
                      }
                    }
                  },
                  child: const Text('Link'),
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
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Academic Configuration'),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.auto_awesome, color: Colors.amber),
              label: const Text('Quick CBSE Setup', style: TextStyle(color: Colors.white)),
              onPressed: _runCBSEQuickSetup,
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.school), text: 'Classes'),
              Tab(icon: Icon(Icons.grid_view), text: 'Sections'),
              Tab(icon: Icon(Icons.book), text: 'Subjects'),
            ],
          ),
        ),
        drawer: const AppNavigationDrawer(),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildClassesTab(),
                  _buildSectionsTab(),
                  _buildSubjectsTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildClassesTab() {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddClassDialog,
        tooltip: 'Add Class',
        child: const Icon(Icons.add),
      ),
      body: _classes.isEmpty
          ? const Center(child: Text('No classes configured yet.'))
          : ListView.builder(
              padding: AppSpacing.paddingM,
              itemCount: _classes.length,
              itemBuilder: (context, index) {
                final cls = _classes[index];
                final mappings = cls['subjects'] as List? ?? [];
                
                return Card(
                  child: ListTile(
                    title: Text(
                      cls['name'] ?? 'Class',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    subtitle: Text(
                      mappings.isEmpty
                          ? 'No subjects mapped'
                          : 'Subjects: ${mappings.map((m) => m['subject']?['name'] ?? '').join(", ")}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.link, color: Colors.blue),
                      tooltip: 'Map Subject',
                      onPressed: _showMapSubjectDialog,
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildSectionsTab() {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSectionDialog,
        tooltip: 'Add Section',
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: AppSpacing.paddingM,
            child: DropdownButtonFormField<String>(
              value: _selectedClassIdForSections,
              decoration: const InputDecoration(labelText: 'Filter Sections by Class'),
              items: _classes.map((c) {
                return DropdownMenuItem(value: c['id'] as String, child: Text(c['name'] ?? ''));
              }).toList(),
              onChanged: (classId) {
                if (classId != null) {
                  setState(() => _selectedClassIdForSections = classId);
                  _fetchSections(classId);
                }
              },
            ),
          ),
          Expanded(
            child: _sections.isEmpty
                ? const Center(child: Text('No sections configured for this class.'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _sections.length,
                    itemBuilder: (context, index) {
                      final sec = _sections[index];
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.door_sliding_outlined)),
                          title: Text('Section ${sec['name'] ?? ''}'),
                          subtitle: Text('ID: ${sec['id']}'),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectsTab() {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSubjectDialog,
        tooltip: 'Add Subject',
        child: const Icon(Icons.add),
      ),
      body: _subjects.isEmpty
          ? const Center(child: Text('No subjects configured yet.'))
          : ListView.builder(
              padding: AppSpacing.paddingM,
              itemCount: _subjects.length,
              itemBuilder: (context, index) {
                final sub = _subjects[index];
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.menu_book)),
                    title: Text(
                      sub['name'] ?? 'Subject',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('Code: ${sub['code'] ?? 'N/A'}'),
                  ),
                );
              },
            ),
    );
  }
}
