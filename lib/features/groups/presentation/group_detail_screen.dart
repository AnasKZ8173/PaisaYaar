import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/data/group_chat_repository.dart';
import '../../group_expenses/data/group_expense_repository.dart';
import '../../group_expenses/providers/group_expenses_provider.dart';
import '../../personal_finance/data/personal_finance_repository.dart';
import '../../personal_finance/providers/personal_finance_provider.dart';
import '../../profile/providers/profile_provider.dart';
import '../../settlements/data/settlement_repository.dart';
import '../../settlements/providers/settlements_provider.dart';
import '../data/group_models.dart';
import '../data/group_repository.dart';
import '../providers/groups_provider.dart';

class GroupDetailScreen extends ConsumerStatefulWidget {
  const GroupDetailScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(myGroupsProvider).valueOrNull ?? const [];
    final group = groups.where((g) => g.id == widget.groupId).firstOrNull;
    final members =
        ref.watch(groupMembersProvider(widget.groupId)).valueOrNull ?? const [];
    final settings =
        ref.watch(groupSettingsProvider(widget.groupId)).valueOrNull;
    final uid = ref.watch(currentUserProvider)?.id;
    final myMember = members.where((m) => m.userId == uid).firstOrNull;

    final canAddExpense = _canPerform(
      myMember?.role,
      settings?.whoCanAddExpense ?? 'all',
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(group?.name ?? 'Group'),
        actions: [
          if (canAddExpense)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.md),
              child: FilledButton.icon(
                onPressed: () =>
                    context.push('/groups/${widget.groupId}/add-expense'),
                icon: const Icon(AppIcons.plusCircle, size: 16),
                label: const Text('Expense'),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Expenses'),
            Tab(text: 'Balances'),
            Tab(text: 'Chat'),
            Tab(text: 'Members'),
            Tab(text: 'Activity'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ExpensesTab(
            groupId: widget.groupId,
            currency: group?.currency ?? 'PKR',
            members: members,
            canApprove: _canPerform(
              myMember?.role,
              settings?.whoCanApproveExpense ?? 'admins',
            ),
          ),
          _BalancesTab(
            groupId: widget.groupId,
            currency: group?.currency ?? 'PKR',
            members: members,
            currentUserId: uid ?? '',
          ),
          _ChatTab(
            groupId: widget.groupId,
            members: members,
            settings: settings,
            currentUserId: uid ?? '',
          ),
          _MembersAndSettingsTab(
            groupId: widget.groupId,
            group: group,
            members: members,
            settings: settings,
            currentUserId: uid ?? '',
          ),
          _ActivityTab(groupId: widget.groupId),
        ],
      ),
    );
  }

  bool _canPerform(String? role, String rule) {
    if (role == 'owner') return true;
    if (rule == 'all' && role != null) return true;
    if (rule == 'admins' && (role == 'owner' || role == 'sub_admin')) {
      return true;
    }
    return false;
  }
}

class _ExpensesTab extends ConsumerWidget {
  const _ExpensesTab({
    required this.groupId,
    required this.currency,
    required this.members,
    required this.canApprove,
  });

  final String groupId;
  final String currency;
  final List<GroupMemberModel> members;
  final bool canApprove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(groupExpensesProvider(groupId));

