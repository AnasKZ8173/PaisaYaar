class LoanModel {
  const LoanModel({
    required this.id,
    required this.lenderId,
    required this.lenderName,
    required this.lenderPublicId,
    required this.borrowerId,
    required this.borrowerName,
    required this.borrowerPublicId,
    required this.amountMinor,
    required this.remainingMinor,
    required this.currency,
    required this.title,
    required this.note,
    this.dueDate,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String lenderId;
  final String lenderName;
  final String lenderPublicId;
  final String borrowerId;
  final String borrowerName;
  final String borrowerPublicId;
  final int amountMinor;
  final int remainingMinor;
  final String currency;
  final String title;
  final String note;
  final DateTime? dueDate;
  final String status; // pending | active | paid | rejected | cancelled
  final DateTime createdAt;

  bool get isPending => status == 'pending';
  bool get isActive => status == 'active';
  bool get isPaid => status == 'paid';

  factory LoanModel.fromJson(Map<String, dynamic> json) {
    return LoanModel(
      id: json['id'] as String,
      lenderId: json['lender_id'] as String,
      lenderName: (json['lender_name'] as String?) ?? 'User',
      lenderPublicId: (json['lender_public_id'] as String?) ?? '',
      borrowerId: json['borrower_id'] as String,
      borrowerName: (json['borrower_name'] as String?) ?? 'User',
      borrowerPublicId: (json['borrower_public_id'] as String?) ?? '',
      amountMinor: (json['amount_minor'] as num).toInt(),
      remainingMinor: (json['remaining_minor'] as num).toInt(),
      currency: (json['currency'] as String?) ?? 'PKR',
      title: (json['title'] as String?) ?? 'Loan',
      note: (json['note'] as String?) ?? '',
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'] as String)
          : null,
      status: (json['status'] as String?) ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class PendingLoanRepaymentModel {
  const PendingLoanRepaymentModel({
    required this.repaymentId,
    required this.loanId,
    required this.loanTitle,
    required this.payerId,
    required this.payerName,
    required this.amountMinor,
    required this.currency,
    required this.paymentMethod,
    this.proofUrl,
    required this.note,
    required this.paidAt,
  });

  final String repaymentId;
  final String loanId;
  final String loanTitle;
  final String payerId;
  final String payerName;
  final int amountMinor;
  final String currency;
  final String paymentMethod;
  final String? proofUrl;
  final String note;
  final DateTime paidAt;

  factory PendingLoanRepaymentModel.fromJson(Map<String, dynamic> json) {
    return PendingLoanRepaymentModel(
      repaymentId: json['repayment_id'] as String,
      loanId: json['loan_id'] as String,
      loanTitle: (json['loan_title'] as String?) ?? 'Loan',
      payerId: json['payer_id'] as String,
      payerName: (json['payer_name'] as String?) ?? 'Borrower',
      amountMinor: (json['amount_minor'] as num).toInt(),
      currency: (json['currency'] as String?) ?? 'PKR',
      paymentMethod: (json['payment_method'] as String?) ?? 'cash',
      proofUrl: json['proof_url'] as String?,
      note: (json['note'] as String?) ?? '',
      paidAt: DateTime.parse(json['paid_at'] as String),
    );
  }
}
