import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';
import 'settlement_models.dart';

class SettlementRepository {
  SettlementRepository(this._client);

  final SupabaseClient? _client;

  SupabaseClient get _requireClient {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    return client;
  }

  Future<List<GroupSettlementModel>> fetchSettlements(String groupId) async {
    final client = _requireClient;
    final rows = await client
        .from('group_settlements')
        .select()
        .eq('group_id', groupId)
        .order('created_at', ascending: false);

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(GroupSettlementModel.fromJson)
        .toList();
  }

  Future<String> submitSettlement({
    required String groupId,
    required String receiverId,
    required int amountMinor,
    String paymentMethod = 'cash',
    String reference = '',
    String? proofUrl,
  }) async {
    final client = _requireClient;
    final id = await client.rpc('submit_group_settlement', params: {
      'p_group_id': groupId,
      'p_receiver_id': receiverId,
      'p_amount_minor': amountMinor,
      'p_payment_method': paymentMethod,
      'p_reference': reference.trim(),
      'p_proof_url': proofUrl,
    });
    return id as String;
  }

  Future<void> decideSettlement({
    required String settlementId,
    required String decision, // confirmed | rejected | cancelled
    String note = '',
  }) async {
    final client = _requireClient;
    await client.rpc('decide_group_settlement', params: {
      'p_settlement_id': settlementId,
      'p_decision': decision,
      'p_note': note,
    });
  }
}

final settlementRepositoryProvider = Provider<SettlementRepository>((ref) {
  return SettlementRepository(ref.watch(supabaseClientProvider));
});