    return expensesAsync.when(
      loading: () => const AppLoadingView(),
      error: (e, _) => AppErrorState(
        message: e.toString(),
        onRetry: () => ref.invalidate(groupExpensesProvider(groupId)),
      ),
      data: (expenses) {
        if (expenses.isEmpty) {
          return const AppEmptyState(
            icon: AppIcons.wallet,
            title: 'No expenses yet',
            subtitle: 'Add an expense to start splitting with the group.',
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(groupExpensesProvider(groupId)),
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: expenses.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              final exp = expenses[index];
              final payerNames = exp.payers.map((p) {
                final m = members.where((x) => x.userId == p.userId).firstOrNull;
                return m?.fullName ?? 'Member';
              }).join(', ');

              return AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            exp.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        AmountText(
                          amountMinor: exp.totalAmountMinor,
                          currencyCode: currency,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${exp.category} • Paid by $payerNames • ${exp.participants.length} split',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        _StatusChip(status: exp.approvalStatus),
                        const Spacer(),
                        if (exp.isPending && canApprove) ...[
                          TextButton(
                            onPressed: () async {
                              await ref
                                  .read(groupExpenseRepositoryProvider)
                                  .decideExpense(
                                    expenseId: exp.id,
                                    decision: 'rejected',
                                  );
                              ref.invalidate(groupExpensesProvider(groupId));
                              ref.invalidate(groupActivityProvider(groupId));
                            },
                            child: const Text('Reject'),
                          ),
                          FilledButton(
                            onPressed: () async {
                              await ref
                                  .read(groupExpenseRepositoryProvider)
                                  .decideExpense(
                                    expenseId: exp.id,
                                    decision: 'approved',
                                  );
                              ref.invalidate(groupExpensesProvider(groupId));
                              ref.invalidate(groupActivityProvider(groupId));
                            },
                            child: const Text('Approve'),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _BalancesTab extends ConsumerWidget {
  const _BalancesTab({
    required this.groupId,
    required this.currency,
    required this.members,
    required this.currentUserId,
  });

  final String groupId;
  final String currency;
  final List<GroupMemberModel> members;
  final String currentUserId;

  String _nameOf(String uid) =>
      members.where((m) => m.userId == uid).firstOrNull?.fullName ?? 'Member';

  Future<void> _openSettleDialog(
    BuildContext context,
    WidgetRef ref, {
    required String receiverId,
    required int suggestedMinor,
  }) async {
    final amountCtrl = TextEditingController(
      text: (suggestedMinor / 100).toStringAsFixed(0),
    );
    final refCtrl = TextEditingController();
    final accounts =
        ref.read(personalAccountsProvider).valueOrNull ?? const [];
    var method = 'bank';
    String? selectedAccountId = accounts.isNotEmpty ? accounts.first.id : null;
    var deductFromAccount = accounts.isNotEmpty;
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('Pay ${_nameOf(receiverId)}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'Amount ($currency)'),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  initialValue: method,
                  decoration: const InputDecoration(
                    labelText: 'Payment method',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(
                      value: 'bank',
                      child: Text('Bank Transfer'),
                    ),
                    DropdownMenuItem(
                      value: 'easypaisa',
                      child: Text('Easypaisa'),
                    ),
                    DropdownMenuItem(
                      value: 'jazzcash',
                      child: Text('JazzCash'),
                    ),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        method = v;
                        deductFromAccount = v != 'cash' && accounts.isNotEmpty;
                      });
                    }
                  },
                ),
                if (accounts.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Deduct from personal account'),
                    value: deductFromAccount,
                    onChanged: (v) => setState(() => deductFromAccount = v),
                  ),
                  if (deductFromAccount)
                    DropdownButtonFormField<String>(
                      initialValue: selectedAccountId,
                      decoration: const InputDecoration(labelText: 'Account'),
                      items: accounts
                          .map(
                            (a) => DropdownMenuItem(
                              value: a.id,
                              child: Text(a.name),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => selectedAccountId = v),
                    ),
                ],
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: refCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Reference / Note (optional)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final major = double.tryParse(amountCtrl.text.trim());
                      if (major == null || major <= 0) return;
                      final minor = (major * 100).round();
                      setState(() => saving = true);
                      try {
                        await ref
                            .read(settlementRepositoryProvider)
                            .submitSettlement(
                              groupId: groupId,
                              receiverId: receiverId,
                              amountMinor: minor,
                              paymentMethod: method,
                              reference: refCtrl.text,
                            );
                        if (deductFromAccount && selectedAccountId != null) {
                          await ref
                              .read(personalFinanceRepositoryProvider)
                              .recordTransaction(
                                accountId: selectedAccountId,
                                txType: 'group_payment',
                                amountMinor: minor,
                                title: 'Group Settlement to ${_nameOf(receiverId)}',
                                paymentMethod: method,
                              );
                          ref.invalidate(personalAccountsProvider);
                          ref.invalidate(personalTransactionsProvider);
                        }
                        ref.invalidate(groupSettlementsProvider(groupId));
                        ref.invalidate(groupActivityProvider(groupId));
                        ref.invalidate(groupDashboardSummaryProvider);
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      } finally {
                        if (ctx.mounted) setState(() => saving = false);
                      }
                    },
              child: const Text('Submit Payment'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balancesAsync = ref.watch(groupBalancesProvider(groupId));
    final suggested = ref.watch(groupSuggestedSettlementsProvider(groupId));
    final settlementsAsync = ref.watch(groupSettlementsProvider(groupId));

    return balancesAsync.when(
      loading: () => const AppLoadingView(),
      error: (e, _) => AppErrorState(message: e.toString()),
      data: (balances) {
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              'Suggested Settlement Plan',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (suggested.isEmpty)
              const AppCard(
                child: Text('All group balances are settled!'),
              )
            else
              ...suggested.map(
                (s) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AppCard(
                    backgroundColor: AppColors.accentGreenSoft,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_nameOf(s.fromUserId)} pays ${_nameOf(s.toUserId)}',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        AmountText(
                          amountMinor: s.amountMinor,
                          currencyCode: currency,
                        ),
                        if (s.fromUserId == currentUserId) ...[
                          const SizedBox(width: AppSpacing.sm),
                          FilledButton(
                            onPressed: () => _openSettleDialog(
                              context,
                              ref,
                              receiverId: s.toUserId,
                              suggestedMinor: s.amountMinor,
                            ),
                            child: const Text('Settle'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Member Balances',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            ...balances.values.map(
              (b) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppCard(
                  child: Row(
                    children: [
                      UserAvatar(name: _nameOf(b.userId), radius: 18),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _nameOf(b.userId),
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            Text(
                              'Paid ${(b.totalPaidMinor / 100).toStringAsFixed(0)} • Share ${(b.totalShareMinor / 100).toStringAsFixed(0)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      AmountText(
                        amountMinor: b.netBalanceMinor,
                        currencyCode: currency,
                        showSign: true,
                        colorBySign: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Settlement History',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            settlementsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (items) {
                if (items.isEmpty) {
                  return const AppCard(child: Text('No settlements recorded.'));
                }
                return Column(
                  children: items
                      .map(
                        (st) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${_nameOf(st.senderId)} → ${_nameOf(st.receiverId)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall,
                                      ),
                                    ),
                                    AmountText(
                                      amountMinor: st.amountMinor,
                                      currencyCode: currency,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    _StatusChip(status: st.status),
                                    const SizedBox(width: AppSpacing.sm),
                                    Text(
                                      st.paymentMethod.toUpperCase(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                    const Spacer(),
                                    if (st.isPending &&
                                        st.receiverId == currentUserId) ...[
                                      TextButton(
                                        onPressed: () async {
                                          await ref
                                              .read(
                                                settlementRepositoryProvider,
                                              )
                                              .decideSettlement(
                                                settlementId: st.id,
                                                decision: 'rejected',
                                              );
                                          ref.invalidate(
                                            groupSettlementsProvider(groupId),
                                          );
                                          ref.invalidate(
                                            groupActivityProvider(groupId),
                                          );
                                        },
                                        child: const Text('Reject'),
                                      ),
                                      FilledButton(
                                        onPressed: () async {
                                          await ref
                                              .read(
                                                settlementRepositoryProvider,
                                              )
                                              .decideSettlement(
                                                settlementId: st.id,
                                                decision: 'confirmed',
                                              );
                                          ref.invalidate(
                                            groupSettlementsProvider(groupId),
                                          );
                                          ref.invalidate(
                                            groupActivityProvider(groupId),
                                          );
                                        },
                                        child: const Text('Confirm'),
                                      ),
                                    ],
                                    if (st.isPending &&
                                        st.senderId == currentUserId)
                                      TextButton(
                                        onPressed: () async {
                                          await ref
                                              .read(
                                                settlementRepositoryProvider,
                                              )
                                              .decideSettlement(
                                                settlementId: st.id,
                                                decision: 'cancelled',
                                              );
                                          ref.invalidate(
                                            groupSettlementsProvider(groupId),
                                          );
                                        },
                                        child: const Text('Cancel'),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _MembersAndSettingsTab extends ConsumerStatefulWidget {
  const _MembersAndSettingsTab({
    required this.groupId,
    required this.group,
    required this.members,
    required this.settings,
    required this.currentUserId,
  });

  final String groupId;
  final GroupModel? group;
  final List<GroupMemberModel> members;
  final GroupSettingsModel? settings;
  final String currentUserId;

  @override
  ConsumerState<_MembersAndSettingsTab> createState() =>
      _MembersAndSettingsTabState();
}

class _MembersAndSettingsTabState
    extends ConsumerState<_MembersAndSettingsTab> {
  String _inviteSearch = '';

  @override
  Widget build(BuildContext context) {
    final isOwner = widget.group?.ownerId == widget.currentUserId;
    final searchAsync = ref.watch(publicUserSearchProvider(_inviteSearch));

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(
          'Invite by Unique ID',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: Column(
            children: [
              TextField(
                onChanged: (v) => setState(() => _inviteSearch = v),
                decoration: const InputDecoration(
                  hintText: 'Search public ID (min 2 chars)...',
                  prefixIcon: Icon(AppIcons.search, size: 18),
                ),
              ),
              if (_inviteSearch.trim().length >= 2)
                searchAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  error: (e, _) => Text(e.toString()),
                  data: (users) => Column(
                    children: users
                        .map(
                          (u) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: UserAvatar(
                              name: u.fullName,
                              imageUrl: u.avatarUrl,
                              radius: 16,
                            ),
                            title: Text(u.fullName),
                            subtitle: Text('@${u.publicId}'),
                            trailing: FilledButton(
                              onPressed: () async {
                                await ref
                                    .read(groupRepositoryProvider)
                                    .inviteUser(
                                      groupId: widget.groupId,
                                      inviteeUserId: u.id,
                                    );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Invited @${u.publicId}'),
                                    ),
                                  );
                                }
                              },
                              child: const Text('Invite'),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Members (${widget.members.length})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        ...widget.members.map(
          (m) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: AppCard(
              child: Row(
                children: [
                  UserAvatar(
                    name: m.fullName,
                    imageUrl: m.avatarUrl,
                    radius: 18,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.fullName,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          '@${m.publicId} • ${m.role.toUpperCase()}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (isOwner && m.userId != widget.currentUserId)
                    PopupMenuButton<String>(
                      onSelected: (action) async {
                        final repo = ref.read(groupRepositoryProvider);
                        if (action == 'sub_admin' || action == 'member') {
                          await repo.updateMemberRole(
                            groupId: widget.groupId,
                            userId: m.userId,
                            role: action,
                          );
                        } else if (action == 'remove') {
                          await repo.removeMember(
                            groupId: widget.groupId,
                            userId: m.userId,
                          );
                        }
                        ref.invalidate(groupMembersProvider(widget.groupId));
                      },
                      itemBuilder: (_) => [
                        if (m.role == 'member')
                          const PopupMenuItem(
                            value: 'sub_admin',
                            child: Text('Make Sub-admin'),
                          ),
                        if (m.role == 'sub_admin')
                          const PopupMenuItem(
                            value: 'member',
                            child: Text('Demote to Member'),
                          ),
                        const PopupMenuItem(
                          value: 'remove',
                          child: Text('Remove from group'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
        if (isOwner && widget.settings != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Group Settings & Permissions',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Require expense approval'),
                  value: widget.settings!.requireExpenseApproval,
                  onChanged: (v) async {
                    await ref.read(groupRepositoryProvider).updateSettings(
                          widget.settings!.copyWith(requireExpenseApproval: v),
                        );
                    ref.invalidate(groupSettingsProvider(widget.groupId));
                  },
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('Auto-confirm settlements'),
                  value: widget.settings!.autoConfirmSettlements,
                  onChanged: (v) async {
                    await ref.read(groupRepositoryProvider).updateSettings(
                          widget.settings!.copyWith(autoConfirmSettlements: v),
                        );
                    ref.invalidate(groupSettingsProvider(widget.groupId));
                  },
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('Allow all members to chat'),
                  value: widget.settings!.allowAllMembersChat,
                  onChanged: (v) async {
                    await ref.read(groupRepositoryProvider).updateSettings(
                          widget.settings!.copyWith(allowAllMembersChat: v),
                        );
                    ref.invalidate(groupSettingsProvider(widget.groupId));
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'Delete Group',
            variant: AppButtonVariant.outline,
            onPressed: () async {
              await ref
                  .read(groupRepositoryProvider)
                  .deleteGroup(widget.groupId);
              ref.invalidate(myGroupsProvider);
              if (context.mounted) context.pop();
            },
          ),
        ],
      ],
    );
  }
}

class _ChatTab extends ConsumerStatefulWidget {
  const _ChatTab({
    required this.groupId,
    required this.members,
    required this.settings,
    required this.currentUserId,
  });

  final String groupId;
  final List<GroupMemberModel> members;
  final GroupSettingsModel? settings;
  final String currentUserId;

  @override
  ConsumerState<_ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends ConsumerState<_ChatTab> {
  final _msgCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(groupMessagesStreamProvider(widget.groupId));
    final myMember = widget.members
        .where((m) => m.userId == widget.currentUserId)
        .firstOrNull;
    final isAdmin = myMember?.isAdmin ?? false;
    final canChat =
        isAdmin || (widget.settings?.allowAllMembersChat ?? true);

    String nameOf(String uid) =>
        widget.members.where((m) => m.userId == uid).firstOrNull?.fullName ??
        'Member';

    return Column(
      children: [
        Expanded(
          child: messagesAsync.when(
            loading: () => const AppLoadingView(),
            error: (e, _) => AppErrorState(message: e.toString()),
            data: (messages) {
              if (messages.isEmpty) {
                return const AppEmptyState(
                  icon: AppIcons.mail,
                  title: 'No messages yet',
                  subtitle:
                      'Admins can post announcements and tag members with @public_id or @all.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: messages.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (_, i) {
                  final msg = messages[i];
                  final isMe = msg.senderId == widget.currentUserId;
                  return Align(
                    alignment: isMe
                        ? AlignmentDirectional.centerEnd
                        : AlignmentDirectional.centerStart,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 300),
                      child: AppCard(
                        backgroundColor:
                            isMe ? AppColors.accentGreenSoft : null,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nameOf(msg.senderId),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(msg.body),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        if (canChat) ...[
          if (widget.members.isNotEmpty)
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                children: [
                  if (isAdmin)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 6),
                      child: ActionChip(
                        label: const Text('@all'),
                        onPressed: () {
                          _msgCtrl.text = '${_msgCtrl.text}@all ';
                        },
                      ),
                    ),
                  ...widget.members
                      .where((m) => m.userId != widget.currentUserId)
                      .map(
                        (m) => Padding(
                          padding: const EdgeInsetsDirectional.only(end: 6),
                          child: ActionChip(
                            label: Text('@${m.publicId}'),
                            onPressed: () {
                              _msgCtrl.text = '${_msgCtrl.text}@${m.publicId} ';
                            },
                          ),
                        ),
                      ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Message or @tag member...',
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  onPressed: _sending
                      ? null
                      : () async {
                          final text = _msgCtrl.text.trim();
                          if (text.isEmpty) return;
                          setState(() => _sending = true);
                          try {
                            await ref
                                .read(groupChatRepositoryProvider)
                                .sendMessage(
                                  groupId: widget.groupId,
                                  body: text,
                                  isAnnouncement: isAdmin,
                                );
                            _msgCtrl.clear();
                          } finally {
                            if (mounted) setState(() => _sending = false);
                          }
                        },
                  child: const Text('Send'),
                ),
              ],
            ),
          ),
        ] else
          const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: AppCard(
              child: Text('Only admins can send messages in this group.'),
            ),
          ),
      ],
    );
  }
}

class _ActivityTab extends ConsumerWidget {
  const _ActivityTab({required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(groupActivityProvider(groupId));
    return activityAsync.when(
      loading: () => const AppLoadingView(),
      error: (e, _) => AppErrorState(message: e.toString()),
      data: (items) {
        if (items.isEmpty) {
          return const AppEmptyState(
            icon: AppIcons.info,
            title: 'No activity yet',
            subtitle: 'Group actions will appear here.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (_, i) {
            final item = items[i];
            return AppCard(
              child: Row(
                children: [
                  const Icon(AppIcons.info, size: 18, color: AppColors.accentGreen),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.actionType.replaceAll('_', ' ').toUpperCase(),
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        Text(
                          item.createdAt.toLocal().toString().split('.').first,
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
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      'approved' || 'confirmed' => (
          AppColors.accentGreenSoft,
          AppColors.accentGreenDark,
        ),
      'rejected' || 'cancelled' => (
          AppColors.negativeRedSoft,
          AppColors.negativeRed,
        ),
      _ => (AppColors.warningAmberSoft, AppColors.warningAmber),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
