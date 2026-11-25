import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/settlement_models.dart';
import '../data/settlement_repository.dart';

final groupSettlementsProvider =
    FutureProvider.family<List<GroupSettlementModel>, String>(
        (ref, groupId) async {
  return ref.read(settlementRepositoryProvider).fetchSettlements(groupId);
});
