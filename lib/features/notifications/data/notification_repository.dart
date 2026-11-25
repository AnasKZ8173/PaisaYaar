import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';
import 'notification_model.dart';

class NotificationRepository {
  NotificationRepository(this._client);

  final SupabaseClient? _client;

  Stream<List<AppNotificationModel>> watchNotifications(String userId) {
    final client = _client;
    if (client == null) return const Stream.empty();

    return client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50)
        .map(
          (rows) => rows.map(AppNotificationModel.fromJson).toList(),
        );
  }

  Future<void> markAsRead(String notificationId) async {
    final client = _client;
    if (client == null) return;
    await client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  Future<void> markAllAsRead(String userId) async {
    final client = _client;
    if (client == null) return;
    await client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(supabaseClientProvider));
});
