class GroupExpenseLedgerEntry {
  const GroupExpenseLedgerEntry({
    required this.payersMinor,
    required this.sharesMinor,
  });

  final Map<String, int> payersMinor;
  final Map<String, int> sharesMinor;
}

class ConfirmedSettlementEntry {
  const ConfirmedSettlementEntry({
    required this.senderId,
    required this.receiverId,
    required this.amountMinor,
  });

  final String senderId;
  final String receiverId;
  final int amountMinor;
}

class MemberBalanceSummary {
  const MemberBalanceSummary({
    required this.userId,
    required this.totalPaidMinor,
    required this.totalShareMinor,
    required this.netBalanceMinor,
  });

  final String userId;
  final int totalPaidMinor;
  final int totalShareMinor;

  /// Positive = member should receive money; Negative = member owes money.
  final int netBalanceMinor;

  int get owedMinor => netBalanceMinor < 0 ? -netBalanceMinor : 0;
  int get receivableMinor => netBalanceMinor > 0 ? netBalanceMinor : 0;
}

/// Pure Dart service for netting all approved group expenses & confirmed settlements.
class GroupBalanceService {
  const GroupBalanceService._();

  static Map<String, MemberBalanceSummary> calculateBalances({
    required Iterable<String> memberIds,
    required List<GroupExpenseLedgerEntry> approvedExpenses,
    required List<ConfirmedSettlementEntry> confirmedSettlements,
  }) {
    final paid = <String, int>{};
    final share = <String, int>{};
    final net = <String, int>{};

    void ensure(String id) {
      paid.putIfAbsent(id, () => 0);
      share.putIfAbsent(id, () => 0);
      net.putIfAbsent(id, () => 0);
    }

    for (final id in memberIds) {
      ensure(id);
    }

    for (final exp in approvedExpenses) {
      for (final entry in exp.payersMinor.entries) {
        ensure(entry.key);
        paid[entry.key] = paid[entry.key]! + entry.value;
        net[entry.key] = net[entry.key]! + entry.value;
      }
      for (final entry in exp.sharesMinor.entries) {
        ensure(entry.key);
        share[entry.key] = share[entry.key]! + entry.value;
        net[entry.key] = net[entry.key]! - entry.value;
      }
    }

    for (final st in confirmedSettlements) {
      ensure(st.senderId);
      ensure(st.receiverId);
      // Sender paid off debt -> net increases toward 0 (or positive)
      net[st.senderId] = net[st.senderId]! + st.amountMinor;
      // Receiver collected owed money -> net decreases toward 0
      net[st.receiverId] = net[st.receiverId]! - st.amountMinor;
    }

    return {
      for (final id in net.keys)
        id: MemberBalanceSummary(
          userId: id,
          totalPaidMinor: paid[id]!,
          totalShareMinor: share[id]!,
          netBalanceMinor: net[id]!,
        ),
    };
  }
}
