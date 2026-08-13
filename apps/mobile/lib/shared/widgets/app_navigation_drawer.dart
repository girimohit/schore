import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_notifier.dart';
import '../../features/bootstrap/bootstrap_notifier.dart';

class AppNavigationDrawer extends ConsumerWidget {
  const AppNavigationDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrapState = ref.watch(bootstrapProvider);
    final user = bootstrapState.config?.user;
    final flags = bootstrapState.config?.featureFlags;

    if (user == null || flags == null) {
      return const Drawer(child: Center(child: CircularProgressIndicator()));
    }

    final role = user.role.toUpperCase();

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                user.email.substring(0, 2).toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            accountName: Text(
              role,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(user.email),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard_outlined),
            title: const Text('Dashboard'),
            onTap: () {
              Navigator.pop(context);
              context.go('/dashboard');
            },
          ),
          
          // ADMIN-ONLY Modules
          if (role == 'ADMIN' || role == 'SUPERADMIN' || role == 'SCHOOL_ADMIN') ...[
            ListTile(
              leading: const Icon(Icons.people_outline),
              title: const Text('Students'),
              onTap: () {
                Navigator.pop(context);
                context.go('/students');
              },
            ),
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: const Text('Faculty'),
              onTap: () {
                Navigator.pop(context);
                context.go('/faculty');
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_suggest_outlined),
              title: const Text('Academic Setup'),
              onTap: () {
                Navigator.pop(context);
                context.go('/academic-settings');
              },
            ),
          ],

          // FEATURE-FLAGGED Modules
          if (flags.attendance)
            ListTile(
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('Attendance'),
              onTap: () {
                Navigator.pop(context);
                context.go('/attendance');
              },
            ),

          if (flags.homework && role != 'ADMIN' && role != 'SUPERADMIN' && role != 'SCHOOL_ADMIN')
            ListTile(
              leading: const Icon(Icons.assignment_outlined),
              title: const Text('Homework'),
              onTap: () {
                Navigator.pop(context);
                context.go('/homework');
              },
            ),

          if (flags.timetable)
            ListTile(
              leading: const Icon(Icons.schedule_outlined),
              title: const Text('Timetable'),
              onTap: () {
                Navigator.pop(context);
                context.go('/timetable');
              },
            ),

          if (flags.exams && (role == 'ADMIN' || role == 'SUPERADMIN' || role == 'SCHOOL_ADMIN'))
            ListTile(
              leading: const Icon(Icons.quiz_outlined),
              title: const Text('Exams'),
              onTap: () {
                Navigator.pop(context);
                context.go('/exams');
              },
            ),

          // Results access (Exams flag check)
          if (flags.exams)
            ListTile(
              leading: const Icon(Icons.grade_outlined),
              title: const Text('Results'),
              onTap: () {
                Navigator.pop(context);
                context.go('/results');
              },
            ),

          if (flags.notices)
            ListTile(
              leading: const Icon(Icons.campaign_outlined),
              title: const Text('Notices'),
              onTap: () {
                Navigator.pop(context);
                context.go('/notices');
              },
            ),

          if (flags.remarks)
            ListTile(
              leading: const Icon(Icons.rate_review_outlined),
              title: const Text('Remarks'),
              onTap: () {
                Navigator.pop(context);
                context.go('/remarks');
              },
            ),

          const Divider(),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Profile'),
            onTap: () {
              Navigator.pop(context);
              context.go('/profile');
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              ref.read(authProvider.notifier).logout();
            },
          ),
        ],
      ),
    );
  }
}
