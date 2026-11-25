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
