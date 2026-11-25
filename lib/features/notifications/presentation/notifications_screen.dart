import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/notification_repository.dart';
import '../providers/notifications_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsStreamProvider);
    final uid = ref.watch(currentUserProvider)?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (uid != null)
            TextButton(
              onPressed: () => ref
                  .read(notificationRepositoryProvider)
                  .markAllAsRead(uid),
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const AppLoadingView(),
        error: (e, _) => AppErrorState(message: e.toString()),
        data: (items) {
          if (items.isEmpty) {
            return const AppEmptyState(
              icon: AppIcons.bell,
              title: 'No notifications yet',
              subtitle:
                  'You will be notified when someone adds a group expense involving you, invites you, or settles a balance.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final item = items[index];
              return AppCard(
                backgroundColor:
                    item.isRead ? null : AppColors.accentGreenSoft,
                onTap: () async {
                  if (!item.isRead) {
                    await ref
                        .read(notificationRepositoryProvider)
                        .markAsRead(item.id);
                  }
                  if (context.mounted && item.groupId != null) {
                    context.push('/groups/${item.groupId}');
                  }
                },
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: item.isRead
                            ? AppColors.lightSurfaceMuted
                            : AppColors.accentGreen,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        AppIcons.bell,
                        size: 18,
                        color: item.isRead
                            ? AppColors.lightTextSecondary
                            : Colors.white,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.body,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.createdAt
                                .toLocal()
                                .toString()
                                .split('.')
                                .first,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
