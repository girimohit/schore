import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_notifier.dart';
import '../../core/network/api_client.dart';

class DashboardData {
  final Map<String, dynamic> stats;
  final List<dynamic> timetable;
  final List<dynamic> notices;

  const DashboardData({
    this.stats = const {},
    this.timetable = const [],
    this.notices = const [],
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      stats: (json['stats'] as Map<String, dynamic>?) ?? const {},
      timetable: (json['timetable'] as List<dynamic>?) ?? const [],
      notices: (json['recentNotices'] as List<dynamic>?) ?? const [],
    );
  }
}

class DashboardState {
  final bool isLoading;
  final String? errorMessage;
  final DashboardData? data;

  const DashboardState({
    this.isLoading = false,
    this.errorMessage,
    this.data,
  });

  DashboardState copyWith({
    bool? isLoading,
    String? errorMessage,
    DashboardData? data,
  }) {
    return DashboardState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      data: data ?? this.data,
    );
  }
}

final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return DashboardNotifier(apiClient);
});

class DashboardNotifier extends StateNotifier<DashboardState> {
  final ApiClient _apiClient;

  DashboardNotifier(this._apiClient) : super(const DashboardState());

  Future<void> fetchDashboardData({bool forceRefresh = false}) async {
    // If we already have cached data and not forcing refresh, do a background update without blocking
    if (!forceRefresh && state.data != null) {
      _backgroundUpdate();
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final response = await _apiClient.dio.get('/api/school/metrics');
      if (response.statusCode == 200) {
        final rawData = (response.data['data'] as Map<String, dynamic>?) ?? {};
        state = state.copyWith(
          isLoading: false,
          errorMessage: null,
          data: DashboardData.fromJson(rawData),
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: response.data['message'] ?? 'Failed to load dashboard metrics',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Could not retrieve live dashboard stats. Please try again.',
      );
    }
  }

  Future<void> _backgroundUpdate() async {
    try {
      final response = await _apiClient.dio.get('/api/school/metrics');
      if (response.statusCode == 200) {
        final rawData = (response.data['data'] as Map<String, dynamic>?) ?? {};
        state = state.copyWith(
          data: DashboardData.fromJson(rawData),
        );
      }
    } catch (_) {}
  }

  void clear() {
    state = const DashboardState();
  }
}
