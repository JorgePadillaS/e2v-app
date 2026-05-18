import 'dart:async';
import 'package:e2v_app/src/features/mobile/data/mobile_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final activeSessionProvider = StateNotifierProvider<ActiveSessionNotifier, AsyncValue<Map<String, dynamic>?>>((ref) {
  return ActiveSessionNotifier();
});

class ActiveSessionNotifier extends StateNotifier<AsyncValue<Map<String, dynamic>?>> {
  ActiveSessionNotifier() : super(const AsyncValue.loading());

  Timer? _timer;
  MobileApi? _api;

  void startPolling(MobileApi api) {
    _api = api;
    _timer?.cancel();
    _fetch();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _fetch());
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> refresh() => _fetch();

  Future<void> _fetch() async {
    if (_api == null) return;
    try {
      final response = await _api!.sessions();
      final List data = response['data'] ?? [];
      final active = data.firstWhere(
        (s) => s['status'] == 'Active' || s['status'] == 'Starting',
        orElse: () => null,
      );
      
      if (active != null) {
        state = AsyncValue.data(Map<String, dynamic>.from(active as Map));
      } else {
        state = const AsyncValue.data(null);
      }
    } catch (e, st) {
      // Don't overwrite data with error if we already have data to avoid flickers
      if (!state.hasValue) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
