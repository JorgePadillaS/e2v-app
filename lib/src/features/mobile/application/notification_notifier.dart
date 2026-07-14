import 'dart:async';
import '../data/mobile_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationProvider = StateNotifierProvider<
  NotificationNotifier,
  AsyncValue<Map<String, dynamic>>
>((ref) => NotificationNotifier(ref));

class NotificationNotifier
    extends StateNotifier<AsyncValue<Map<String, dynamic>>> {
  NotificationNotifier(this.ref) : super(const AsyncValue.loading());

  final Ref ref;
  Timer? _timer;

  void startPolling(MobileApi api) {
    _timer?.cancel();
    fetchNotifications(api);
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      fetchNotifications(api);
    });
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> poll(MobileApi api) => fetchNotifications(api);

  Future<void> fetchNotifications(MobileApi api) async {
    try {
      final data = await api.notifications();
      state = AsyncValue.data(data);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> markAsRead(MobileApi api, String id) async {
    try {
      await api.markNotificationAsRead(id);
      await fetchNotifications(api);
    } catch (_) {}
  }

  Future<void> markAllAsRead(MobileApi api) async {
    try {
      await api.markAllNotificationsAsRead();
      await fetchNotifications(api);
    } catch (_) {}
  }
}
