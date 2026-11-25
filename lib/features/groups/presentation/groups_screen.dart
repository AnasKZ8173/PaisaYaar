import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/currencies.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/router/route_names.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/top_action_bar.dart';
import '../../notifications/providers/notifications_provider.dart';
import '../data/group_repository.dart';
import '../providers/groups_provider.dart';

class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  String _search = '';
  bool _showSearch = false;

  Future<void> _openCreateGroupDialog() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    var category = 'Friends Trip';
    var currency = SupportedCurrencies.defaultCurrency;
    var saving = false;

    const categories = [
      'Friends Trip',
      'Family',
      'Office',
      'Flat Expenses',
      'Shopping',
      'Events',
      'General',
    ];

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.xl,
                MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Create Group',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    controller: nameCtrl,
                    label: 'Group name',
                    hint: 'e.g. Hunza Trip',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: descCtrl,
                    label: 'Description (optional)',
                    hint: 'Shared expenses',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setModalState(() => category = v);
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    initialValue: currency,
                    decoration: const InputDecoration(labelText: 'Currency'),
                    items: SupportedCurrencies.all
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.code,
                            child: Text(c.nameEn),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setModalState(() => currency = v);
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: 'Create Group',
                    isLoading: saving,
                    onPressed: () async {
                      if (nameCtrl.text.trim().length < 2) return;
                      setModalState(() => saving = true);
                      try {
                        final newId = await ref
                            .read(groupRepositoryProvider)
                            .createGroup(
                              name: nameCtrl.text,
                              description: descCtrl.text,
                              category: category,
                              currency: currency,
                            );
                        ref.invalidate(myGroupsProvider);
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        if (mounted) context.push('/groups/$newId');
                      } finally {
                        if (ctx.mounted) setModalState(() => saving = false);
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final groupsAsync = ref.watch(myGroupsProvider);
    final invitesAsync = ref.watch(pendingInvitesProvider);

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myGroupsProvider);
          ref.invalidate(pendingInvitesProvider);
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: TopActionBar(
                title: l10n.t('groups_title'),
                hasUnreadNotifications:
                    ref.watch(unreadNotificationsCountProvider) > 0,
                onSearchTap: () => setState(() => _showSearch = !_showSearch),
                onNotificationsTap: () => context.push(RoutePaths.notifications),
              ),
            ),
            if (_showSearch)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.xs,
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _search = v.toLowerCase()),
                    decoration: const InputDecoration(
                      hintText: 'Search groups...',
                      prefixIcon: Icon(AppIcons.search, size: 18),
                    ),
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                110,
              ),
              sliver: SliverList.list(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      AppButton(
                        label: l10n.t('create_group'),
                        icon: AppIcons.plusCircle,
                        fullWidth: false,
                        onPressed: _openCreateGroupDialog,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Pending Invitations
                  invitesAsync.when(
                    data: (invites) {
                      if (invites.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pending Invitations',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          ...invites.map(
                            (inv) => Padding(
                              padding:
                                  const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: AppCard(
                                backgroundColor: AppColors.accentGreenSoft,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            inv.groupName,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium,
                                          ),
                                          Text(
                                            inv.groupCategory,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        await ref
                                            .read(groupRepositoryProvider)
                                            .respondToInvite(
                                              inviteId: inv.id,
                                              accept: false,
                                            );
                                        ref.invalidate(pendingInvitesProvider);
                                      },
                                      child: const Text('Reject'),
                                    ),
                                    FilledButton(
                                      onPressed: () async {
                                        await ref
                                            .read(groupRepositoryProvider)
                                            .respondToInvite(
                                              inviteId: inv.id,
                                              accept: true,
                                            );
                                        ref.invalidate(pendingInvitesProvider);
                                        ref.invalidate(myGroupsProvider);
                                      },
                                      child: const Text('Accept'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),

                  // Joined Groups
                  groupsAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(AppSpacing.xxxl),
                      child: AppLoadingView(),
                    ),
                    error: (e, _) => AppErrorState(
                      message: e.toString(),
                      onRetry: () => ref.invalidate(myGroupsProvider),
                    ),
                    data: (groups) {
                      final filtered = groups
                          .where(
                            (g) =>
                                _search.isEmpty ||
                                g.name.toLowerCase().contains(_search) ||
                                g.category.toLowerCase().contains(_search),
                          )
                          .toList();

                      if (filtered.isEmpty) {
                        return AppEmptyState(
                          icon: AppIcons.users,
                          title: 'No groups yet',
                          subtitle:
                              'Create a group for trips, flat expenses, family, or office.',
                          actionLabel: l10n.t('create_group'),
                          onAction: _openCreateGroupDialog,
                        );
                      }

                      return Column(
                        children: filtered
                            .map(
                              (g) => Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.md,
                                ),
                                child: AppCard(
                                  onTap: () => context.push('/groups/${g.id}'),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: AppColors.accentGreenSoft,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                          AppIcons.users,
                                          color: AppColors.accentGreenDark,
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.md),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              g.name,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${g.category} • ${g.currency}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        color: AppColors.lightTextTertiary,
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
