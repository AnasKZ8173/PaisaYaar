import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/providers/auth_provider.dart';
import '../../personal_finance/providers/personal_finance_provider.dart';
import '../data/loan_model.dart';
import '../data/loan_repository.dart';
import '../providers/loans_provider.dart';

class LoansScreen extends ConsumerStatefulWidget {
  const LoansScreen({super.key});

  @override
  ConsumerState<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends ConsumerState<LoansScreen> {
  String _statusFilter = 'all'; // all | active | pending | paid

  Future<void> _openRepayDialog(LoanModel loan) async {
    final accounts =
        ref.read(personalAccountsProvider).valueOrNull ?? const [];
    final amountCtrl = TextEditingController(
      text: (loan.remainingMinor / 100).toStringAsFixed(0),
    );
    final noteCtrl = TextEditingController();
    String? accountId = accounts.isNotEmpty ? accounts.first.id : null;
    var saving = false;
    String? err;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('Repay ${loan.lenderName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Repayment amount (${loan.currency})',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (accounts.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: accountId,
                  decoration: const InputDecoration(
                    labelText: 'Pay from account (optional)',
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Cash / External'),
                    ),
                    ...accounts.map(
                      (a) => DropdownMenuItem(
                        value: a.id,
                        child: Text(a.name),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => accountId = v),
                ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                ),
              ),
              if (err != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  err!,
                  style: const TextStyle(color: AppColors.negativeRed),
                ),
              ],
            ],
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
                      final major =
                          double.tryParse(amountCtrl.text.trim()) ?? 0;
                      if (major <= 0) return;
                      setState(() {
                        saving = true;
                        err = null;
                      });
                      try {
                        await ref.read(loanRepositoryProvider).recordRepayment(
                              loanId: loan.id,
                              amountMinor: (major * 100).round(),
                              accountId: accountId,
                              paymentMethod:
                                  accountId != null ? 'account' : 'cash',
                              note: noteCtrl.text,
                            );
                        ref.invalidate(myLoansProvider);
                        ref.invalidate(personalAccountsProvider);
                        ref.invalidate(personalTransactionsProvider);
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      } catch (e) {
                        setState(() => err = e.toString());
                      } finally {
                        if (ctx.mounted) setState(() => saving = false);
                      }
                    },
              child: const Text('Submit Repayment'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loansAsync = ref.watch(myLoansProvider);
    final uid = ref.watch(currentUserProvider)?.id ?? '';

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Loans'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Loans Given'),
              Tab(text: 'Loans Received'),
            ],
          ),
        ),
        body: loansAsync.when(
          loading: () => const AppLoadingView(),
          error: (e, _) => AppErrorState(
            message: e.toString(),
            onRetry: () => ref.invalidate(myLoansProvider),
          ),
          data: (allLoans) {
            final given = allLoans.where((l) => l.lenderId == uid).toList();
            final received =
                allLoans.where((l) => l.borrowerId == uid).toList();

            final totalGivenMinor = given
                .where((l) => l.isActive || l.isPaid)
                .fold<int>(0, (s, l) => s + l.amountMinor);
            final activeCount = allLoans.where((l) => l.isActive).length;
            final pendingCount = allLoans.where((l) => l.isPending).length;
            final paidCount = allLoans.where((l) => l.isPaid).length;

            List<LoanModel> applyFilter(List<LoanModel> list) {
              if (_statusFilter == 'all') return list;
              return list.where((l) => l.status == _statusFilter).toList();
            }

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: AppCard(
                              backgroundColor: AppColors.accentGreenSoft,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Total Given'),
                                  const SizedBox(height: 4),
                                  AmountText(
                                    amountMinor: totalGivenMinor,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge,
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
                                  const Text('Active / Pending / Paid'),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$activeCount / $pendingCount / $paidCount',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: ['all', 'active', 'pending', 'paid']
                              .map(
                                (f) => Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                    end: AppSpacing.sm,
                                  ),
                                  child: ChoiceChip(
                                    label: Text(f.toUpperCase()),
                                    selected: _statusFilter == f,
                                    onSelected: (_) =>
                                        setState(() => _statusFilter = f),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _LoanList(
                        loans: applyFilter(given),
                        isLenderView: true,
                        onRefresh: () async => ref.invalidate(myLoansProvider),
                        onCancel: (loan) async {
                          await ref
                              .read(loanRepositoryProvider)
                              .cancelLoanRequest(loan.id);
                          ref.invalidate(myLoansProvider);
                        },
                      ),
                      _LoanList(
                        loans: applyFilter(received),
                        isLenderView: false,
                        onRefresh: () async => ref.invalidate(myLoansProvider),
                        onRespond: (loan, accept) async {
                          await ref
                              .read(loanRepositoryProvider)
                              .respondToLoanRequest(
                                loanId: loan.id,
                                accept: accept,
                              );
                          ref.invalidate(myLoansProvider);
                        },
                        onRepay: _openRepayDialog,
                      ),
                    ],
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

class _LoanList extends StatelessWidget {
  const _LoanList({
    required this.loans,
    required this.isLenderView,
    required this.onRefresh,
    this.onRespond,
    this.onCancel,
    this.onRepay,
  });

  final List<LoanModel> loans;
  final bool isLenderView;
  final Future<void> Function() onRefresh;
  final Future<void> Function(LoanModel loan, bool accept)? onRespond;
  final Future<void> Function(LoanModel loan)? onCancel;
  final Future<void> Function(LoanModel loan)? onRepay;

  @override
  Widget build(BuildContext context) {
    if (loans.isEmpty) {
      return AppEmptyState(
        icon: AppIcons.coins,
        title: isLenderView ? 'No loans given' : 'No loans received',
        subtitle: isLenderView
            ? 'Select "Loan Given" category when adding an expense to send a loan request.'
            : 'Loan requests sent to you will appear here.',
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        itemCount: loans.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final loan = loans[index];
          final counterparty = isLenderView
              ? '${loan.borrowerName} (@${loan.borrowerPublicId})'
              : '${loan.lenderName} (@${loan.lenderPublicId})';

          return AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        loan.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    AmountText(
                      amountMinor: loan.remainingMinor,
                      currencyCode: loan.currency,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${isLenderView ? 'Borrower' : 'Lender'}: $counterparty',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  'Total: ${(loan.amountMinor / 100).toStringAsFixed(0)} ${loan.currency} • Status: ${loan.status.toUpperCase()}'
                  '${loan.dueDate != null ? ' • Due: ${loan.dueDate!.toIso8601String().split('T').first}' : ''}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (loan.isPending && !isLenderView && onRespond != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => onRespond!(loan, false),
                        child: const Text('Reject'),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      FilledButton(
                        onPressed: () => onRespond!(loan, true),
                        child: const Text('Accept'),
                      ),
                    ],
                  ),
                ],
                if (loan.isPending && isLenderView && onCancel != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      onPressed: () => onCancel!(loan),
                      child: const Text('Cancel Request'),
                    ),
                  ),
                ],
                if (loan.isActive && !isLenderView && onRepay != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: FilledButton(
                      onPressed: () => onRepay!(loan),
                      child: const Text('Repay Loan'),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
