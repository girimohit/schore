import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/auth/auth_notifier.dart';
import 'core/auth/auth_state.dart';
import 'core/theme/theme_provider.dart';
import 'features/auth/login_screen.dart';
import 'features/bootstrap/bootstrap_screen.dart';

void main() {
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(authProvider.notifier).checkSession();
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final lightTheme = ref.watch(appThemeProvider(false));
    final darkTheme = ref.watch(appThemeProvider(true));
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: 'Schore ERP',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      home: _resolveHomeWidget(authState),
    );
  }

  Widget _resolveHomeWidget(AuthState authState) {
    switch (authState.status) {
      case AuthStatus.initial:
      case AuthStatus.loading:
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      case AuthStatus.authenticated:
        return BootstrapScreen(
          onBootstrapComplete: () {
            // Placeholder: Routing navigation will manage this in Milestone 6
          },
        );
      case AuthStatus.unauthenticated:
      case AuthStatus.error:
        return const LoginScreen();
    }
  }
}
