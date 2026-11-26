import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/providers/auth_provider.dart';
import '../../groups/data/group_repository.dart';
import '../../groups/providers/groups_provider.dart';
import '../../loans/data/loan_repository.dart';
import '../../loans/providers/loans_provider.dart';
import '../../personal_finance/providers/personal_finance_provider.dart';
import '../../settlements/data/settlement_repository.dart';
import '../data/notification_model.dart';
import '../data/notification_repository.dart';
import '../providers/notifications_provider.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = ref.read(currentUserProvider)?.id;
  }

  @override
  void dispose() {
    final uid = _userId;
    if (uid != null) {
      // Automatically mark all notifications as read when leaving the page.
      unawaited(
        ref.read(notificationRepositoryProvider).markAllAsRead(uid).catchError(
              (_) {},
            ),
      );
    }
    super.dispose();
  }

  bool _isRequestNotification(AppNotificationModel n) {
    return n.type == 'group_invite' ||
        n.type == 'loan_request' ||
        n.type == 'loan_repayment_request' ||
        n.type == 'settlement_request';
  }

  Future<void> _handleTap(AppNotificationModel item) async {
    if (!item.isRead) {
      unawaited(ref.read(notificationRepositoryProvider).markAsRead(item.id));
    }

    if (!_isRequestNotification(item)) {
      if (mounted && item.groupId != null) {
        context.push('/groups/${item.groupId}');
      }
      return;
    }

    final accounts =
        ref.read(personalAccountsProvider).valueOrNull ?? const [];
    final isRepaymentOnline = item.type == 'loan_repayment_request' &&
        (item.data['payment_method'] as String?) != 'cash' &&
        accounts.isNotEmpty;
    String? selectedAccountId =
        isRepaymentOnline ? accounts.first.id : null;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Text(item.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.body),
              if (isRepaymentOnline) ...[
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  initialValue: selectedAccountId,
                  decoration: const InputDecoration(
                    labelText: 'Deposit into account',
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Do not add to account'),
                    ),
                    ...accounts.map(
                      (a) => DropdownMenuItem(
                        value: a.id,
                        child: Text(a.name),
                      ),
                    ),
                  ],
                  onChanged: (v) => setModalState(() => selectedAccountId = v),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _executeRequestAction(
                  item,
                  accept: false,
                  lenderAccountId: selectedAccountId,
                );
              },
              child: const Text(
                'Reject',
                style: TextStyle(color: AppColors.negativeRed),
              ),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _executeRequestAction(
                  item,
                  accept: true,
                  lenderAccountId: selectedAccountId,
                );
              },
              child: const Text('Accept'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _executeRequestAction(
    AppNotificationModel item, {
    required bool accept,
    String? lenderAccountId,
  }) async {
    try {
      switch (item.type) {
        case 'group_invite':
          final inviteId = item.data['invite_id'] as String?;
          if (inviteId != null) {
            await ref
                .read(groupRepositoryProvider)
                .respondToInvite(inviteId: inviteId, accept: accept);
            ref.invalidate(pendingInvitesProvider);
            ref.invalidate(myGroupsProvider);
          }
        case 'loan_request':
          final loanId = item.data['loan_id'] as String?;
          if (loanId != null) {
            await ref
                .read(loanRepositoryProvider)
                .respondToLoanRequest(loanId: loanId, accept: accept);
            ref.invalidate(myLoansProvider);
          }
        case 'loan_repayment_request':
          final repaymentId = item.data['repayment_id'] as String?;
          if (repaymentId != null) {
            await ref.read(loanRepositoryProvider).decideRepayment(
                  repaymentId: repaymentId,
                  accept: accept,
                  lenderAccountId: lenderAccountId,
                );
            ref.invalidate(myLoansProvider);
            ref.invalidate(pendingLoanRepaymentsProvider);
            ref.invalidate(personalAccountsProvider);
            ref.invalidate(personalTransactionsProvider);
          }
        case 'settlement_request':
          final settlementId = item.data['settlement_id'] as String?;
          if (settlementId != null) {
            await ref.read(settlementRepositoryProvider).decideSettlement(
                  settlementId: settlementId,
                  decision: accept ? 'confirmed' : 'rejected',
                );
            ref.invalidate(groupDashboardSummaryProvider);
          }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(accept ? 'Request accepted' : 'Request rejected'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorFormatter.friendly(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(notificationsStreamProvider);
        },
        child: notificationsAsync.when(
          loading: () => const AppLoadingView(),
          error: (e, _) => AppErrorState(
            message: e.toString(),
            onRetry: () => ref.invalidate(notificationsStreamProvider),
          ),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                children: const [
                  AppEmptyState(
                    icon: AppIcons.bell,
                    title: 'No notifications yet',
                    subtitle:
                        'You will be notified for group expenses, mentions, loan requests, and settlements.',
                  ),
                ],
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
                  onTap: () => _handleTap(item),
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
      ),
    );
  }
}
