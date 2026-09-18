import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/auth/auth_notifier.dart';
import '../../core/network/api_client.dart';
import '../../shared/models/bootstrap_config.dart';
import '../dashboard/dashboard_notifier.dart';

enum BootstrapStatus { initial, loading, success, forceUpdate, error }

class BootstrapState {
  final BootstrapStatus status;
  final BootstrapConfig? config;
  final String? errorMessage;

  const BootstrapState({
    required this.status,
    this.config,
    this.errorMessage,
  });

  const BootstrapState.initial()
      : status = BootstrapStatus.initial,
        config = null,
        errorMessage = null;

  BootstrapState copyWith({
    BootstrapStatus? status,
    BootstrapConfig? config,
    String? errorMessage,
  }) {
    return BootstrapState(
      status: status ?? this.status,
      config: config ?? this.config,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

final bootstrapProvider = StateNotifierProvider<BootstrapNotifier, BootstrapState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return BootstrapNotifier(apiClient, ref);
});

class BootstrapNotifier extends StateNotifier<BootstrapState> {
  final ApiClient _apiClient;
  final Ref _ref;
  static const String _bootstrapCacheKey = 'bootstrap_cache';

  BootstrapNotifier(this._apiClient, this._ref) : super(const BootstrapState.initial());

  Future<void> initializeBootstrap() async {
    state = state.copyWith(status: BootstrapStatus.loading);
    
    // 1. Try to load cached config first for immediate render (Offline Support)
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString(_bootstrapCacheKey);
    if (cachedData != null) {
      try {
        final config = BootstrapConfig.fromJson(jsonDecode(cachedData));
        
        if (config.appVersion.forceUpdate) {
          state = state.copyWith(status: BootstrapStatus.forceUpdate, config: config);
          return;
        }

        state = state.copyWith(status: BootstrapStatus.success, config: config);
        
        // Eagerly prefetch dashboard metrics in background
        if (config.user != null) {
          _ref.read(dashboardProvider.notifier).fetchDashboardData();
        }
        
        // Refresh in background
        _fetchRemoteBootstrap();
        return;
      } catch (_) {
        // Bad cache, proceed to remote
      }
    }

    // 2. Fetch from remote
    await _fetchRemoteBootstrap();
  }

  Future<void> _fetchRemoteBootstrap() async {
    try {
      final response = await _apiClient.dio.get('/api/bootstrap');
      
      if (response.statusCode == 200) {
        final config = BootstrapConfig.fromJson(response.data['data']);
        
        // Cache the response
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_bootstrapCacheKey, jsonEncode(config.toJson()));

        if (config.appVersion.forceUpdate) {
          state = state.copyWith(status: BootstrapStatus.forceUpdate, config: config);
          return;
        }

        state = state.copyWith(status: BootstrapStatus.success, config: config);

        // Eagerly prefetch dashboard metrics if user is authenticated
        if (config.user != null) {
          _ref.read(dashboardProvider.notifier).fetchDashboardData();
        }
      } else {
        if (state.config == null) {
          state = state.copyWith(
            status: BootstrapStatus.error,
            errorMessage: response.data['message'] ?? 'Failed to initialize app settings',
          );
        }
      }
    } catch (e) {
      if (state.config == null) {
        state = state.copyWith(
          status: BootstrapStatus.error,
          errorMessage: 'Unable to reach server. Please check your internet connection.',
        );
      }
    }
  }

  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_bootstrapCacheKey);
    _ref.read(dashboardProvider.notifier).clear();
    state = const BootstrapState.initial();
  }
}

