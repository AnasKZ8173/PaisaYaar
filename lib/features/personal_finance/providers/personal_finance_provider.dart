import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/finance/personal_balance_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/personal_finance_models.dart';
import '../data/personal_finance_repository.dart';

final personalAccountsProvider =
    FutureProvider<List<PersonalAccountModel>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return ref.read(personalFinanceRepositoryProvider).fetchAccounts();
});

final expenseCategoriesProvider =
    FutureProvider<List<ExpenseCategoryModel>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return ref.read(personalFinanceRepositoryProvider).fetchCategories();
});

final personalTransactionsProvider =
    FutureProvider<List<PersonalTransactionModel>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return ref.read(personalFinanceRepositoryProvider).fetchTransactions();
});

final currentMonthBudgetsProvider =
    FutureProvider<List<BudgetModel>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return ref.read(personalFinanceRepositoryProvider).fetchCurrentMonthBudgets();
});

final includeGroupPaymentsInAnalyticsProvider =
    StateProvider<bool>((ref) => false);

final totalPersonalBalanceProvider = Provider<int>((ref) {
  final accounts = ref.watch(personalAccountsProvider).valueOrNull ?? const [];
  return accounts.fold<int>(0, (sum, a) => sum + a.balanceMinor);
});

final monthlyPersonalSummaryProvider = Provider<MonthlyPersonalSummary>((ref) {
  final txs = ref.watch(personalTransactionsProvider).valueOrNull ?? const [];
  final includeGroup = ref.watch(includeGroupPaymentsInAnalyticsProvider);
  final now = DateTime.now();

  return PersonalBalanceService.summarizeMonth(
    transactions: txs
        .map(
          (t) => PersonalTxRecord(
            txType: t.txType,
            amountMinor: t.amountMinor,
            txDate: t.txDate,
            categoryId: t.categoryId,
            categoryName: t.categoryName,
          ),
        )
        .toList(),
    year: now.year,
    month: now.month,
    includeGroupPayments: includeGroup,
  );
});

final remainingMonthlyBudgetProvider = Provider<int>((ref) {
  final budgets =
      ref.watch(currentMonthBudgetsProvider).valueOrNull ?? const [];
  if (budgets.isEmpty) return 0;

  final summary = ref.watch(monthlyPersonalSummaryProvider);
  final totalLimit = budgets.fold<int>(0, (sum, b) => sum + b.limitMinor);
  var spentInBudgetedCats = 0;
  for (final b in budgets) {
    spentInBudgetedCats += summary.categoryTotalsMinor[b.categoryName] ?? 0;
  }
  return totalLimit - spentInBudgetedCats;
});
