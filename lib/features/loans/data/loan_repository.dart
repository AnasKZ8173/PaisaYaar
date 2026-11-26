import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';
import 'loan_model.dart';

class LoanRepository {
  LoanRepository(this._client);

  final SupabaseClient? _client;

  SupabaseClient get _requireClient {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    return client;
  }

  Future<List<LoanModel>> fetchMyLoans() async {
    final client = _requireClient;
    final rows = await client.rpc('get_my_loans_with_profiles');
    if (rows is! List) return const [];
    return rows
        .cast<Map<String, dynamic>>()
        .map(LoanModel.fromJson)
        .toList();
  }

  Future<String> createLoanRequest({
    required String borrowerId,
    required int amountMinor,
    required String title,
    DateTime? dueDate,
    String note = '',
    String? lenderTxId,
  }) async {
    final client = _requireClient;
    final id = await client.rpc('create_loan_request', params: {
      'p_borrower_id': borrowerId,
      'p_amount_minor': amountMinor,
      'p_title': title.trim(),
      'p_due_date': dueDate?.toIso8601String().split('T').first,
      'p_note': note.trim(),
      'p_lender_tx_id': lenderTxId,
    });
    return id as String;
  }

  Future<void> respondToLoanRequest({
    required String loanId,
    required bool accept,
  }) async {
    final client = _requireClient;
    await client.rpc('respond_to_loan_request', params: {
      'p_loan_id': loanId,
      'p_accept': accept,
    });
  }

  Future<void> cancelLoanRequest(String loanId) async {
    final client = _requireClient;
    await client.rpc('cancel_loan_request', params: {
      'p_loan_id': loanId,
    });
  }

  Future<String> recordRepayment({
    required String loanId,
    required int amountMinor,
    String? accountId,
    String paymentMethod = 'account',
    String note = '',
    String? proofUrl,
  }) async {
    final client = _requireClient;
    final id = await client.rpc('record_loan_repayment', params: {
      'p_loan_id': loanId,
      'p_amount_minor': amountMinor,
      'p_account_id': accountId,
      'p_payment_method': paymentMethod,
      'p_note': note.trim(),
      'p_proof_url': proofUrl,
    });
    return id as String;
  }

  Future<List<PendingLoanRepaymentModel>> fetchPendingRepaymentsForLender() async {
    final client = _requireClient;
    final rows = await client.rpc('get_pending_loan_repayments_for_lender');
    if (rows is! List) return const [];
    return rows
        .cast<Map<String, dynamic>>()
        .map(PendingLoanRepaymentModel.fromJson)
        .toList();
  }

  Future<void> decideRepayment({
    required String repaymentId,
    required bool accept,
    String? lenderAccountId,
  }) async {
    final client = _requireClient;
    await client.rpc('decide_loan_repayment', params: {
      'p_repayment_id': repaymentId,
      'p_accept': accept,
      'p_lender_account_id': lenderAccountId,
    });
  }

  Future<void> checkDueReminders() async {
    final client = _client;
    if (client == null || client.auth.currentUser == null) return;
    await client.rpc('check_and_create_loan_due_reminders');
  }
}

final loanRepositoryProvider = Provider<LoanRepository>((ref) {
  return LoanRepository(ref.watch(supabaseClientProvider));
});
