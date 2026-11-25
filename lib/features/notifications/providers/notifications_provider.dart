import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/notification_model.dart';
import '../data/notification_repository.dart';

final notificationsStreamProvider =
    StreamProvider<List<AppNotificationModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.read(notificationRepositoryProvider).watchNotifications(user.id);
});

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final list = ref.watch(notificationsStreamProvider).valueOrNull ?? const [];
  return list.where((n) => !n.isRead).length;
});
