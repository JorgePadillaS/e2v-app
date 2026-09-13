import 'dart:async';

import '../data/mobile_api.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

final activeSessionStaleProvider = StateProvider<bool>((ref) => false);
final activeSessionProvider = StateNotifierProvider<ActiveSessionNotifier, AsyncValue<Map<String, dynamic>?>>((ref) {
  return ActiveSessionNotifier(onStale: (stale) => ref.read(activeSessionStaleProvider.notifier).state = stale);
});

class ActiveSessionNotifier extends StateNotifier<AsyncValue<Map<String, dynamic>?>> {
  ActiveSessionNotifier({this.onStale}) : super(const AsyncValue.loading());
  final void Function(bool)? onStale;
  Timer? _timer;
  MobileApi? _api;
  bool _fetching = false;
  int _generation = 0;
  void startPolling(MobileApi api) {
    _generation++;
    _api = api;
    _timer?.cancel();
    state = const AsyncValue.loading();
    _fetch();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _fetch());
  }

  void stopPolling() {
    _generation++;
    _timer?.cancel();
    _timer = null;
    _api = null;
  }

  Future<void> refresh() => _fetch();
  Future<void> _fetch() async {
    if (_api == null || _fetching) return;
    final generation = _generation;
    _fetching = true;
    try {
      final response = await _api!.sessions();
      if (response['data'] is! List) throw const FormatException('Invalid sessions response');
      if (!mounted || generation != _generation) return;
      final active = (response['data'] as List)
          .whereType<Map>()
          .where((s) => s['status'] == 'Active' || s['status'] == 'Starting')
          .firstOrNull;
      onStale?.call(false);
      state = AsyncValue.data(active == null ? null : Map<String, dynamic>.from(active));
    } catch (e, st) {
      if (!mounted || generation != _generation) return;
      onStale?.call(true);
      // Retain the active session; a network failure is not a completed charge.
      if (!state.hasValue) state = AsyncValue.error(e, st);
    } finally {
      _fetching = false;
    }
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
