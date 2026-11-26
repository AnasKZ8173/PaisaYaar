import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../personal_finance/providers/personal_finance_provider.dart';

enum _ReportPeriod { currentMonth, lastMonth, last3Months }

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  _ReportPeriod _period = _ReportPeriod.currentMonth;
  String _selectedCategory = 'All';
  String _selectedType = 'all'; // all | expense | loan_given | income | transfer | cash_withdrawal
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final txsAsync = ref.watch(personalTransactionsProvider);
    final categories =
        ref.watch(expenseCategoriesProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Reports & Transactions')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(personalTransactionsProvider);
          ref.invalidate(expenseCategoriesProvider);
        },
        child: txsAsync.when(
          loading: () => const AppLoadingView(),
          error: (e, _) => AppErrorState(
            message: e.toString(),
            onRetry: () => ref.invalidate(personalTransactionsProvider),
          ),
          data: (allTxs) {
            final now = DateTime.now();
            final currentMonthStart = DateTime(now.year, now.month, 1);
            final lastMonthStart = DateTime(now.year, now.month - 1, 1);
            final threeMonthsStart = DateTime(now.year, now.month - 2, 1);

            final filtered = allTxs.where((tx) {
              // Period filter
              final inPeriod = switch (_period) {
                _ReportPeriod.currentMonth =>
                  !tx.txDate.isBefore(currentMonthStart),
                _ReportPeriod.lastMonth =>
                  !tx.txDate.isBefore(lastMonthStart) &&
                      tx.txDate.isBefore(currentMonthStart),
                _ReportPeriod.last3Months =>
                  !tx.txDate.isBefore(threeMonthsStart),
              };
              if (!inPeriod) return false;

              // Type filter
              if (_selectedType == 'loan_given') {
                if ((tx.categoryName ?? '').toLowerCase() != 'loan given') {
                  return false;
                }
              } else if (_selectedType != 'all' && tx.txType != _selectedType) {
                return false;
              }

              // Category filter
              if (_selectedCategory != 'All' &&
                  (tx.categoryName ?? 'Other') != _selectedCategory) {
                return false;
              }

              // Search filter
              if (_searchQuery.trim().isNotEmpty) {
                final q = _searchQuery.trim().toLowerCase();
                final matches = tx.title.toLowerCase().contains(q) ||
                    (tx.categoryName ?? '').toLowerCase().contains(q) ||
                    tx.note.toLowerCase().contains(q) ||
                    tx.recipientName.toLowerCase().contains(q);
                if (!matches) return false;
              }

              return true;
            }).toList();

            final totalMinor = filtered.fold<int>(
              0,
              (s, tx) => s + tx.amountMinor,
            );

            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                // Period Toggle
                SegmentedButton<_ReportPeriod>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: _ReportPeriod.currentMonth,
                      label: Text('This Month'),
                    ),
                    ButtonSegment(
                      value: _ReportPeriod.lastMonth,
                      label: Text('Last Month'),
                    ),
                    ButtonSegment(
                      value: _ReportPeriod.last3Months,
                      label: Text('3 Months'),
                    ),
                  ],
                  selected: {_period},
                  onSelectionChanged: (s) => setState(() => _period = s.first),
                ),
                const SizedBox(height: AppSpacing.md),

                // Search & Filters
                TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: const InputDecoration(
                    hintText: 'Search by title, category, or note...',
                    prefixIcon: Icon(AppIcons.search, size: 18),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedCategory,
                        decoration:
                            const InputDecoration(labelText: 'Category'),
                        items: [
                          const DropdownMenuItem(
                            value: 'All',
                            child: Text('All Categories'),
                          ),
                          ...categories.map(
                            (c) => DropdownMenuItem(
                              value: c.name,
                              child: Text(c.name),
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedCategory = v);
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedType,
                        decoration: const InputDecoration(labelText: 'Type'),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All')),
                          DropdownMenuItem(
                            value: 'expense',
                            child: Text('Expenses'),
                          ),
                          DropdownMenuItem(
                            value: 'loan_given',
                            child: Text('Loans Given'),
                          ),
                          DropdownMenuItem(
                            value: 'income',
                            child: Text('Income'),
                          ),
                          DropdownMenuItem(
                            value: 'transfer',
                            child: Text('Transfers'),
                          ),
                          DropdownMenuItem(
                            value: 'cash_withdrawal',
                            child: Text('Withdrawals'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedType = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // Summary Card
                AppCard(
                  backgroundColor: AppColors.accentGreenSoft,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${filtered.length} transactions',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      AmountText(
                        amountMinor: totalMinor,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                if (filtered.isEmpty)
                  const AppEmptyState(
                    icon: AppIcons.wallet,
                    title: 'No matching transactions',
                    subtitle: 'Try changing the period or category filter.',
                  )
                else
                  ...filtered.map(
                    (tx) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: AppCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tx.title,
                                    style:
                                        Theme.of(context).textTheme.titleSmall,
                                  ),
                                  Text(
                                    '${tx.categoryName ?? tx.txType.toUpperCase()} • ${tx.txDate.toIso8601String().split('T').first}',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            AmountText(
                              amountMinor: tx.txType == 'income' ||
                                      tx.txType == 'reimbursement'
                                  ? tx.amountMinor
                                  : -tx.amountMinor,
                              showSign: true,
                              colorBySign: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
