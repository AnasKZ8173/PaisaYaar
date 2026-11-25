class ExpensePayerModel {
  const ExpensePayerModel({
    required this.userId,
    required this.paidAmountMinor,
  });

  final String userId;
  final int paidAmountMinor;

  factory ExpensePayerModel.fromJson(Map<String, dynamic> json) {
    return ExpensePayerModel(
      userId: json['user_id'] as String,
      paidAmountMinor: (json['paid_amount_minor'] as num).toInt(),
    );
  }

  Map<String, dynamic> toRpcJson() => {
        'user_id': userId,
        'paid_amount_minor': paidAmountMinor,
      };
}

class ExpenseParticipantModel {
  const ExpenseParticipantModel({
    required this.userId,
    required this.shareAmountMinor,
  });

  final String userId;
  final int shareAmountMinor;

  factory ExpenseParticipantModel.fromJson(Map<String, dynamic> json) {
    return ExpenseParticipantModel(
      userId: json['user_id'] as String,
      shareAmountMinor: (json['share_amount_minor'] as num).toInt(),
    );
  }

  Map<String, dynamic> toRpcJson() => {
        'user_id': userId,
        'share_amount_minor': shareAmountMinor,
      };
}

class GroupExpenseModel {
  const GroupExpenseModel({
    required this.id,
    required this.groupId,
    required this.createdBy,
    required this.title,
    required this.description,
    required this.totalAmountMinor,
    required this.currency,
    required this.category,
    required this.expenseDate,
    required this.splitMethod,
    required this.paymentMethod,
    required this.approvalStatus,
    this.receiptUrl,
    required this.payers,
    required this.participants,
  });

  final String id;
  final String groupId;
  final String createdBy;
  final String title;
  final String description;
  final int totalAmountMinor;
  final String currency;
  final String category;
  final DateTime expenseDate;
  final String splitMethod;
  final String paymentMethod;
  final String approvalStatus; // pending | approved | rejected
  final String? receiptUrl;
  final List<ExpensePayerModel> payers;
  final List<ExpenseParticipantModel> participants;

  bool get isApproved => approvalStatus == 'approved';
  bool get isPending => approvalStatus == 'pending';
  bool get isRejected => approvalStatus == 'rejected';

  factory GroupExpenseModel.fromJson(Map<String, dynamic> json) {
    final payersRaw = (json['expense_payers'] as List?) ?? const [];
    final partsRaw = (json['expense_participants'] as List?) ?? const [];

    return GroupExpenseModel(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      createdBy: json['created_by'] as String,
      title: json['title'] as String,
      description: (json['description'] as String?) ?? '',
      totalAmountMinor: (json['total_amount_minor'] as num).toInt(),
      currency: (json['currency'] as String?) ?? 'PKR',
      category: (json['category'] as String?) ?? 'Other',
      expenseDate: DateTime.parse(json['expense_date'] as String),
      splitMethod: (json['split_method'] as String?) ?? 'equal',
      paymentMethod: (json['payment_method'] as String?) ?? 'cash',
      approvalStatus: (json['approval_status'] as String?) ?? 'approved',
      receiptUrl: json['receipt_url'] as String?,
      payers: payersRaw
          .cast<Map<String, dynamic>>()
          .map(ExpensePayerModel.fromJson)
          .toList(),
      participants: partsRaw
          .cast<Map<String, dynamic>>()
          .map(ExpenseParticipantModel.fromJson)
          .toList(),
    );
  }
}
