import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/router/route_names.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/top_action_bar.dart';
import '../../loans/data/loan_model.dart';
import '../../loans/data/loan_repository.dart';
import '../../loans/providers/loans_provider.dart';
import '../../notifications/providers/notifications_provider.dart';
import '../../profile/data/profile_model.dart';
import '../../profile/data/profile_repository.dart';
import '../data/personal_finance_models.dart';
import '../data/personal_finance_repository.dart';
import '../providers/personal_finance_provider.dart';

class PersonalScreen extends ConsumerStatefulWidget {
  const PersonalScreen({super.key});

  @override
  ConsumerState<PersonalScreen> createState() => _PersonalScreenState();
}

class _PersonalScreenState extends ConsumerState<PersonalScreen> {
  String _txFilter = 'all';

  Future<void> _openAddAccountSheet({
    PersonalAccountModel? editingAccount,
  }) async {
    final nameCtrl = TextEditingController(text: editingAccount?.name ?? '');
    final balanceCtrl = TextEditingController(
      text: editingAccount != null
          ? (editingAccount.balanceMinor / 100).toStringAsFixed(0)
          : '0',
    );
    var accountType = editingAccount?.accountType ?? 'bank';
    var saving = false;

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SingleChildScrollView(
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
                editingAccount != null
                    ? 'Edit Personal Account'
                    : 'Add Personal Account',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: nameCtrl,
                label: 'Account name',
                hint: 'e.g. Meezan Bank / Easypaisa',
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: accountType,
                decoration: const InputDecoration(labelText: 'Account type'),
                items: const [
                  DropdownMenuItem(value: 'bank', child: Text('Bank')),
                  DropdownMenuItem(
                    value: 'easypaisa',
                    child: Text('Easypaisa'),
                  ),
                  DropdownMenuItem(value: 'jazzcash', child: Text('JazzCash')),
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'custom', child: Text('Custom')),
                ],
                onChanged: (v) {
                  if (v != null) setModalState(() => accountType = v);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: balanceCtrl,
                label: 'Available balance (PKR)',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Save Account',
                isLoading: saving,
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) return;
                  final major = double.tryParse(balanceCtrl.text.trim()) ?? 0;
                  setModalState(() => saving = true);
                  try {
                    final repo = ref.read(personalFinanceRepositoryProvider);
                    if (editingAccount != null) {
                      await repo.updateAccount(
                        accountId: editingAccount.id,
                        name: nameCtrl.text,
                        accountType: accountType,
                        balanceMinor: (major * 100).round(),
                      );
                    } else {
                      await repo.createAccount(
                        name: nameCtrl.text,
                        accountType: accountType,
                        initialBalanceMinor: (major * 100).round(),
                      );
                    }
                    ref.invalidate(personalAccountsProvider);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  } finally {
                    if (ctx.mounted) setModalState(() => saving = false);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openRecordTxSheet({
    required String initialType,
    required List<PersonalAccountModel> accounts,
    required List<ExpenseCategoryModel> categories,
    PersonalTransactionModel? editingTx,
  }) async {
    final needsAccountByDefault =
        initialType == 'transfer' || initialType == 'cash_withdrawal';
    if (editingTx == null && needsAccountByDefault && accounts.isEmpty) {
      await _openAddAccountSheet();
      return;
    }

    final titleCtrl = TextEditingController(text: editingTx?.title ?? '');
    final amountCtrl = TextEditingController(
      text: editingTx != null
          ? (editingTx.amountMinor / 100).toStringAsFixed(0)
          : '',
    );
    final recipientCtrl =
        TextEditingController(text: editingTx?.recipientName ?? '');
    final sourceCtrl = TextEditingController(text: editingTx?.source ?? '');
    final noteCtrl = TextEditingController(text: editingTx?.note ?? '');

    var txType = editingTx?.txType ?? initialType; // expense | income | transfer | cash_withdrawal
    var incomeKind = editingTx?.incomeKind ?? 'fixed'; // fixed | extra
    var expenseMethod = editingTx != null
        ? (editingTx.paymentMethod == 'cash' ? 'cash' : 'account')
        : 'cash'; // cash | account
    String? accountId = editingTx?.accountId ??
        (accounts.isNotEmpty ? accounts.first.id : null);
    String? categoryId = editingTx?.categoryId ??
        (categories.isNotEmpty ? categories.first.id : null);
    PublicProfileSearchResult? selectedBorrower;
    List<PublicProfileSearchResult> borrowerMatches = const [];
    DateTime? loanDueDate;
    var isLoanRepayment = false;
    LoanModel? selectedRepayLoan;
    final activeBorrowedLoans = ref.read(activeBorrowedLoansProvider);
    var saving = false;
    String? err;

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isIncome = txType == 'income';
          final isExpense = txType == 'expense';
          final isTransfer = txType == 'transfer';
          final isWithdrawal = txType == 'cash_withdrawal';

          final showAccountDropdown = isTransfer ||
              isWithdrawal ||
              (isExpense && expenseMethod == 'account');

          final selectedCat = categories
              .where((c) => c.id == categoryId)
              .firstOrNull;
          final isLoanGivenCategory = editingTx == null &&
              isExpense &&
              selectedCat?.name.toLowerCase() == 'loan given';

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
                  switch (txType) {
                    'income' => 'Record Income (Separate)',
                    'transfer' => 'Transfer To',
                    'cash_withdrawal' => 'Cash Withdrawal',
                    _ => 'Record Expense',
                  },
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'expense', label: Text('Expense')),
                    ButtonSegment(value: 'income', label: Text('Income')),
                    ButtonSegment(value: 'transfer', label: Text('Transfer')),
                    ButtonSegment(
                      value: 'cash_withdrawal',
                      label: Text('Withdraw'),
                    ),
                  ],
                  selected: {txType},
                  onSelectionChanged: (sel) => setModalState(() {
                    txType = sel.first;
                    err = null;
                  }),
                ),
                const SizedBox(height: AppSpacing.md),

