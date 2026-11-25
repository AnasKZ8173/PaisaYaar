import 'package:flutter_test/flutter_test.dart';
import 'package:pocketyaar/core/services/finance/personal_balance_service.dart';

void main() {
  group('PersonalBalanceService', () {
    test('excludes transfers, withdrawals, and group payments by default', () {
      final summary = PersonalBalanceService.summarizeMonth(
        year: 2026,
        month: 11,
        transactions: [
          PersonalTxRecord(
            txType: 'income',
            amountMinor: 15000000,
            txDate: DateTime(2026, 11, 1),
          ),
          PersonalTxRecord(
            txType: 'expense',
            amountMinor: 500000,
            txDate: DateTime(2026, 11, 5),
            categoryName: 'Food',
          ),
          PersonalTxRecord(
            txType: 'cash_withdrawal',
            amountMinor: 1000000,
            txDate: DateTime(2026, 11, 6),
          ),
          PersonalTxRecord(
            txType: 'group_payment',
            amountMinor: 300000,
            txDate: DateTime(2026, 11, 7),
          ),
        ],
      );

      expect(summary.incomeMinor, 15000000);
      expect(summary.expenseMinor, 500000);
      expect(summary.groupPaymentMinor, 300000);
      expect(summary.categoryTotalsMinor['Food'], 500000);
      expect(summary.dailySpendingMinor[5], 500000);
    });
  });
}
