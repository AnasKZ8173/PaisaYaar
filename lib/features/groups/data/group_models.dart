class GroupModel {
  const GroupModel({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.ownerId,
    required this.currency,
    required this.iconKey,
    this.imageUrl,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String description;
  final String category;
  final String ownerId;
  final String currency;
  final String iconKey;
  final String? imageUrl;
  final DateTime createdAt;

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: (json['description'] as String?) ?? '',
      category: (json['category'] as String?) ?? 'General',
      ownerId: json['owner_id'] as String,
      currency: (json['currency'] as String?) ?? 'PKR',
      iconKey: (json['icon_key'] as String?) ?? 'users',
      imageUrl: json['image_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class GroupSettingsModel {
  const GroupSettingsModel({
    required this.groupId,
    required this.requireExpenseApproval,
    required this.autoConfirmSettlements,
    required this.allowAllMembersChat,
    required this.whoCanAddExpense,
    required this.whoCanApproveExpense,
    required this.whoCanInvite,
    required this.whoCanRemoveMember,
    required this.whoCanEditGroup,
  });

  final String groupId;
  final bool requireExpenseApproval;
  final bool autoConfirmSettlements;
  final bool allowAllMembersChat;
  final String whoCanAddExpense;
  final String whoCanApproveExpense;
  final String whoCanInvite;
  final String whoCanRemoveMember;
  final String whoCanEditGroup;

  factory GroupSettingsModel.fromJson(Map<String, dynamic> json) {
    return GroupSettingsModel(
      groupId: json['group_id'] as String,
      requireExpenseApproval:
          (json['require_expense_approval'] as bool?) ?? false,
      autoConfirmSettlements:
          (json['auto_confirm_settlements'] as bool?) ?? false,
      allowAllMembersChat: (json['allow_all_members_chat'] as bool?) ?? true,
      whoCanAddExpense: (json['who_can_add_expense'] as String?) ?? 'all',
      whoCanApproveExpense:
          (json['who_can_approve_expense'] as String?) ?? 'admins',
      whoCanInvite: (json['who_can_invite'] as String?) ?? 'admins',
      whoCanRemoveMember:
          (json['who_can_remove_member'] as String?) ?? 'admins',
      whoCanEditGroup: (json['who_can_edit_group'] as String?) ?? 'admins',
    );
  }

  Map<String, dynamic> toUpdateJson() => {
        'require_expense_approval': requireExpenseApproval,
        'auto_confirm_settlements': autoConfirmSettlements,
        'allow_all_members_chat': allowAllMembersChat,
        'who_can_add_expense': whoCanAddExpense,
        'who_can_approve_expense': whoCanApproveExpense,
        'who_can_invite': whoCanInvite,
        'who_can_remove_member': whoCanRemoveMember,
        'who_can_edit_group': whoCanEditGroup,
      };

  GroupSettingsModel copyWith({
    bool? requireExpenseApproval,
    bool? autoConfirmSettlements,
    bool? allowAllMembersChat,
    String? whoCanAddExpense,
    String? whoCanApproveExpense,
    String? whoCanInvite,
    String? whoCanRemoveMember,
    String? whoCanEditGroup,
  }) {
    return GroupSettingsModel(
      groupId: groupId,
      requireExpenseApproval:
          requireExpenseApproval ?? this.requireExpenseApproval,
      autoConfirmSettlements:
          autoConfirmSettlements ?? this.autoConfirmSettlements,
      allowAllMembersChat: allowAllMembersChat ?? this.allowAllMembersChat,
      whoCanAddExpense: whoCanAddExpense ?? this.whoCanAddExpense,
      whoCanApproveExpense: whoCanApproveExpense ?? this.whoCanApproveExpense,
      whoCanInvite: whoCanInvite ?? this.whoCanInvite,
      whoCanRemoveMember: whoCanRemoveMember ?? this.whoCanRemoveMember,
      whoCanEditGroup: whoCanEditGroup ?? this.whoCanEditGroup,
    );
  }
}

class GroupMemberModel {
  const GroupMemberModel({
    required this.memberId,
    required this.userId,
    required this.publicId,
    required this.fullName,
    this.avatarUrl,
    required this.role,
    required this.status,
  });

  final String memberId;
  final String userId;
  final String publicId;
  final String fullName;
  final String? avatarUrl;
  final String role; // owner | sub_admin | member
  final String status;

  bool get isOwner => role == 'owner';
  bool get isAdmin => role == 'owner' || role == 'sub_admin';

  factory GroupMemberModel.fromJson(Map<String, dynamic> json) {
    return GroupMemberModel(
      memberId: json['member_id'] as String,
      userId: json['user_id'] as String,
      publicId: json['public_id'] as String,
      fullName: json['full_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      role: json['role'] as String,
      status: json['status'] as String,
    );
  }
}

class GroupInviteModel {
  const GroupInviteModel({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.groupCategory,
    required this.inviterId,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String groupId;
  final String groupName;
  final String groupCategory;
  final String inviterId;
  final String status;
  final DateTime createdAt;

  factory GroupInviteModel.fromJson(Map<String, dynamic> json) {
    final group = json['groups'] as Map<String, dynamic>?;
    return GroupInviteModel(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      groupName: (group?['name'] as String?) ?? 'Group',
      groupCategory: (group?['category'] as String?) ?? 'General',
      inviterId: json['inviter_id'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class GroupActivityModel {
  const GroupActivityModel({
    required this.id,
    required this.groupId,
    required this.actorId,
    required this.actionType,
    required this.metadata,
    required this.createdAt,
  });

  final String id;
  final String groupId;
  final String actorId;
  final String actionType;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  factory GroupActivityModel.fromJson(Map<String, dynamic> json) {
    return GroupActivityModel(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      actorId: json['actor_id'] as String,
      actionType: json['action_type'] as String,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? const {},
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
