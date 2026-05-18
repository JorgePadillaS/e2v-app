import 'package:intl/intl.dart';
import 'package:e2v_app/src/features/mobile/application/notification_notifier.dart';
import 'package:e2v_app/src/features/mobile/data/mobile_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key, required this.api});
  final MobileApi api;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            onPressed:
                () =>
                    ref.read(notificationProvider.notifier).markAllAsRead(api),
            tooltip: 'Marcar todas como leídas',
          ),
        ],
      ),
      body: state.when(
        data: (data) {
          final notifications = (data['data']['data'] as List? ?? []);
          if (notifications.isEmpty) {
            return const Center(child: Text('No tienes notificaciones'));
          }
          return RefreshIndicator(
            onRefresh:
                () => ref
                    .read(notificationProvider.notifier)
                    .fetchNotifications(api),
            child: ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final item = notifications[index];
                final notificationData = item['data'] ?? {};
                final isRead = item['read_at'] != null;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        isRead ? Colors.grey : Theme.of(context).primaryColor,
                    child: const Icon(Icons.notifications, color: Colors.white),
                  ),
                  title: Text(notificationData['title'] ?? 'Aviso'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(notificationData['message'] ?? ''),
                      const SizedBox(height: 4),
                      Text(
                        (DateTime.tryParse(item['created_at']?.toString() ?? '')?.toLocal() != null)
                            ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(item['created_at']!))
                            : '',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                  trailing:
                      !isRead
                          ? const Icon(
                            Icons.circle,
                            size: 12,
                            color: Colors.blue,
                          )
                          : null,
                  onTap: () {
                    if (!isRead) {
                      ref
                          .read(notificationProvider.notifier)
                          .markAsRead(api, item['id']);
                    }
                  },
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
