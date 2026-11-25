class PersonalTxRecord {
  const PersonalTxRecord({
    required this.txType,
    required this.amountMinor,
    required this.txDate,
    this.categoryId,
    this.categoryName,
  });

  final String txType; // income | expense | transfer | cash_withdrawal | group_payment | reimbursement
  final int amountMinor;
  final DateTime txDate;
  final String? categoryId;
  final String? categoryName;
}

class MonthlyPersonalSummary {
  const MonthlyPersonalSummary({
    required this.incomeMinor,
    required this.expenseMinor,
    required this.groupPaymentMinor,
    required this.categoryTotalsMinor,
    required this.dailySpendingMinor,
  });

  final int incomeMinor;
  final int expenseMinor;
  final int groupPaymentMinor;
  final Map<String, int> categoryTotalsMinor;
  final Map<int, int> dailySpendingMinor; // day-of-month -> minor
}

/// Pure Dart service for personal spending, income, transfer-neutrality & analytics.
class PersonalBalanceService {
  const PersonalBalanceService._();

  static MonthlyPersonalSummary summarizeMonth({
    required List<PersonalTxRecord> transactions,
    required int year,
    required int month,
    bool includeGroupPayments = false,
  }) {
    var income = 0;
    var expense = 0;
    var groupPayments = 0;
    final categoryTotals = <String, int>{};
    final dailySpending = <int, int>{};

    for (final tx in transactions) {
      if (tx.txDate.year != year || tx.txDate.month != month) continue;

      if (tx.txType == 'income') {
        income += tx.amountMinor;
      } else if (tx.txType == 'expense') {
        expense += tx.amountMinor;
        final cat = tx.categoryName ?? 'Other';
        categoryTotals[cat] = (categoryTotals[cat] ?? 0) + tx.amountMinor;
        dailySpending[tx.txDate.day] =
            (dailySpending[tx.txDate.day] ?? 0) + tx.amountMinor;
      } else if (tx.txType == 'group_payment') {
        groupPayments += tx.amountMinor;
        if (includeGroupPayments) {
          expense += tx.amountMinor;
          dailySpending[tx.txDate.day] =
              (dailySpending[tx.txDate.day] ?? 0) + tx.amountMinor;
        }
      }
      // transfer, cash_withdrawal, reimbursement are intentionally excluded
      // from income/consumption totals to prevent double-counting.
    }

    return MonthlyPersonalSummary(
      incomeMinor: income,
      expenseMinor: expense,
      groupPaymentMinor: groupPayments,
      categoryTotalsMinor: categoryTotals,
      dailySpendingMinor: dailySpending,
    );
  }
}
