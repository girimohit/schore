import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/bootstrap/bootstrap_notifier.dart';
import '../../shared/widgets/app_navigation_drawer.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/radius.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrapState = ref.watch(bootstrapProvider);
    final user = bootstrapState.config?.user;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final role = user.role.toUpperCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Schore Portal'),
      ),
      drawer: const AppNavigationDrawer(),
      body: SingleChildScrollView(
        padding: AppSpacing.paddingM,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Welcome Greeting Header with dynamic gradient background banner
            _buildWelcomeBanner(context, user.email, role),
            AppSpacing.heightL,

            // Role-based main dashboard body
            if (role == 'ADMIN' || role == 'SUPERADMIN')
              _buildAdminDashboard(context)
            else if (role == 'FACULTY')
              _buildFacultyDashboard(context)
            else
              _buildStudentDashboard(context),

            AppSpacing.heightL,

            // Global Notices Panel (Shared by all roles)
            _buildRecentNoticesSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner(BuildContext context, String email, String role) {
    final theme = Theme.of(context);
    return Container(
      padding: AppSpacing.paddingL,
      decoration: BoxDecoration(
        borderRadius: AppRadius.borderL,
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back,',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white70,
            ),
          ),
          AppSpacing.heightXS,
          Text(
            email.split('@')[0],
            style: theme.textTheme.headlineLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          AppSpacing.heightS,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: AppRadius.borderS,
            ),
            child: Text(
              role,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        AppSpacing.heightM,
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                title: 'Attendance',
                value: '94.2%',
                icon: Icons.calendar_month,
                color: Colors.blue,
              ),
            ),
            AppSpacing.widthM,
            Expanded(
              child: _buildStatCard(
                context,
                title: 'Pending Tasks',
                value: '3 Tasks',
                icon: Icons.assignment_late_outlined,
                color: Colors.orange,
              ),
            ),
          ],
        ),
        AppSpacing.heightM,
        _buildDashboardSectionHeader(context, 'Today\'s Timetable'),
        Card(
          child: Padding(
            padding: AppSpacing.paddingM,
            child: Column(
              children: [
                _buildTimetableItem('09:00 AM', 'Mathematics', 'Room 101'),
                const Divider(),
                _buildTimetableItem('10:30 AM', 'Physics', 'Room 102'),
                const Divider(),
                _buildTimetableItem('01:00 PM', 'Chemistry', 'Lab 2'),
              ],
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
        Text(
          'Teaching Console',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        AppSpacing.heightM,
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                title: 'Classes Today',
                value: '4 Periods',
                icon: Icons.schedule,
                color: Colors.deepPurple,
              ),
            ),
            AppSpacing.widthM,
            Expanded(
              child: _buildStatCard(
                context,
                title: 'Unmarked Attendance',
                value: '1 Class',
                icon: Icons.pending_actions,
                color: Colors.red,
              ),
            ),
          ],
        ),
        AppSpacing.heightM,
        _buildDashboardSectionHeader(context, 'Faculty Shortcuts'),
        Row(
          children: [
            Expanded(
              child: _buildShortcutButton(
                context,
                label: 'Mark Attendance',
                icon: Icons.check_circle_outline,
                color: Colors.green,
              ),
            ),
            AppSpacing.widthM,
            Expanded(
              child: _buildShortcutButton(
                context,
                label: 'Post Homework',
                icon: Icons.post_add,
                color: Colors.blue,
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
        Text(
          'Administration Overview',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        AppSpacing.heightM,
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                title: 'Total Students',
                value: '1,240',
                icon: Icons.people_outline,
                color: Colors.indigo,
              ),
            ),
            AppSpacing.widthM,
            Expanded(
              child: _buildStatCard(
                context,
                title: 'Total Faculty',
                value: '84',
                icon: Icons.badge_outlined,
                color: Colors.teal,
              ),
            ),
          ],
        ),
        AppSpacing.heightM,
        _buildDashboardSectionHeader(context, 'Quick Management Actions'),
        Card(
          child: Padding(
            padding: AppSpacing.paddingM,
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.spaceEvenly,
              children: [
                _buildCircularAction(context, Icons.person_add_alt, 'Add Student'),
                _buildCircularAction(context, Icons.person_add_alt_1, 'Add Faculty'),
                _buildCircularAction(context, Icons.settings_input_component, 'Config Class'),
                _buildCircularAction(context, Icons.campaign, 'Send Notice'),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDashboardSectionHeader(context, 'Recent Notices'),
        Card(
          child: Padding(
            padding: AppSpacing.paddingM,
            child: Column(
              children: [
                _buildNoticeItem(
                  'Annual Sports Meet 2026',
                  'Register for track events by next Friday.',
                  '2 hours ago',
                ),
                const Divider(),
                _buildNoticeItem(
                  'Mid-Term Exam Schedule',
                  'Exams start from 20th September. Download timetables.',
                  '1 day ago',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // REUSABLE HELPER COMPONENT BLOCKS
  // ─────────────────────────────────────────────
  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: AppSpacing.paddingM,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                ),
                Icon(icon, color: color, size: 20),
              ],
            ),
            AppSpacing.heightS,
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildTimetableItem(String time, String subject, String room) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            time,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                subject,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                time,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          AppSpacing.heightXS,
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      color: color.withOpacity(0.08),
      child: InkWell(
        borderRadius: AppRadius.borderM,
        onTap: () {},
        child: Padding(
          padding: AppSpacing.paddingM,
          child: Column(
            children: [
              Icon(icon, color: color, size: 30),
              AppSpacing.heightS,
              Text(
                label,
                style: TextStyle(fontWeight: FontWeight.w600, color: color, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCircularAction(BuildContext context, IconData icon, String label) {
    return SizedBox(
      width: 70,
      child: Column(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.08),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          AppSpacing.heightXS,
          Text(
            label,
            style: const TextStyle(fontSize: 11),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}
