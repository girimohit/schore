import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_notifier.dart';
import '../../features/bootstrap/bootstrap_notifier.dart';
import '../../shared/widgets/app_navigation_drawer.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/radius.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic> _stats = {};
  List<dynamic> _timetable = [];
  List<dynamic> _notices = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _fetchDashboardData());
  }

  Future<void> _fetchDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.dio.get('/api/school/metrics');
      if (response.statusCode == 200) {
        final data = response.data['data'] ?? {};
        setState(() {
          _stats = data['stats'] ?? {};
          _timetable = data['timetable'] ?? [];
          _notices = data['recentNotices'] ?? [];
        });
      } else {
        setState(() {
          _errorMessage = response.data['message'] ?? 'Failed to load dashboard metrics';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not retrieve live dashboard stats. Please try again.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bootstrapState = ref.watch(bootstrapProvider);
    final user = bootstrapState.config?.user;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final role = user.role.toUpperCase();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          bootstrapState.config?.school.name ?? 'Schore Portal',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchDashboardData,
          )
        ],
      ),
      drawer: const AppNavigationDrawer(),
      body: RefreshIndicator(
        onRefresh: _fetchDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppSpacing.paddingM,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome Header
              _buildWelcomeBanner(context, user.email, role),
              AppSpacing.heightL,

              if (_errorMessage != null) ...[
                Card(
                  color: theme.colorScheme.error.withOpacity(0.08),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: theme.colorScheme.error.withOpacity(0.3)),
                  ),
                  child: Padding(
                    padding: AppSpacing.paddingM,
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: theme.colorScheme.error),
                        AppSpacing.widthM,
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                AppSpacing.heightM,
              ],

              // Role Dashboard Stats
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40.0),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                if (role == 'ADMIN' || role == 'SUPERADMIN' || role == 'SCHOOL_ADMIN')
                  _buildAdminDashboard(context)
                else if (role == 'FACULTY')
                  _buildFacultyDashboard(context)
                else
                  _buildStudentDashboard(context),

                AppSpacing.heightL,

                // Shared Dynamic Notices Board
                _buildRecentNoticesSection(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner(BuildContext context, String email, String role) {
    final theme = Theme.of(context);
    final displayRole = role == 'SCHOOL_ADMIN' ? 'School Administrator' : role;
    return Container(
      padding: AppSpacing.paddingL,
      decoration: BoxDecoration(
        borderRadius: AppRadius.borderL,
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.secondary.withOpacity(0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back,',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          AppSpacing.heightXS,
          Text(
            email.split('@')[0].replaceAll('_', ' '),
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          AppSpacing.heightM,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              displayRole,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // STUDENT DASHBOARD
  // ─────────────────────────────────────────────
  Widget _buildStudentDashboard(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDashboardSectionHeader(context, 'Your Progress'),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                title: 'Attendance',
                value: _stats['attendanceRate'] ?? '0.0%',
                icon: Icons.calendar_month_outlined,
                gradient: [Colors.teal.shade400, Colors.emerald.shade600],
              ),
            ),
            AppSpacing.widthM,
            Expanded(
              child: _buildStatCard(
                context,
                title: 'Pending Tasks',
                value: _stats['pendingTasks'] ?? '0 Tasks',
                icon: Icons.assignment_late_outlined,
                gradient: [Colors.orange.shade400, Colors.red.shade600],
              ),
            ),
          ],
        ),
        AppSpacing.heightL,
        _buildDashboardSectionHeader(context, 'Student Panel'),
        Row(
          children: [
            Expanded(
              child: _buildShortcutButton(
                context,
                label: 'Attendance logs',
                icon: Icons.done_all,
                color: Colors.emerald,
                onTap: () => context.push('/attendance'),
              ),
            ),
            AppSpacing.widthM,
            Expanded(
              child: _buildShortcutButton(
                context,
                label: 'Timetable',
                icon: Icons.schedule_outlined,
                color: Colors.indigo,
                onTap: () => context.push('/timetable'),
              ),
            ),
          ],
        ),
        AppSpacing.heightM,
        Row(
          children: [
            Expanded(
              child: _buildShortcutButton(
                context,
                label: 'Homework Tasks',
                icon: Icons.assignment_outlined,
                color: Colors.orange,
                onTap: () => context.push('/homework'),
              ),
            ),
            AppSpacing.widthM,
            Expanded(
              child: _buildShortcutButton(
                context,
                label: 'Exam Results',
                icon: Icons.analytics_outlined,
                color: Colors.purple,
                onTap: () => context.push('/exams'),
              ),
            ),
          ],
        ),
        AppSpacing.heightL,
        _buildDashboardSectionHeader(context, "Today's Schedule"),
        if (_timetable.isEmpty)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: const Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(child: Text('No classes scheduled for today.')),
            ),
          )
        else
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: AppSpacing.paddingM,
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _timetable.length,
                separatorBuilder: (context, idx) => const Divider(height: 24),
                itemBuilder: (context, index) {
                  final item = _timetable[index];
                  return _buildTimetableItem(
                    item['time'] ?? '',
                    item['subject'] ?? '',
                    item['room'] ?? '',
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // FACULTY DASHBOARD
  // ─────────────────────────────────────────────
  Widget _buildFacultyDashboard(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDashboardSectionHeader(context, 'Teaching Overview'),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                title: 'Classes Today',
                value: _stats['classesToday'] ?? '0 Periods',
                icon: Icons.schedule_outlined,
                gradient: [Colors.indigo.shade400, Colors.deepPurple.shade600],
              ),
            ),
            AppSpacing.widthM,
            Expanded(
              child: _buildStatCard(
                context,
                title: 'Unmarked Attendance',
                value: _stats['unmarkedAttendance'] ?? '0 Classes',
                icon: Icons.pending_actions_outlined,
                gradient: [Colors.red.shade400, Colors.pink.shade600],
              ),
            ),
          ],
        ),
        AppSpacing.heightL,
        _buildDashboardSectionHeader(context, 'Faculty shortcuts'),
        Row(
          children: [
            Expanded(
              child: _buildShortcutButton(
                context,
                label: 'Mark Attendance',
                icon: Icons.check_circle_outline,
                color: Colors.emerald,
                onTap: () => context.push('/attendance'),
              ),
            ),
            AppSpacing.widthM,
            Expanded(
              child: _buildShortcutButton(
                context,
                label: 'Post Homework',
                icon: Icons.post_add_outlined,
                color: Colors.blue,
                onTap: () => context.push('/homework'),
              ),
            ),
          ],
        ),
        AppSpacing.heightM,
        Row(
          children: [
            Expanded(
              child: _buildShortcutButton(
                context,
                label: 'Timetable schedule',
                icon: Icons.date_range_outlined,
                color: Colors.amber.shade800,
                onTap: () => context.push('/timetable'),
              ),
            ),
            AppSpacing.widthM,
            Expanded(
              child: _buildShortcutButton(
                context,
                label: 'Remarks panel',
                icon: Icons.chat_bubble_outline_outlined,
                color: Colors.purple,
                onTap: () => context.push('/remarks'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // ADMIN DASHBOARD
  // ─────────────────────────────────────────────
  Widget _buildAdminDashboard(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDashboardSectionHeader(context, 'Administration Stats'),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                title: 'Total Students',
                value: _stats['totalStudents']?.toString() ?? '0',
                icon: Icons.people_outline,
                gradient: [Colors.blue.shade400, Colors.indigo.shade600],
              ),
            ),
            AppSpacing.widthM,
            Expanded(
              child: _buildStatCard(
                context,
                title: 'Total Faculty',
                value: _stats['totalFaculty']?.toString() ?? '0',
                icon: Icons.badge_outlined,
                gradient: [Colors.teal.shade400, Colors.cyan.shade600],
              ),
            ),
          ],
        ),
        AppSpacing.heightM,
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                title: 'Total Classes',
                value: _stats['totalClasses']?.toString() ?? '0',
                icon: Icons.school_outlined,
                gradient: [Colors.purple.shade400, Colors.deepPurple.shade600],
              ),
            ),
            AppSpacing.widthM,
            Expanded(
              child: _buildStatCard(
                context,
                title: 'Unmarked Attendance',
                value: _stats['unmarkedAttendance']?.toString() ?? '0',
                icon: Icons.assignment_late_outlined,
                gradient: [Colors.red.shade400, Colors.orange.shade600],
              ),
            ),
          ],
        ),
        AppSpacing.heightL,
        _buildDashboardSectionHeader(context, 'Quick Management Actions'),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: AppSpacing.paddingM,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCircularAction(context, Icons.person_add_alt_outlined, 'Students', () => context.push('/students')),
                _buildCircularAction(context, Icons.person_add_alt_1_outlined, 'Faculty', () => context.push('/faculty')),
                _buildCircularAction(context, Icons.settings_input_component_outlined, 'Setup Class', () => context.push('/academic-settings')),
                _buildCircularAction(context, Icons.campaign_outlined, 'Notices', () => context.push('/notices')),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // SHARED NOTICES WIDGET
  // ─────────────────────────────────────────────
  Widget _buildRecentNoticesSection(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDashboardSectionHeader(context, 'Recent Notices'),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: AppSpacing.paddingM,
            child: _notices.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20.0),
                    child: Center(
                      child: Text(
                        'All caught up! No recent notices.',
                        style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _notices.length,
                    separatorBuilder: (context, idx) => const Divider(height: 24),
                    itemBuilder: (context, index) {
                      final notice = _notices[index];
                      final diff = DateTime.now().difference(DateTime.parse(notice['createdAt']));
                      String timeLabel = '${diff.inDays}d ago';
                      if (diff.inDays == 0) {
                        timeLabel = diff.inHours > 0 ? '${diff.inHours}h ago' : '${diff.inMinutes}m ago';
                      }

                      return _buildNoticeItem(
                        notice['title'] ?? '',
                        notice['content'] ?? '',
                        timeLabel,
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // REUSABLE HELPER BLOCKS
  // ─────────────────────────────────────────────
  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required List<Color> gradient,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: AppSpacing.paddingM,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient.last.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, color: Colors.white, size: 20),
            ],
          ),
          AppSpacing.heightM,
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 24,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8, left: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.2,
            ),
      ),
    );
  }

  Widget _buildTimetableItem(String time, String subject, String room) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              time,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
                fontSize: 12,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                subject,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 2),
              Text(
                room,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeItem(String title, String subtitle, String time) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                time,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildShortcutButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              AppSpacing.widthM,
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCircularAction(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8.0),
        width: 80,
        child: Column(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: theme.colorScheme.primary.withOpacity(0.08),
              child: Icon(icon, color: theme.colorScheme.primary, size: 24),
            ),
            AppSpacing.heightXS,
            Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface.withOpacity(0.8)),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
