import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'bootstrap_notifier.dart';
import '../../core/theme/spacing.dart';

class BootstrapScreen extends ConsumerStatefulWidget {
  final VoidCallback onBootstrapComplete;
  
  const BootstrapScreen({
    super.key,
    required this.onBootstrapComplete,
  });

  @override
  ConsumerState<BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends ConsumerState<BootstrapScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(bootstrapProvider.notifier).initializeBootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bootstrapState = ref.watch(bootstrapProvider);

    // Listen for bootstrap success to trigger navigation callback
    ref.listen<BootstrapState>(bootstrapProvider, (previous, next) {
      if (next.status == BootstrapStatus.success) {
        widget.onBootstrapComplete();
      }
    });

    if (bootstrapState.status == BootstrapStatus.forceUpdate) {
      return _buildForceUpdateScreen(context);
    }

    if (bootstrapState.status == BootstrapStatus.error) {
      return _buildErrorScreen(context, bootstrapState.errorMessage);
    }

    return _buildLoadingScreen(context);
  }

  Widget _buildLoadingScreen(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
            AppSpacing.heightL,
            Text(
              'Initializing Portal...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForceUpdateScreen(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: AppSpacing.paddingL,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.system_update_alt,
              size: 80,
              color: Colors.orange,
            ),
            AppSpacing.heightL,
            Text(
              'App Update Required',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            AppSpacing.heightS,
            Text(
              'Your version of the app is no longer supported. Please download the latest version from the app store to continue.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
              textAlign: TextAlign.center,
            ),
            AppSpacing.heightXL,
            ElevatedButton(
              onPressed: () {
                // In production, this would open App Store or Play Store
              },
              child: const Text('Update Now'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen(BuildContext context, String? message) {
    return Scaffold(
      body: Padding(
        padding: AppSpacing.paddingL,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.cloud_off,
              size: 80,
              color: Theme.of(context).colorScheme.error,
            ),
            AppSpacing.heightL,
            Text(
              'Connection Error',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            AppSpacing.heightS,
            Text(
              message ?? 'Something went wrong while connecting to school servers.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
              textAlign: TextAlign.center,
            ),
            AppSpacing.heightXL,
            ElevatedButton(
              onPressed: () {
                ref.read(bootstrapProvider.notifier).initializeBootstrap();
              },
              child: const Text('Retry Connection'),
            ),
          ],
        ),
      ),
    );
  }
}
