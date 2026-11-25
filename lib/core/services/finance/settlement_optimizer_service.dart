class SuggestedSettlement {
  const SuggestedSettlement({
    required this.fromUserId,
    required this.toUserId,
    required this.amountMinor,
  });

  final String fromUserId;
  final String toUserId;
  final int amountMinor;
}

class _BalanceNode {
  _BalanceNode(this.userId, this.amountMinor);
  final String userId;
  int amountMinor;
}

/// Minimizes the number of transactions needed to settle all group balances.
class SettlementOptimizerService {
  const SettlementOptimizerService._();

  static List<SuggestedSettlement> optimize(Map<String, int> netBalancesMinor) {
    final creditors = <_BalanceNode>[];
    final debtors = <_BalanceNode>[];

    netBalancesMinor.forEach((userId, balance) {
      if (balance > 0) {
        creditors.add(_BalanceNode(userId, balance));
      } else if (balance < 0) {
        debtors.add(_BalanceNode(userId, -balance));
      }
    });

    creditors.sort((a, b) => b.amountMinor.compareTo(a.amountMinor));
    debtors.sort((a, b) => b.amountMinor.compareTo(a.amountMinor));

    final result = <SuggestedSettlement>[];
    var i = 0;
    var j = 0;

    while (i < debtors.length && j < creditors.length) {
      final debtor = debtors[i];
      final creditor = creditors[j];
      final transfer = debtor.amountMinor < creditor.amountMinor
          ? debtor.amountMinor
          : creditor.amountMinor;

      if (transfer > 0) {
        result.add(
          SuggestedSettlement(
            fromUserId: debtor.userId,
            toUserId: creditor.userId,
            amountMinor: transfer,
          ),
        );
      }

      debtor.amountMinor -= transfer;
      creditor.amountMinor -= transfer;

      if (debtor.amountMinor == 0) i++;
      if (creditor.amountMinor == 0) j++;
    }

    return result;
  }
}
