class PersonalAccountModel {
  const PersonalAccountModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.accountType,
    required this.currency,
    required this.balanceMinor,
  });

  final String id;
  final String userId;
  final String name;
  final String accountType; // bank | cash | easypaisa | jazzcash | custom
  final String currency;
  final int balanceMinor;

  factory PersonalAccountModel.fromJson(Map<String, dynamic> json) {
    return PersonalAccountModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      accountType: json['account_type'] as String,
      currency: (json['currency'] as String?) ?? 'PKR',
      balanceMinor: (json['balance_minor'] as num).toInt(),
    );
  }
}

class ExpenseCategoryModel {
  const ExpenseCategoryModel({
    required this.id,
    this.userId,
    required this.name,
    required this.iconKey,
    required this.colorHex,
    required this.isDefault,
  });

  final String id;
  final String? userId;
  final String name;
  final String iconKey;
  final String colorHex;
  final bool isDefault;

  factory ExpenseCategoryModel.fromJson(Map<String, dynamic> json) {
    return ExpenseCategoryModel(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      name: json['name'] as String,
      iconKey: (json['icon_key'] as String?) ?? 'tag',
      colorHex: (json['color_hex'] as String?) ?? '#558B2F',
      isDefault: (json['is_default'] as bool?) ?? false,
    );
  }
}

class PersonalTransactionModel {
  const PersonalTransactionModel({
    required this.id,
    required this.userId,
    this.accountId,
    this.transferAccountId,
    this.categoryId,
    this.categoryName,
    required this.txType,
    required this.amountMinor,
    required this.title,
    required this.source,
    required this.paymentMethod,
    required this.note,
    required this.txDate,
    this.linkedGroupExpenseId,
    this.recipientName = '',
    this.incomeKind = 'extra',
  });

  final String id;
  final String userId;
  final String? accountId;
  final String? transferAccountId;
  final String? categoryId;
  final String? categoryName;
  final String txType;
  final int amountMinor;
  final String title;
  final String source;
  final String paymentMethod;
  final String note;
  final DateTime txDate;
  final String? linkedGroupExpenseId;
  final String recipientName;
  final String incomeKind;

  factory PersonalTransactionModel.fromJson(Map<String, dynamic> json) {
    final cat = json['expense_categories'] as Map<String, dynamic>?;
    return PersonalTransactionModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      accountId: json['account_id'] as String?,
      transferAccountId: json['transfer_account_id'] as String?,
      categoryId: json['category_id'] as String?,
      categoryName: cat?['name'] as String?,
      txType: json['tx_type'] as String,
      amountMinor: (json['amount_minor'] as num).toInt(),
      title: json['title'] as String,
      source: (json['source'] as String?) ?? '',
      paymentMethod: (json['payment_method'] as String?) ?? 'cash',
      note: (json['note'] as String?) ?? '',
      txDate: DateTime.parse(json['tx_date'] as String),
      linkedGroupExpenseId: json['linked_group_expense_id'] as String?,
      recipientName: (json['recipient_name'] as String?) ?? '',
      incomeKind: (json['income_kind'] as String?) ?? 'extra',
    );
  }
}

class BudgetModel {
  const BudgetModel({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.monthDate,
    required this.limitMinor,
    required this.currency,
  });

  final String id;
  final String categoryId;
  final String categoryName;
  final DateTime monthDate;
  final int limitMinor;
  final String currency;

  factory BudgetModel.fromJson(Map<String, dynamic> json) {
    final cat = json['expense_categories'] as Map<String, dynamic>?;
    return BudgetModel(
      id: json['id'] as String,
      categoryId: json['category_id'] as String,
      categoryName: (cat?['name'] as String?) ?? 'Category',
      monthDate: DateTime.parse(json['month_date'] as String),
      limitMinor: (json['limit_minor'] as num).toInt(),
      currency: (json['currency'] as String?) ?? 'PKR',
    );
  }
}
