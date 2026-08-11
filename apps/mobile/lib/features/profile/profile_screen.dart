import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_notifier.dart';
import '../../core/theme/theme_provider.dart';
import '../../features/bootstrap/bootstrap_notifier.dart';
import '../../shared/widgets/app_navigation_drawer.dart';
import '../../core/theme/spacing.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrapState = ref.watch(bootstrapProvider);
    final user = bootstrapState.config?.user;
    final themeMode = ref.watch(themeModeProvider);

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
      ),
      drawer: const AppNavigationDrawer(),
      body: SingleChildScrollView(
        padding: AppSpacing.paddingM,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSpacing.heightL,
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    child: Text(
                      user.email.substring(0, 2).toUpperCase(),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  AppSpacing.heightM,
                  Text(
                    user.email,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  AppSpacing.heightXS,
                  Text(
                    user.role.toUpperCase(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            AppSpacing.heightXL,
            Text(
              'App Settings',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            AppSpacing.heightS,
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Dark Theme Mode'),
                    subtitle: const Text('Toggle between light and dark visual aesthetics'),
                    secondary: const Icon(Icons.palette_outlined),
                    value: isDark,
                    onChanged: (val) {
                      ref.read(themeModeProvider.notifier).toggleTheme(val);
                    },
                  ),
                ],
              ),
            ),
            AppSpacing.heightXL,
            ElevatedButton.icon(
              onPressed: () {
                ref.read(authProvider.notifier).logout();
              },
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out of Portal'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
