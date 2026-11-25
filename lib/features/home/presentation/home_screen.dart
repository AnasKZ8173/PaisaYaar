import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/currencies.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/router/route_names.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/top_action_bar.dart';
import '../../groups/providers/groups_provider.dart';
import '../../notifications/providers/notifications_provider.dart';
import '../../personal_finance/providers/personal_finance_provider.dart';
import '../../profile/providers/profile_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final currency =
        profile?.defaultCurrency ?? SupportedCurrencies.defaultCurrency;

    final accounts =
        ref.watch(personalAccountsProvider).valueOrNull ?? const [];
    final totalBalance = ref.watch(totalPersonalBalanceProvider);
    final summary = ref.watch(monthlyPersonalSummaryProvider);
    final remainingBudget = ref.watch(remainingMonthlyBudgetProvider);
    final recentTxs =
        ref.watch(personalTransactionsProvider).valueOrNull ?? const [];
    final groupSummary =
        ref.watch(groupDashboardSummaryProvider).valueOrNull ?? const {};
    final totalOwedMinor =
        (groupSummary['total_owed_minor'] as num?)?.toInt() ?? 0;
    final totalReceivableMinor =
        (groupSummary['total_receivable_minor'] as num?)?.toInt() ?? 0;
    final recentGroupExpenses =
        (groupSummary['recent_expenses'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        const [];
    final unreadCount = ref.watch(unreadNotificationsCountProvider);

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(personalAccountsProvider);
          ref.invalidate(personalTransactionsProvider);
          ref.invalidate(currentMonthBudgetsProvider);
          ref.invalidate(groupDashboardSummaryProvider);
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: TopActionBar(
                title: l10n.t('home_greeting'),
                showBrandLogo: true,
                hasUnreadNotifications: unreadCount > 0,
                onNotificationsTap: () => context.push(RoutePaths.notifications),
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
                  // Hero Personal Balance Card
                  AppCard(
                    backgroundColor: AppColors.accentGreenSoft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l10n.t('total_balance'),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: AppColors.accentGreenDark,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.pillRadius,
                                ),
                              ),
                              child: Text(
                                currency,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.accentGreenDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        AmountText(
                          amountMinor: totalBalance,
                          currencyCode: currency,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                color: AppColors.lightTextPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: _MiniMetric(
                                label: l10n.t('monthly_income'),
                                amountMinor: summary.incomeMinor,
                                currencyCode: currency,
                                positive: true,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: _MiniMetric(
                                label: l10n.t('monthly_expenses'),
                                amountMinor: summary.expenseMinor,
                                currencyCode: currency,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: _MiniMetric(
                                label: l10n.t('remaining_budget'),
                                amountMinor: remainingBudget,
                                currencyCode: currency,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Account-wise Balances Strip
                  if (accounts.isNotEmpty) ...[
                    SizedBox(
                      height: 76,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: accounts.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: AppSpacing.sm),
                        itemBuilder: (_, i) {
                          final acc = accounts[i];
                          return SizedBox(
                            width: 148,
                            child: AppCard(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              onTap: () => context.go(RoutePaths.personal),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    acc.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                  AmountText(
                                    amountMinor: acc.balanceMinor,
                                    currencyCode: acc.currency,
                                    style:
                                        Theme.of(context).textTheme.titleSmall,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // Group Balances Row
                  Row(
                    children: [
                      Expanded(
                        child: AppCard(
                          onTap: () => context.go(RoutePaths.groups),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.t('owed_to_you'),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 2),
                              AmountText(
                                amountMinor: totalReceivableMinor,
                                currencyCode: currency,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(color: AppColors.positiveGreen),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppCard(
                          onTap: () => context.go(RoutePaths.groups),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.t('you_owe'),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 2),
                              AmountText(
                                amountMinor: totalOwedMinor,
                                currencyCode: currency,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(color: AppColors.negativeRed),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Recent Group Expenses (Paid vs Return/Owed)
                  if (recentGroupExpenses.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Group Expenses',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        TextButton(
                          onPressed: () => context.go(RoutePaths.groups),
                          child: const Text('Groups'),
                        ),
                      ],
                    ),
                    ...recentGroupExpenses.take(4).map((ge) {
                      final paid = (ge['my_paid_minor'] as num?)?.toInt() ?? 0;
                      final share = (ge['my_share_minor'] as num?)?.toInt() ?? 0;
                      final net = paid - share;
                      final gCurrency = (ge['currency'] as String?) ?? currency;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: AppCard(
                          onTap: () =>
                              context.push('/groups/${ge['group_id']}'),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${ge['group_name']} • ${ge['title']}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall,
                                    ),
                                    Text(
                                      'Paid: ${(paid / 100).toStringAsFixed(0)} $gCurrency • Share: ${(share / 100).toStringAsFixed(0)} $gCurrency',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              AmountText(
                                amountMinor: net,
                                currencyCode: gCurrency,
                                showSign: true,
                                colorBySign: true,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // Spending Over Time Chart (Modern Reference UI)
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Spending Trend (This Month)',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              '${summary.dailySpendingMinor.length} active days',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        SizedBox(
                          height: 165,
                          child: _DailySpendingChart(
                            dailySpendingMinor: summary.dailySpendingMinor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Category Breakdown Bars
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Category Breakdown',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (summary.categoryTotalsMinor.isEmpty)
                          Text(
                            'Record personal expenses to see category analytics.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          )
                        else
                          ..._buildCategoryBars(
                            context,
                            summary.categoryTotalsMinor,
                            summary.expenseMinor,
                            currency,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Quick Actions
                  Text(
                    l10n.t('quick_actions'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _QuickActionChip(
                          icon: AppIcons.minusCircle,
                          label: l10n.t('add_expense'),
                          onTap: () => context.go(RoutePaths.personal),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _QuickActionChip(
                          icon: AppIcons.plusCircle,
                          label: l10n.t('add_income'),
                          onTap: () => context.go(RoutePaths.personal),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _QuickActionChip(
                          icon: AppIcons.users,
                          label: l10n.t('create_group'),
                          onTap: () => context.go(RoutePaths.groups),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _QuickActionChip(
                          icon: AppIcons.arrowLeftRight,
                          label: l10n.t('transfer_money'),
                          onTap: () => context.go(RoutePaths.personal),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _QuickActionChip(
                          icon: AppIcons.coins,
                          label: 'Loans',
                          onTap: () => context.push(RoutePaths.loans),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Recent Transactions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.t('recent_transactions'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      TextButton(
                        onPressed: () => context.go(RoutePaths.personal),
                        child: const Text('See all'),
                      ),
                    ],
                  ),
                  if (recentTxs.isEmpty)
                    const AppCard(
                      child: Text('No recent personal transactions.'),
                    )
                  else
                    ...recentTxs.take(5).map(
                          (tx) => Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: AppCard(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tx.title,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall,
                                        ),
                                        Text(
                                          '${tx.categoryName ?? tx.txType.toUpperCase()} • ${tx.txDate.toIso8601String().split('T').first}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  AmountText(
                                    amountMinor: tx.txType == 'income' ||
                                            tx.txType == 'reimbursement'
                                        ? tx.amountMinor
                                        : -tx.amountMinor,
                                    currencyCode: currency,
                                    showSign: true,
                                    colorBySign: true,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCategoryBars(
    BuildContext context,
    Map<String, int> totals,
    int totalExpense,
    String currency,
  ) {
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final denom = totalExpense <= 0 ? 1 : totalExpense;

    return entries.take(5).map((e) {
      final ratio = (e.value / denom).clamp(0.0, 1.0);
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(e.key, style: Theme.of(context).textTheme.bodyMedium),
                Text(
                  '${(e.value / 100).toStringAsFixed(0)} $currency (${(ratio * 100).toStringAsFixed(0)}%)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: ratio,
              minHeight: 7,
              borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
              backgroundColor: AppColors.lightSurfaceMuted,
              valueColor: const AlwaysStoppedAnimation(AppColors.accentGreen),
            ),
          ],
        ),
      );
    }).toList();
  }
}

class _DailySpendingChart extends StatelessWidget {
  const _DailySpendingChart({required this.dailySpendingMinor});

  final Map<int, int> dailySpendingMinor;

  @override
  Widget build(BuildContext context) {
    if (dailySpendingMinor.isEmpty) {
      return Center(
        child: Text(
          'No spending data this month yet',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    final sortedDays = dailySpendingMinor.keys.toList()..sort();
    final spots = sortedDays
        .map(
          (d) => FlSpot(
            d.toDouble(),
            dailySpendingMinor[d]! / 100.0,
          ),
        )
        .toList();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => const FlLine(
            color: AppColors.lightBorder,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (value, _) => Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, _) => Text(
                'D${value.toInt()}',
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.accentGreen,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.accentGreen.withValues(alpha: 0.14),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.label,
    required this.amountMinor,
    required this.currencyCode,
    this.positive = false,
  });

  final String label;
  final int amountMinor;
  final String currencyCode;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.lightTextSecondary,
                  fontSize: 11,
                ),
          ),
          const SizedBox(height: 2),
          AmountText(
            amountMinor: amountMinor,
            currencyCode: currencyCode,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: positive
                      ? AppColors.positiveGreen
                      : AppColors.lightTextPrimary,
                ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.accentGreen),
          const SizedBox(width: AppSpacing.xs + 2),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ],
      ),
    );
  }
}
