import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';
import 'group_expense_models.dart';

class GroupExpenseRepository {
  GroupExpenseRepository(this._client);

  final SupabaseClient? _client;

  SupabaseClient get _requireClient {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    return client;
  }

  Future<List<GroupExpenseModel>> fetchExpenses(String groupId) async {
    final client = _requireClient;
    final rows = await client
        .from('group_expenses')
        .select('*, expense_payers(*), expense_participants(*)')
        .eq('group_id', groupId)
        .eq('is_deleted', false)
        .order('expense_date', ascending: false)
        .order('created_at', ascending: false);

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(GroupExpenseModel.fromJson)
        .toList();
  }

  Future<String> createExpense({
    required String groupId,
    required String title,
    required String description,
    required int totalAmountMinor,
    required String category,
    required DateTime expenseDate,
    required String splitMethod,
    required String paymentMethod,
    required List<ExpensePayerModel> payers,
    required List<ExpenseParticipantModel> participants,
    String? receiptUrl,
  }) async {
    final client = _requireClient;
    final id = await client.rpc('create_group_expense', params: {
      'p_group_id': groupId,
      'p_title': title.trim(),
      'p_description': description.trim(),
      'p_total_amount_minor': totalAmountMinor,
      'p_category': category,
      'p_expense_date': expenseDate.toIso8601String().split('T').first,
      'p_split_method': splitMethod,
      'p_payment_method': paymentMethod,
      'p_payers': payers.map((e) => e.toRpcJson()).toList(),
      'p_participants': participants.map((e) => e.toRpcJson()).toList(),
      'p_receipt_url': receiptUrl,
    });
    return id as String;
  }

  Future<void> decideExpense({
    required String expenseId,
    required String decision, // approved | rejected
    String note = '',
  }) async {
    final client = _requireClient;
    await client.rpc('decide_group_expense', params: {
      'p_expense_id': expenseId,
      'p_decision': decision,
      'p_note': note,
    });
  }

  Future<void> updateExpense({
    required String expenseId,
    required String title,
    required String description,
    required int totalAmountMinor,
    required String category,
    required String splitMethod,
    required String paymentMethod,
    required List<ExpensePayerModel> payers,
    required List<ExpenseParticipantModel> participants,
  }) async {
    final client = _requireClient;
    await client.rpc('update_group_expense', params: {
      'p_expense_id': expenseId,
      'p_title': title.trim(),
      'p_description': description.trim(),
      'p_total_amount_minor': totalAmountMinor,
      'p_category': category,
      'p_split_method': splitMethod,
      'p_payment_method': paymentMethod,
      'p_payers': payers.map((e) => e.toRpcJson()).toList(),
      'p_participants': participants.map((e) => e.toRpcJson()).toList(),
    });
  }

  Future<void> deleteExpense(String expenseId) async {
    final client = _requireClient;
    await client.rpc('delete_group_expense', params: {
      'p_expense_id': expenseId,
    });
  }

  Future<List<Map<String, dynamic>>> fetchMyGroupExpenseShares() async {
    final client = _requireClient;
    final rows = await client.rpc('get_my_group_expense_shares');
    if (rows is! List) return const [];
    return rows.cast<Map<String, dynamic>>();
  }
}

final groupExpenseRepositoryProvider = Provider<GroupExpenseRepository>((ref) {
  return GroupExpenseRepository(ref.watch(supabaseClientProvider));
});
