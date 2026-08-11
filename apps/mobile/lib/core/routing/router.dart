import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_notifier.dart';
import '../auth/auth_state.dart';
import '../../features/bootstrap/bootstrap_notifier.dart';
import '../../features/auth/login_screen.dart';
import '../../features/bootstrap/bootstrap_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/students/students_screen.dart';
import '../../features/faculty/faculty_screen.dart';
import '../../features/attendance/attendance_screen.dart';
import '../../features/homework/homework_screen.dart';
import '../../features/timetable/timetable_screen.dart';
import '../../features/notices/notices_screen.dart';
import '../../features/exams/exams_screen.dart';
import '../../features/remarks/remarks_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../shared/widgets/app_navigation_drawer.dart';

// Shell Navigation screens placeholder.
// We will create the actual dashboard and screens in Milestones 7-11.
// Using temporary placeholder Scaffold widgets for compilation safety.

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);
  final bootstrapState = ref.watch(bootstrapProvider);

  return GoRouter(
    initialLocation: '/bootstrap',
    redirect: (context, state) {
      final isLoggedIn = authState.status == AuthStatus.authenticated;
      final isBootstrapped = bootstrapState.status == BootstrapStatus.success;
      final isLoggingIn = state.matchedLocation == '/login';
      final isBootstrapping = state.matchedLocation == '/bootstrap';

      // 1. Unauthenticated users must go to Login
      if (!isLoggedIn && !isLoggingIn) {
        return '/login';
      }

      // 2. Authenticated users must bootstrap configuration
      if (isLoggedIn && !isBootstrapped && !isBootstrapping) {
        return '/bootstrap';
      }

      // 3. Prevent loop redirection if already logged in and bootstrapped
      if (isLoggedIn && isBootstrapped && (isLoggingIn || isBootstrapping)) {
        return '/dashboard';
      }

      // 4. Feature Flag Route Guards
      final featureFlags = bootstrapState.config?.featureFlags;
      if (featureFlags != null) {
        final path = state.matchedLocation;
        if (path == '/attendance' && !featureFlags.attendance) return '/dashboard';
        if (path == '/homework' && !featureFlags.homework) return '/dashboard';
        if (path == '/timetable' && !featureFlags.timetable) return '/dashboard';
        if (path == '/notices' && !featureFlags.notices) return '/dashboard';
        if (path == '/remarks' && !featureFlags.remarks) return '/dashboard';
        if (path == '/exams' && !featureFlags.exams) return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/bootstrap',
        builder: (context, state) => BootstrapScreen(
          onBootstrapComplete: () {
            // Once bootstrap resolves, router automatically triggers redirect to /dashboard
          },
        ),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/students',
        builder: (context, state) => const StudentsScreen(),
      ),
      GoRoute(
        path: '/faculty',
        builder: (context, state) => const FacultyScreen(),
      ),
      GoRoute(
        path: '/attendance',
        builder: (context, state) => const AttendanceScreen(),
      ),
      GoRoute(
        path: '/homework',
        builder: (context, state) => const HomeworkScreen(),
      ),
      GoRoute(
        path: '/timetable',
        builder: (context, state) => const TimetableScreen(),
      ),
      GoRoute(
        path: '/notices',
        builder: (context, state) => const NoticesScreen(),
      ),
      GoRoute(
        path: '/exams',
        builder: (context, state) => const ExamsScreen(),
      ),
      GoRoute(
        path: '/results',
        builder: (context, state) => const ExamsScreen(),
      ),
      GoRoute(
        path: '/remarks',
        builder: (context, state) => const RemarksScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
    ],
  );
});

class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      drawer: const AppNavigationDrawer(),
      body: Center(
        child: Text('Welcome to $title screen'),
      ),
    );
  }
}
