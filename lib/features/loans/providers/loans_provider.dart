import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/loan_model.dart';
import '../data/loan_repository.dart';

bool _checkedDueRemindersThisSession = false;

final myLoansProvider = FutureProvider<List<LoanModel>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  final repo = ref.read(loanRepositoryProvider);
  if (!_checkedDueRemindersThisSession) {
    _checkedDueRemindersThisSession = true;
    unawaited(repo.checkDueReminders().catchError((_) {}));
  }
  return repo.fetchMyLoans();
});

final activeBorrowedLoansProvider = Provider<List<LoanModel>>((ref) {
  final uid = ref.watch(currentUserProvider)?.id;
  if (uid == null) return const [];
  final loans = ref.watch(myLoansProvider).valueOrNull ?? const [];
  return loans
      .where((l) => l.borrowerId == uid && l.isActive && l.remainingMinor > 0)
      .toList();
});

final pendingLoanRepaymentsProvider =
    FutureProvider<List<PendingLoanRepaymentModel>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return ref.read(loanRepositoryProvider).fetchPendingRepaymentsForLender();
});
