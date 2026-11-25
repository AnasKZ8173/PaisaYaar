import 'package:flutter_test/flutter_test.dart';
import 'package:pocketyaar/core/services/finance/group_balance_service.dart';
import 'package:pocketyaar/core/services/finance/settlement_optimizer_service.dart';
import 'package:pocketyaar/core/services/finance/split_calculator_service.dart';

void main() {
  group('SplitCalculatorService', () {
    test('distributes equal split remainder deterministically', () {
      final shares = SplitCalculatorService.calculateEqualSplit(
        totalMinor: 1000, // 10.00 PKR among 3 -> 334, 333, 333
        participantUserIds: ['anas', 'ali', 'ahmed'],
      );
      expect(shares['anas'], 334);
      expect(shares['ali'], 333);
      expect(shares['ahmed'], 333);
      expect(shares.values.fold<int>(0, (a, b) => a + b), 1000);
    });

    test('validates multi-payer contributions equal total', () {
      expect(
        SplitCalculatorService.validatePayers(
          totalMinor: 1000000,
          payerAmountsMinor: {
            'anas': 600000,
            'ali': 250000,
            'ahmed': 150000,
          },
        ),
        isNull,
      );
      expect(
        SplitCalculatorService.validatePayers(
          totalMinor: 1000000,
          payerAmountsMinor: {'anas': 500000},
        ),
        isNotNull,
      );
    });
  });

  group('GroupBalanceService & SettlementOptimizerService', () {
    test('nets multiple expenses and confirmed settlements accurately', () {
      // Expense 1: Total 10,000 paid by Anas (6k), Ali (2.5k), Ahmed (1.5k)
      // Split equally among Anas & Ali only (5k each), Ahmed excluded
      // Expense 2: Ali pays 2,000 for Ahmed
      final balances = GroupBalanceService.calculateBalances(
        memberIds: ['anas', 'ali', 'ahmed'],
        approvedExpenses: const [
          GroupExpenseLedgerEntry(
            payersMinor: {'anas': 600000, 'ali': 250000, 'ahmed': 150000},
            sharesMinor: {'anas': 500000, 'ali': 500000},
          ),
          GroupExpenseLedgerEntry(
            payersMinor: {'ali': 200000},
            sharesMinor: {'ahmed': 200000},
          ),
        ],
        confirmedSettlements: const [
          // Ahmed pays Anas 500
          ConfirmedSettlementEntry(
            senderId: 'ahmed',
            receiverId: 'anas',
            amountMinor: 50000,
          ),
        ],
      );

      // Anas: +6000 - 5000 - 500 = +500
      expect(balances['anas']!.netBalanceMinor, 50000);
      // Ali: +2500 - 5000 + 2000 = -500
      expect(balances['ali']!.netBalanceMinor, -50000);
      // Ahmed: +1500 - 2000 + 500 = 0
      expect(balances['ahmed']!.netBalanceMinor, 0);

      final plan = SettlementOptimizerService.optimize({
        for (final e in balances.entries) e.key: e.value.netBalanceMinor,
      });

      expect(plan.length, 1);
      expect(plan.first.fromUserId, 'ali');
      expect(plan.first.toUserId, 'anas');
      expect(plan.first.amountMinor, 50000);
    });
  });
}
