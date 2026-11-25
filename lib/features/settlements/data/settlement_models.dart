class GroupSettlementModel {
  const GroupSettlementModel({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.receiverId,
    required this.amountMinor,
    required this.currency,
    required this.paymentMethod,
    required this.settlementDate,
    required this.reference,
    this.proofUrl,
    required this.status,
  });

  final String id;
  final String groupId;
  final String senderId;
  final String receiverId;
  final int amountMinor;
  final String currency;
  final String paymentMethod;
  final DateTime settlementDate;
  final String reference;
  final String? proofUrl;
  final String status; // pending | confirmed | rejected | cancelled

  bool get isPending => status == 'pending';
  bool get isConfirmed => status == 'confirmed';

  factory GroupSettlementModel.fromJson(Map<String, dynamic> json) {
    return GroupSettlementModel(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      senderId: json['sender_id'] as String,
      receiverId: json['receiver_id'] as String,
      amountMinor: (json['amount_minor'] as num).toInt(),
      currency: (json['currency'] as String?) ?? 'PKR',
      paymentMethod: (json['payment_method'] as String?) ?? 'cash',
      settlementDate: DateTime.parse(json['settlement_date'] as String),
      reference: (json['reference'] as String?) ?? '',
      proofUrl: json['proof_url'] as String?,
      status: (json['status'] as String?) ?? 'pending',
    );
  }
}