                if (isIncome) ...[
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: 'fixed',
                        label: Text('Fixed Income'),
                      ),
                      ButtonSegment(
                        value: 'extra',
                        label: Text('Received / Extra'),
                      ),
                    ],
                    selected: {incomeKind},
                    onSelectionChanged: (sel) =>
                        setModalState(() => incomeKind = sel.first),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: sourceCtrl,
                    label: incomeKind == 'fixed'
                        ? 'Source (e.g. Monthly Salary)'
                        : 'Received from (e.g. Freelance / Ali)',
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                if (isExpense) ...[
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: 'cash',
                        label: Text('Cash (No balance deduct)'),
                      ),
                      ButtonSegment(
                        value: 'account',
                        label: Text('Account (Deducts)'),
                      ),
                    ],
                    selected: {expenseMethod},
                    onSelectionChanged: (sel) =>
                        setModalState(() => expenseMethod = sel.first),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                if (isTransfer) ...[
                  AppTextField(
                    controller: recipientCtrl,
                    label: 'Transfer to (Name)',
                    hint: 'e.g. Ali, Ammi, Rent',
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                AppTextField(
                  controller: titleCtrl,
                  label: isTransfer
                      ? 'Purpose / Title'
                      : isWithdrawal
                          ? 'Withdrawal note'
                          : 'Title',
                  hint: isIncome
                      ? 'e.g. November Salary'
                      : isWithdrawal
                          ? 'e.g. ATM Cash'
                          : isTransfer
                              ? 'e.g. Home expenses'
                              : 'e.g. Groceries',
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: amountCtrl,
                  label: 'Amount (PKR)',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),

                if (showAccountDropdown) ...[
                  const SizedBox(height: AppSpacing.md),
                  if (accounts.isEmpty)
                    const Text(
                      'Add an account first to deduct from available balance.',
                      style: TextStyle(color: AppColors.negativeRed),
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue: accountId,
                      decoration: const InputDecoration(
                        labelText: 'From account (deducts available balance)',
                      ),
                      items: accounts
                          .map(
                            (a) => DropdownMenuItem(
                              value: a.id,
                              child: Text(
                                '${a.name} (${(a.balanceMinor / 100).toStringAsFixed(0)} ${a.currency})',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setModalState(() => accountId = v),
                    ),
                ],

                if (isExpense && categories.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    initialValue: categoryId,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: categories
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setModalState(() {
                      categoryId = v;
                      isLoanRepayment = false;
                    }),
                  ),
                ],

                if (isLoanGivenCategory) ...[
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    decoration: InputDecoration(
                      labelText: selectedBorrower == null
                          ? 'Search borrower by public ID'
                          : 'Borrower: ${selectedBorrower!.fullName} (@${selectedBorrower!.publicId})',
                      prefixIcon: const Icon(AppIcons.search, size: 18),
                    ),
                    onChanged: (q) async {
                      if (q.trim().length < 2) {
                        setModalState(() => borrowerMatches = const []);
                        return;
                      }
                      final res = await ref
                          .read(profileRepositoryProvider)
                          .searchPublicProfiles(q);
                      if (ctx.mounted) {
                        setModalState(() => borrowerMatches = res);
                      }
                    },
                  ),
                  if (borrowerMatches.isNotEmpty)
                    ...borrowerMatches.take(4).map(
                          (u) => ListTile(
                            dense: true,
                            title: Text(u.fullName),
                            subtitle: Text('@${u.publicId}'),
                            onTap: () => setModalState(() {
                              selectedBorrower = u;
                              borrowerMatches = const [];
                            }),
                          ),
                        ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate:
                            DateTime.now().add(const Duration(days: 7)),
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 3650)),
                      );
                      if (picked != null) {
                        setModalState(() => loanDueDate = picked);
                      }
                    },
                    icon: const Icon(Icons.calendar_today_outlined, size: 16),
                    label: Text(
                      loanDueDate == null
                          ? 'Optional repayment due date'
                          : 'Due: ${loanDueDate!.toIso8601String().split('T').first}',
                    ),
                  ),
                ],

                if (editingTx == null &&
                    isExpense &&
                    expenseMethod == 'account' &&
                    !isLoanGivenCategory &&
                    activeBorrowedLoans.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mark as Loan Repayment'),
                    value: isLoanRepayment,
                    onChanged: (v) => setModalState(() {
                      isLoanRepayment = v;
                      if (v && selectedRepayLoan == null) {
                        selectedRepayLoan = activeBorrowedLoans.first;
                        amountCtrl.text =
                            (selectedRepayLoan!.remainingMinor / 100)
                                .toStringAsFixed(0);
                        titleCtrl.text =
                            'Loan Repayment: ${selectedRepayLoan!.title}';
                      }
                    }),
                  ),
                  if (isLoanRepayment)
                    DropdownButtonFormField<String>(
                      initialValue: selectedRepayLoan?.id,
                      decoration: const InputDecoration(
                        labelText: 'Select Active Loan',
                      ),
                      items: activeBorrowedLoans
                          .map(
                            (l) => DropdownMenuItem(
                              value: l.id,
                              child: Text(
                                '${l.title} (${l.lenderName} • ${(l.remainingMinor / 100).toStringAsFixed(0)} ${l.currency})',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (id) {
                        final found = activeBorrowedLoans
                            .where((l) => l.id == id)
                            .firstOrNull;
                        if (found != null) {
                          setModalState(() {
                            selectedRepayLoan = found;
                            amountCtrl.text = (found.remainingMinor / 100)
                                .toStringAsFixed(0);
                            titleCtrl.text = 'Loan Repayment: ${found.title}';
                          });
                        }
                      },
                    ),
                ],

                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: noteCtrl,
                  label: 'Note (optional)',
                ),
                if (err != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    err!,
                    style: const TextStyle(color: AppColors.negativeRed),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: 'Save',
                  isLoading: saving,
                  onPressed: () async {
                    final major = double.tryParse(amountCtrl.text.trim()) ?? 0;
                    if (major <= 0) {
                      setModalState(() => err = 'Enter a valid amount');
                      return;
                    }
                    if (isTransfer && recipientCtrl.text.trim().isEmpty) {
                      setModalState(
                        () => err = 'Enter recipient name for transfer',
                      );
                      return;
                    }
                    if (showAccountDropdown && accountId == null) {
                      setModalState(() => err = 'Please add/select an account');
                      return;
                    }
                    if (isLoanGivenCategory && selectedBorrower == null) {
                      setModalState(
                        () => err = 'Select a borrower for Loan Given',
                      );
                      return;
                    }

                    final effectiveTitle = titleCtrl.text.trim().isNotEmpty
                        ? titleCtrl.text.trim()
                        : isTransfer
                            ? 'Transfer to ${recipientCtrl.text.trim()}'
                            : isWithdrawal
                                ? 'Cash Withdrawal'
                                : (sourceCtrl.text.trim().isNotEmpty
                                    ? sourceCtrl.text.trim()
                                    : 'Income');

                    setModalState(() {
                      saving = true;
                      err = null;
                    });
                    try {
                      final repo = ref.read(personalFinanceRepositoryProvider);
                      if (isLoanRepayment && selectedRepayLoan != null) {
                        await ref.read(loanRepositoryProvider).recordRepayment(
                              loanId: selectedRepayLoan!.id,
                              amountMinor: (major * 100).round(),
                              accountId: accountId,
                              paymentMethod: 'account',
                              note: noteCtrl.text,
                            );
                        ref.invalidate(myLoansProvider);
                      } else if (editingTx != null) {
                        await repo.updateTransaction(
                          txId: editingTx.id,
                          accountId: showAccountDropdown ? accountId : null,
                          txType: txType,
                          amountMinor: (major * 100).round(),
                          title: effectiveTitle,
                          categoryId: isExpense ? categoryId : null,
                          source: sourceCtrl.text,
                          paymentMethod: isExpense ? expenseMethod : 'account',
                          note: noteCtrl.text,
                          recipientName: recipientCtrl.text,
                          incomeKind: incomeKind,
                        );
                      } else {
                        final txId = await repo.recordTransaction(
                          accountId: showAccountDropdown ? accountId : null,
                          txType: txType,
                          amountMinor: (major * 100).round(),
                          title: effectiveTitle,
                          categoryId: isExpense ? categoryId : null,
                          source: sourceCtrl.text,
                          paymentMethod: isExpense ? expenseMethod : 'account',
                          note: noteCtrl.text,
                          recipientName: recipientCtrl.text,
                          incomeKind: incomeKind,
                        );
                        if (isLoanGivenCategory && selectedBorrower != null) {
                          await ref
                              .read(loanRepositoryProvider)
                              .createLoanRequest(
                                borrowerId: selectedBorrower!.id,
                                amountMinor: (major * 100).round(),
                                title: effectiveTitle,
                                dueDate: loanDueDate,
                                note: noteCtrl.text,
                                lenderTxId: txId,
                              );
                          ref.invalidate(myLoansProvider);
                        }
                      }
                      ref.invalidate(personalAccountsProvider);
                      ref.invalidate(personalTransactionsProvider);
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    } catch (e) {
                      setModalState(() => err = e.toString());
                    } finally {
                      if (ctx.mounted) setModalState(() => saving = false);
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openSetBudgetSheet(
    List<ExpenseCategoryModel> categories, {
    BudgetModel? editingBudget,
  }) async {
    if (categories.isEmpty) return;
    var categoryId = editingBudget?.categoryId ?? categories.first.id;
    final limitCtrl = TextEditingController(
      text: editingBudget != null
          ? (editingBudget.limitMinor / 100).toStringAsFixed(0)
          : '',
    );
    var saving = false;

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SingleChildScrollView(
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
                editingBudget != null
                    ? 'Edit Monthly Budget'
                    : 'Set Monthly Budget',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.lg),
              DropdownButtonFormField<String>(
                initialValue: categoryId,
                decoration: const InputDecoration(labelText: 'Category'),
                items: categories
                    .map(
                      (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setModalState(() => categoryId = v);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: limitCtrl,
                label: 'Monthly limit (PKR)',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Save Budget',
                isLoading: saving,
                onPressed: () async {
                  final major = double.tryParse(limitCtrl.text.trim()) ?? 0;
                  if (major <= 0) return;
                  setModalState(() => saving = true);
                  try {
                    await ref
                        .read(personalFinanceRepositoryProvider)
                        .upsertBudget(
                          categoryId: categoryId,
                          limitMinor: (major * 100).round(),
                        );
                    ref.invalidate(currentMonthBudgetsProvider);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  } finally {
                    if (ctx.mounted) setModalState(() => saving = false);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accountsAsync = ref.watch(personalAccountsProvider);
    final categories =
        ref.watch(expenseCategoriesProvider).valueOrNull ?? const [];
    final txsAsync = ref.watch(personalTransactionsProvider);
    final budgets =
        ref.watch(currentMonthBudgetsProvider).valueOrNull ?? const [];
    final summary = ref.watch(monthlyPersonalSummaryProvider);
    final totalAvailableBalance = ref.watch(totalPersonalBalanceProvider);
    final unreadCount = ref.watch(unreadNotificationsCountProvider);

    final accounts = accountsAsync.valueOrNull ?? const [];

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(personalAccountsProvider);
          ref.invalidate(personalTransactionsProvider);
          ref.invalidate(currentMonthBudgetsProvider);
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: TopActionBar(
                title: l10n.t('personal_title'),
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
                  // Action Buttons Row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        AppButton(
                          label: 'Expense',
                          icon: AppIcons.minusCircle,
                          fullWidth: false,
                          onPressed: () => _openRecordTxSheet(
                            initialType: 'expense',
                            accounts: accounts,
                            categories: categories,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        AppButton(
                          label: 'Income',
                          variant: AppButtonVariant.secondary,
                          icon: AppIcons.plusCircle,
                          fullWidth: false,
                          onPressed: () => _openRecordTxSheet(
                            initialType: 'income',
                            accounts: accounts,
                            categories: categories,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        AppButton(
                          label: 'Transfer To',
                          variant: AppButtonVariant.outline,
                          icon: AppIcons.arrowLeftRight,
                          fullWidth: false,
                          onPressed: () => _openRecordTxSheet(
                            initialType: 'transfer',
                            accounts: accounts,
                            categories: categories,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        AppButton(
                          label: 'Withdraw Cash',
                          variant: AppButtonVariant.outline,
                          icon: AppIcons.wallet,
                          fullWidth: false,
                          onPressed: () => _openRecordTxSheet(
                            initialType: 'cash_withdrawal',
                            accounts: accounts,
                            categories: categories,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        AppButton(
                          label: 'Loans',
                          variant: AppButtonVariant.outline,
                          icon: AppIcons.coins,
                          fullWidth: false,
                          onPressed: () => context.push(RoutePaths.loans),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Accounts & Available Balance
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Available Balance (Accounts)',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          AmountText(
                            amountMinor: totalAvailableBalance,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(color: AppColors.accentGreenDark),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: _openAddAccountSheet,
                        icon: const Icon(AppIcons.plusCircle, size: 16),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  accountsAsync.when(
                    loading: () => const AppLoadingView(),
                    error: (e, _) => AppErrorState(message: e.toString()),
                    data: (list) {
                      if (list.isEmpty) {
                        return AppCard(
                          onTap: _openAddAccountSheet,
                          child: const Text(
                            'No accounts yet. Tap to add Bank, Easypaisa, or JazzCash.',
                          ),
                        );
                      }
                      return SizedBox(
                        height: 112,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: list.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(width: AppSpacing.md),
                          itemBuilder: (_, i) {
                            final acc = list[i];
                            return SizedBox(
                              width: 185,
                              child: AppCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${acc.name} (${acc.accountType.toUpperCase()})',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ),
                                        PopupMenuButton<String>(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          iconSize: 18,
                                          onSelected: (action) async {
                                            if (action == 'edit') {
                                              await _openAddAccountSheet(
                                                editingAccount: acc,
                                              );
                                            } else if (action == 'remove') {
                                              await ref
                                                  .read(
                                                    personalFinanceRepositoryProvider,
                                                  )
                                                  .removeAccount(acc.id);
                                              ref.invalidate(
                                                personalAccountsProvider,
                                              );
                                            }
                                          },
                                          itemBuilder: (_) => const [
                                            PopupMenuItem(
                                              value: 'edit',
                                              child: Text('Edit'),
                                            ),
                                            PopupMenuItem(
                                              value: 'remove',
                                              child: Text(
                                                'Remove',
                                                style: TextStyle(
                                                  color: AppColors.negativeRed,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    AmountText(
                                      amountMinor: acc.balanceMinor,
                                      currencyCode: acc.currency,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Monthly Budgets
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Monthly Budgets',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      TextButton.icon(
                        onPressed: () => _openSetBudgetSheet(categories),
                        icon: const Icon(AppIcons.plusCircle, size: 16),
                        label: const Text('Set Budget'),
                      ),
                    ],
                  ),
                  if (budgets.isEmpty)
                    const AppCard(
                      child: Text('No monthly budgets set yet.'),
                    )
                  else
                    ...budgets.map((b) {
                      final spent =
                          summary.categoryTotalsMinor[b.categoryName] ?? 0;
                      final ratio = (spent / b.limitMinor).clamp(0.0, 1.0);
                      final over = spent > b.limitMinor;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        b.categoryName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall,
                                      ),
                                    ),
                                    Text(
                                      '${(spent / 100).toStringAsFixed(0)} / ${(b.limitMinor / 100).toStringAsFixed(0)} ${b.currency}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: over
                                                ? AppColors.negativeRed
                                                : null,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    PopupMenuButton<String>(
                                      iconSize: 18,
                                      onSelected: (action) async {
                                        if (action == 'edit') {
                                          await _openSetBudgetSheet(
                                            categories,
                                            editingBudget: b,
                                          );
                                        } else if (action == 'delete') {
                                          await ref
                                              .read(
                                                personalFinanceRepositoryProvider,
                                              )
                                              .deleteBudget(b.id);
                                          ref.invalidate(
                                            currentMonthBudgetsProvider,
                                          );
                                        }
                                      },
                                      itemBuilder: (_) => const [
                                        PopupMenuItem(
                                          value: 'edit',
                                          child: Text('Edit'),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Text(
                                            'Delete',
                                            style: TextStyle(
                                              color: AppColors.negativeRed,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              const SizedBox(height: AppSpacing.sm),
                              LinearProgressIndicator(
                                value: ratio,
                                minHeight: 7,
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.pillRadius,
                                ),
                                backgroundColor: AppColors.lightSurfaceMuted,
                                valueColor: AlwaysStoppedAnimation(
                                  over
                                      ? AppColors.negativeRed
                                      : AppColors.accentGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: AppSpacing.lg),

                  // Transaction History
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Transactions',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      DropdownButton<String>(
                        value: _txFilter,
                        underline: const SizedBox.shrink(),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All')),
                          DropdownMenuItem(
                            value: 'expense',
                            child: Text('Expenses'),
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
                          if (v != null) setState(() => _txFilter = v);
                        },
                      ),
                    ],
                  ),
                  txsAsync.when(
                    loading: () => const AppLoadingView(),
                    error: (e, _) => AppErrorState(message: e.toString()),
                    data: (txs) {
                      final filtered = txs
                          .where(
                            (t) =>
                                _txFilter == 'all' || t.txType == _txFilter,
                          )
                          .toList();
                      if (filtered.isEmpty) {
                        return const AppCard(
                          child: Text('No transactions recorded yet.'),
                        );
                      }
                      return Column(
                        children: filtered
                            .map(
                              (tx) => Padding(
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
                                              tx.title,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleSmall,
                                            ),
                                            Text(
                                              _subtitleForTx(tx),
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
                                        showSign: true,
                                        colorBySign: true,
                                      ),
                                      PopupMenuButton<String>(
                                        onSelected: (action) async {
                                          if (action == 'edit') {
                                            await _openRecordTxSheet(
                                              initialType: tx.txType,
                                              accounts: accounts,
                                              categories: categories,
                                              editingTx: tx,
                                            );
                                          } else if (action == 'delete') {
                                            await ref
                                                .read(
                                                  personalFinanceRepositoryProvider,
                                                )
                                                .deleteTransaction(tx.id);
                                            ref.invalidate(
                                              personalAccountsProvider,
                                            );
                                            ref.invalidate(
                                              personalTransactionsProvider,
                                            );
                                          }
                                        },
                                        itemBuilder: (_) => const [
                                          PopupMenuItem(
                                            value: 'edit',
                                            child: Text('Edit'),
                                          ),
                                          PopupMenuItem(
                                            value: 'delete',
                                            child: Text(
                                              'Delete',
                                              style: TextStyle(
                                                color: AppColors.negativeRed,
                                              ),
                                            ),
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _subtitleForTx(PersonalTransactionModel tx) {
    final date = tx.txDate.toIso8601String().split('T').first;
    if (tx.txType == 'income') {
      final kind = tx.incomeKind == 'fixed' ? 'Fixed Income' : 'Received';
      final src = tx.source.isNotEmpty ? ' • ${tx.source}' : '';
      return '$kind$src • $date';
    }
    if (tx.txType == 'transfer') {
      final to = tx.recipientName.isNotEmpty ? 'To ${tx.recipientName}' : 'Transfer';
      return '$to • $date';
    }
    if (tx.txType == 'cash_withdrawal') {
      return 'Cash Withdrawal • $date';
    }
    final method = tx.paymentMethod == 'cash' ? 'Cash (No balance deduct)' : 'Account';
    return '${tx.categoryName ?? 'Expense'} • $method • $date';
  }
}
