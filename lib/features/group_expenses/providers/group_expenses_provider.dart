import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/finance/group_balance_service.dart';
import '../../../core/services/finance/settlement_optimizer_service.dart';
import '../../groups/providers/groups_provider.dart';
import '../../settlements/providers/settlements_provider.dart';
import '../data/group_expense_models.dart';
import '../data/group_expense_repository.dart';

final groupExpensesProvider =
    FutureProvider.family<List<GroupExpenseModel>, String>((ref, groupId) async {
  return ref.read(groupExpenseRepositoryProvider).fetchExpenses(groupId);
});

/// Computes netted member balances from approved expenses & confirmed settlements.
final groupBalancesProvider =
    Provider.family<AsyncValue<Map<String, MemberBalanceSummary>>, String>(
        (ref, groupId) {
  final membersAsync = ref.watch(groupMembersProvider(groupId));
  final expensesAsync = ref.watch(groupExpensesProvider(groupId));
  final settlementsAsync = ref.watch(groupSettlementsProvider(groupId));

  if (membersAsync.isLoading ||
      expensesAsync.isLoading ||
      settlementsAsync.isLoading) {
    return const AsyncLoading();
  }
  if (membersAsync.hasError) {
    return AsyncError(membersAsync.error!, membersAsync.stackTrace!);
  }
  if (expensesAsync.hasError) {
    return AsyncError(expensesAsync.error!, expensesAsync.stackTrace!);
  }
  if (settlementsAsync.hasError) {
    return AsyncError(settlementsAsync.error!, settlementsAsync.stackTrace!);
  }

  final members = membersAsync.valueOrNull ?? const [];
  final expenses = expensesAsync.valueOrNull ?? const [];
  final settlements = settlementsAsync.valueOrNull ?? const [];

  final approvedEntries = expenses
      .where((e) => e.isApproved)
      .map(
        (e) => GroupExpenseLedgerEntry(
          payersMinor: {
            for (final p in e.payers) p.userId: p.paidAmountMinor,
          },
          sharesMinor: {
            for (final s in e.participants) s.userId: s.shareAmountMinor,
          },
        ),
      )
      .toList();

  final confirmedEntries = settlements
      .where((s) => s.isConfirmed)
      .map(
        (s) => ConfirmedSettlementEntry(
          senderId: s.senderId,
          receiverId: s.receiverId,
          amountMinor: s.amountMinor,
        ),
      )
      .toList();

  final balances = GroupBalanceService.calculateBalances(
    memberIds: members.map((m) => m.userId),
    approvedExpenses: approvedEntries,
    confirmedSettlements: confirmedEntries,
  );

  return AsyncData(balances);
});

/// Computes minimal settlement transactions for a group.
final groupSuggestedSettlementsProvider =
    Provider.family<List<SuggestedSettlement>, String>((ref, groupId) {
  final balances = ref.watch(groupBalancesProvider(groupId)).valueOrNull;
  if (balances == null) return const [];

  final netMap = {
    for (final entry in balances.entries) entry.key: entry.value.netBalanceMinor,
  };
  return SettlementOptimizerService.optimize(netMap);
});
