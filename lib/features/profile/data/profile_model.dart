/// Full private profile for the currently authenticated user.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.publicId,
    required this.fullName,
    required this.email,
    this.phone,
    this.avatarUrl,
    this.defaultCurrency = 'PKR',
    this.preferredLanguage = 'en',
    this.themeMode = 'light',
    this.profileCompleted = false,
  });

  final String id;
  final String publicId;
  final String fullName;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final String defaultCurrency;
  final String preferredLanguage;
  final String themeMode;
  final bool profileCompleted;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      publicId: (json['public_id'] as String?) ?? '',
      fullName: (json['full_name'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      defaultCurrency: (json['default_currency'] as String?) ?? 'PKR',
      preferredLanguage: (json['preferred_language'] as String?) ?? 'en',
      themeMode: (json['theme_mode'] as String?) ?? 'light',
      profileCompleted: (json['profile_completed'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toUpsertJson() {
    return {
      'id': id,
      'public_id': publicId.trim().toLowerCase(),
      'full_name': fullName.trim(),
      'email': email.trim(),
      'phone': phone?.trim().isEmpty == true ? null : phone?.trim(),
      'avatar_url': avatarUrl,
      'default_currency': defaultCurrency,
      'preferred_language': preferredLanguage,
      'theme_mode': themeMode,
      'profile_completed': profileCompleted,
    };
  }

  UserProfile copyWith({
    String? publicId,
    String? fullName,
    String? email,
    String? phone,
    String? avatarUrl,
    String? defaultCurrency,
    String? preferredLanguage,
    String? themeMode,
    bool? profileCompleted,
  }) {
    return UserProfile(
      id: id,
      publicId: publicId ?? this.publicId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      themeMode: themeMode ?? this.themeMode,
      profileCompleted: profileCompleted ?? this.profileCompleted,
    );
  }
}

/// Safe public profile returned by `search_public_profiles` RPC.
/// Never contains private email or phone fields.
class PublicProfileSearchResult {
  const PublicProfileSearchResult({
    required this.id,
    required this.publicId,
    required this.fullName,
    this.avatarUrl,
  });

  final String id;
  final String publicId;
  final String fullName;
  final String? avatarUrl;

  factory PublicProfileSearchResult.fromJson(Map<String, dynamic> json) {
    return PublicProfileSearchResult(
      id: json['id'] as String,
      publicId: json['public_id'] as String,
      fullName: json['full_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}
