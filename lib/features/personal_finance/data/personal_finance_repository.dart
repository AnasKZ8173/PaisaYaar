import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';
import 'personal_finance_models.dart';

class PersonalFinanceRepository {
  PersonalFinanceRepository(this._client);

  final SupabaseClient? _client;

  SupabaseClient get _requireClient {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    return client;
  }

  Future<List<PersonalAccountModel>> fetchAccounts() async {
    final client = _requireClient;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return const [];

    final rows = await client
        .from('personal_accounts')
        .select()
        .eq('user_id', uid)
        .eq('is_archived', false)
        .order('created_at', ascending: true);

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(PersonalAccountModel.fromJson)
        .toList();
  }

  Future<void> createAccount({
    required String name,
    required String accountType,
    String currency = 'PKR',
    int initialBalanceMinor = 0,
  }) async {
    final client = _requireClient;
    final uid = client.auth.currentUser?.id;
    if (uid == null) throw StateError('Not signed in');

    await client.from('personal_accounts').insert({
      'user_id': uid,
      'name': name.trim(),
      'account_type': accountType,
      'currency': currency,
      'balance_minor': initialBalanceMinor,
    });
  }

  Future<void> updateAccount({
    required String accountId,
    required String name,
    required String accountType,
    required int balanceMinor,
  }) async {
    final client = _requireClient;
    final uid = client.auth.currentUser?.id;
    if (uid == null) throw StateError('Not signed in');

    await client
        .from('personal_accounts')
        .update({
          'name': name.trim(),
          'account_type': accountType,
          'balance_minor': balanceMinor,
        })
        .eq('id', accountId)
        .eq('user_id', uid);
  }

  Future<void> removeAccount(String accountId) async {
    final client = _requireClient;
    final uid = client.auth.currentUser?.id;
    if (uid == null) throw StateError('Not signed in');

    await client
        .from('personal_accounts')
        .update({'is_archived': true})
        .eq('id', accountId)
        .eq('user_id', uid);
  }

  Future<List<ExpenseCategoryModel>> fetchCategories() async {
    final client = _requireClient;
    final rows = await client
        .from('expense_categories')
        .select()
        .order('is_default', ascending: false)
        .order('name', ascending: true);

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(ExpenseCategoryModel.fromJson)
        .toList();
  }

  Future<void> createCustomCategory(String name) async {
    final client = _requireClient;
    final uid = client.auth.currentUser?.id;
    if (uid == null) throw StateError('Not signed in');

    await client.from('expense_categories').insert({
      'user_id': uid,
      'name': name.trim(),
      'icon_key': 'tag',
      'color_hex': '#558B2F',
      'is_default': false,
    });
  }

  Future<List<PersonalTransactionModel>> fetchTransactions() async {
    final client = _requireClient;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return const [];

    final rows = await client
        .from('personal_transactions')
        .select('*, expense_categories(name)')
        .eq('user_id', uid)
        .order('tx_date', ascending: false)
        .order('created_at', ascending: false)
        .limit(200);

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(PersonalTransactionModel.fromJson)
        .toList();
  }

  Future<String> recordTransaction({
    String? accountId,
    required String txType,
    required int amountMinor,
    required String title,
    String? categoryId,
    String? transferAccountId,
    String source = '',
    String paymentMethod = 'cash',
    String note = '',
    DateTime? txDate,
    String? linkedGroupExpenseId,
    String recipientName = '',
    String incomeKind = 'extra',
  }) async {
    final client = _requireClient;
    final id = await client.rpc('record_personal_transaction', params: {
      'p_account_id': accountId,
      'p_tx_type': txType,
      'p_amount_minor': amountMinor,
      'p_title': title.trim(),
      'p_category_id': categoryId,
      'p_transfer_account_id': transferAccountId,
      'p_source': source.trim(),
      'p_payment_method': paymentMethod,
      'p_note': note.trim(),
      'p_tx_date': (txDate ?? DateTime.now()).toIso8601String().split('T').first,
      'p_linked_group_expense_id': linkedGroupExpenseId,
      'p_recipient_name': recipientName.trim(),
      'p_income_kind': incomeKind,
    });
    return id as String;
  }

  Future<void> updateTransaction({
    required String txId,
    String? accountId,
    required String txType,
    required int amountMinor,
    required String title,
    String? categoryId,
    String source = '',
    String paymentMethod = 'cash',
    String note = '',
    String recipientName = '',
    String incomeKind = 'extra',
  }) async {
    final client = _requireClient;
    await client.rpc('update_personal_transaction', params: {
      'p_tx_id': txId,
      'p_account_id': accountId,
      'p_tx_type': txType,
      'p_amount_minor': amountMinor,
      'p_title': title.trim(),
      'p_category_id': categoryId,
      'p_source': source.trim(),
      'p_payment_method': paymentMethod,
      'p_note': note.trim(),
      'p_recipient_name': recipientName.trim(),
      'p_income_kind': incomeKind,
    });
  }

  Future<void> deleteTransaction(String txId) async {
    final client = _requireClient;
    await client.rpc('delete_personal_transaction', params: {
      'p_tx_id': txId,
    });
  }

  Future<List<BudgetModel>> fetchCurrentMonthBudgets() async {
    final client = _requireClient;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return const [];

    final now = DateTime.now();
    final monthStr =
        DateTime(now.year, now.month, 1).toIso8601String().split('T').first;

    final rows = await client
        .from('budgets')
        .select('*, expense_categories(name)')
        .eq('user_id', uid)
        .eq('month_date', monthStr);

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(BudgetModel.fromJson)
        .toList();
  }

  Future<void> upsertBudget({
    required String categoryId,
    required int limitMinor,
    String currency = 'PKR',
  }) async {
    final client = _requireClient;
    final uid = client.auth.currentUser?.id;
    if (uid == null) throw StateError('Not signed in');

    final now = DateTime.now();
    final monthStr =
        DateTime(now.year, now.month, 1).toIso8601String().split('T').first;

    await client.from('budgets').upsert(
      {
        'user_id': uid,
        'category_id': categoryId,
        'month_date': monthStr,
        'limit_minor': limitMinor,
        'currency': currency,
      },
      onConflict: 'user_id,category_id,month_date',
    );
  }

  Future<void> deleteBudget(String budgetId) async {
    final client = _requireClient;
    final uid = client.auth.currentUser?.id;
    if (uid == null) throw StateError('Not signed in');

    await client
        .from('budgets')
        .delete()
        .eq('id', budgetId)
        .eq('user_id', uid);
  }
}

final personalFinanceRepositoryProvider =
    Provider<PersonalFinanceRepository>((ref) {
  return PersonalFinanceRepository(ref.watch(supabaseClientProvider));
});
