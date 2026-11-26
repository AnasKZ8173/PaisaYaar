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
import '../../group_expenses/providers/group_expenses_provider.dart';
import '../../groups/providers/groups_provider.dart';
import '../../notifications/providers/notifications_provider.dart';
import '../../personal_finance/providers/personal_finance_provider.dart';
import '../../profile/providers/profile_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _showWeeklyChart = false; // false = Day, true = Week

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final currency =
        profile?.defaultCurrency ?? SupportedCurrencies.defaultCurrency;

    final totalBalance = ref.watch(totalPersonalBalanceProvider);
    final allPersonalTxs =
        ref.watch(personalTransactionsProvider).valueOrNull ?? const [];
    final groupShares =
        ref.watch(myGroupExpenseSharesProvider).valueOrNull ?? const [];
    final budgets =
        ref.watch(currentMonthBudgetsProvider).valueOrNull ?? const [];
    final groupSummary =
        ref.watch(groupDashboardSummaryProvider).valueOrNull ?? const {};
    final totalOwedMinor =
        (groupSummary['total_owed_minor'] as num?)?.toInt() ?? 0;
    final totalReceivableMinor =
        (groupSummary['total_receivable_minor'] as num?)?.toInt() ?? 0;
    final unreadCount = ref.watch(unreadNotificationsCountProvider);

    final now = DateTime.now();

    // Compute current month metrics combining Personal + Group Shares
    var receivedThisMonthMinor = 0;
    var cashWithdrawnMinor = 0;
    var onlinePaymentsMinor = 0;
    var totalMonthlySpendingMinor = 0;

    final Map<String, int> categoryTotalsMinor = {};
    final Map<int, int> dailySpendingMinor = {};
    final Map<int, int> weeklySpendingMinor = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

    final List<_RecentExpenseRow> combinedRecentExpenses = [];

    for (final tx in allPersonalTxs) {
      if (tx.txDate.year == now.year && tx.txDate.month == now.month) {
        if (tx.txType == 'income' || tx.txType == 'reimbursement') {
          receivedThisMonthMinor += tx.amountMinor;
        } else if (tx.txType == 'cash_withdrawal') {
          cashWithdrawnMinor += tx.amountMinor;
        } else if (tx.txType == 'group_payment') {
          if (tx.paymentMethod != 'cash') {
            onlinePaymentsMinor += tx.amountMinor;
          }
        } else if (tx.txType == 'expense') {
          totalMonthlySpendingMinor += tx.amountMinor;
          if (tx.paymentMethod != 'cash') {
            onlinePaymentsMinor += tx.amountMinor;
          }
          final cat = tx.categoryName ?? 'Other';
          categoryTotalsMinor[cat] =
              (categoryTotalsMinor[cat] ?? 0) + tx.amountMinor;
          dailySpendingMinor[tx.txDate.day] =
              (dailySpendingMinor[tx.txDate.day] ?? 0) + tx.amountMinor;
          final week = ((tx.txDate.day - 1) ~/ 7) + 1;
          weeklySpendingMinor[week] =
              (weeklySpendingMinor[week] ?? 0) + tx.amountMinor;
        }
      }
      if (tx.txType == 'expense') {
        combinedRecentExpenses.add(
          _RecentExpenseRow(
            title: tx.title,
            subtitle: '${tx.categoryName ?? 'Expense'} • Personal',
            amountMinor: tx.amountMinor,
            currency: currency,
            date: tx.txDate,
          ),
        );
      }
    }

    // Include user's share of approved group expenses in charts & category totals
    for (final gs in groupShares) {
      final dateStr = gs['expense_date'] as String?;
      if (dateStr == null) continue;
      final dt = DateTime.tryParse(dateStr);
      if (dt == null) continue;
      final share = (gs['my_share_minor'] as num?)?.toInt() ?? 0;
      if (share <= 0) continue;

      if (dt.year == now.year && dt.month == now.month) {
        totalMonthlySpendingMinor += share;
        final cat = (gs['category'] as String?) ?? 'Other';
        categoryTotalsMinor[cat] = (categoryTotalsMinor[cat] ?? 0) + share;
        dailySpendingMinor[dt.day] =
            (dailySpendingMinor[dt.day] ?? 0) + share;
        final week = ((dt.day - 1) ~/ 7) + 1;
        weeklySpendingMinor[week] = (weeklySpendingMinor[week] ?? 0) + share;
      }

      combinedRecentExpenses.add(
        _RecentExpenseRow(
          title: '${gs['group_name']} • ${gs['title']}',
          subtitle: '${gs['category'] ?? 'Group'} • Group Share',
          amountMinor: share,
          currency: (gs['currency'] as String?) ?? currency,
          date: dt,
        ),
      );
    }

    combinedRecentExpenses.sort((a, b) => b.date.compareTo(a.date));

    // Budget limits by category name
    final budgetLimits = {
      for (final b in budgets) b.categoryName: b.limitMinor,
    };

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(personalAccountsProvider);
          ref.invalidate(personalTransactionsProvider);
          ref.invalidate(currentMonthBudgetsProvider);
          ref.invalidate(groupDashboardSummaryProvider);
          ref.invalidate(myGroupExpenseSharesProvider);
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
                  // 1. Hero Balance & Quick Totals
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
                            Text(
                              currency,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.accentGreenDark,
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
                                label: 'Received (Month)',
                                amountMinor: receivedThisMonthMinor,
                                currencyCode: currency,
                                positive: true,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: _MiniMetric(
                                label: 'Total Spending',
                                amountMinor: totalMonthlySpendingMinor,
                                currencyCode: currency,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 2. Key Monthly Metrics Grid
                  Row(
                    children: [
                      Expanded(
                        child: AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cash Withdrawn',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 2),
                              AmountText(
                                amountMinor: cashWithdrawnMinor,
                                currencyCode: currency,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Online Payments',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 2),
                              AmountText(
                                amountMinor: onlinePaymentsMinor,
                                currencyCode: currency,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
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

                  // 3. Day / Week Comparison Chart (with Radio-Style Toggle)
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Expenses Comparison',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: AppColors.lightSurfaceMuted,
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.pillRadius,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _RadioPill(
                                    label: 'Day',
                                    selected: !_showWeeklyChart,
                                    onTap: () => setState(
                                      () => _showWeeklyChart = false,
                                    ),
                                  ),
                                  _RadioPill(
                                    label: 'Week',
                                    selected: _showWeeklyChart,
                                    onTap: () => setState(
                                      () => _showWeeklyChart = true,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        SizedBox(
                          height: 170,
                          child: _ComparisonBarChart(
                            dataMap: _showWeeklyChart
                                ? weeklySpendingMinor
                                : dailySpendingMinor,
                            isWeekly: _showWeeklyChart,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 4. Spending Trend Line Chart (Personal + Group Expenses)
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Spending Trend This Month',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        SizedBox(
                          height: 160,
                          child: _DailySpendingLineChart(
                            dailySpendingMinor: dailySpendingMinor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 5. Category Breakdown with Red Budget Warnings
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Category Breakdown & Budgets',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (categoryTotalsMinor.isEmpty)
                          Text(
                            'No expenses recorded this month yet.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          )
                        else
                          ..._buildCategoryBars(
                            context,
                            categoryTotalsMinor,
                            budgetLimits,
                            totalMonthlySpendingMinor,
                            currency,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Quick Actions
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
                          icon: AppIcons.users,
                          label: l10n.t('create_group'),
                          onTap: () => context.go(RoutePaths.groups),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _QuickActionChip(
                          icon: AppIcons.coins,
                          label: 'Loans',
                          onTap: () => context.push(RoutePaths.loans),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _QuickActionChip(
                          icon: Icons.bar_chart_rounded,
                          label: 'Reports',
                          onTap: () => context.push(RoutePaths.reports),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // 6. Recent Expenses (Placed AFTER Charts)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Expenses',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      TextButton(
                        onPressed: () => context.push(RoutePaths.reports),
                        child: const Text('All'),
                      ),
                    ],
                  ),
                  if (combinedRecentExpenses.isEmpty)
                    const AppCard(child: Text('No recent expenses.'))
                  else
                    ...combinedRecentExpenses.take(5).map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: AppCard(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.title,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall,
                                        ),
                                        Text(
                                          '${item.subtitle} • ${item.date.toIso8601String().split('T').first}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  AmountText(
                                    amountMinor: -item.amountMinor,
                                    currencyCode: item.currency,
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
    Map<String, int> budgetLimits,
    int totalExpense,
    String currency,
  ) {
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final denom = totalExpense <= 0 ? 1 : totalExpense;

    return entries.map((e) {
      final limit = budgetLimits[e.key];
      final overBudget = limit != null && e.value > limit;
      final ratio = limit != null
          ? (e.value / limit).clamp(0.0, 1.0)
          : (e.value / denom).clamp(0.0, 1.0);
      final barColor =
          overBudget ? AppColors.negativeRed : AppColors.accentGreen;

      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      e.key,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: overBudget ? AppColors.negativeRed : null,
                            fontWeight: overBudget ? FontWeight.w700 : null,
                          ),
                    ),
                    if (overBudget) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.negativeRedSoft,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.pillRadius,
                          ),
                        ),
                        child: const Text(
                          'OVER BUDGET',
                          style: TextStyle(
                            color: AppColors.negativeRed,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  limit != null
                      ? '${(e.value / 100).toStringAsFixed(0)} / ${(limit / 100).toStringAsFixed(0)} $currency'
                      : '${(e.value / 100).toStringAsFixed(0)} $currency',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: overBudget ? AppColors.negativeRed : null,
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
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ],
        ),
      );
    }).toList();
  }
}

class _RecentExpenseRow {
  const _RecentExpenseRow({
    required this.title,
    required this.subtitle,
    required this.amountMinor,
    required this.currency,
    required this.date,
  });

  final String title;
  final String subtitle;
  final int amountMinor;
  final String currency;
  final DateTime date;
}

class _RadioPill extends StatelessWidget {
  const _RadioPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.lightTextSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ComparisonBarChart extends StatelessWidget {
  const _ComparisonBarChart({
    required this.dataMap,
    required this.isWeekly,
  });

  final Map<int, int> dataMap;
  final bool isWeekly;

  @override
  Widget build(BuildContext context) {
    final keys = dataMap.keys.toList()..sort();
    if (keys.isEmpty || dataMap.values.every((v) => v == 0)) {
      return Center(
        child: Text(
          'No expenses this month yet',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    return BarChart(
      BarChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => const FlLine(
            color: AppColors.lightBorder,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
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
              reservedSize: 42,
              getTitlesWidget: (v, _) => Text(
                v.toInt().toString(),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) => Text(
                isWeekly ? 'W${v.toInt()}' : 'D${v.toInt()}',
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
        ),
        barGroups: keys
            .map(
              (k) => BarChartGroupData(
                x: k,
                barRods: [
                  BarChartRodData(
                    toY: (dataMap[k] ?? 0) / 100.0,
                    color: AppColors.accentGreen,
                    width: isWeekly ? 20 : 10,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}

class _DailySpendingLineChart extends StatelessWidget {
  const _DailySpendingLineChart({required this.dailySpendingMinor});

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
