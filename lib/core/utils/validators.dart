/// Shared form & domain input validators.
class AppValidators {
  AppValidators._();

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _publicIdRegex = RegExp(r'^[a-z0-9_]{4,24}$');

  static String? email(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Email is required';
    if (!_emailRegex.hasMatch(trimmed)) return 'Enter a valid email address';
    return null;
  }

  static String? otpCode(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.length != 6 || int.tryParse(trimmed) == null) {
      return 'Enter the 6-digit code';
    }
    return null;
  }

  static String? password(String? value) {
    final text = value ?? '';
    if (text.length < 8) return 'Password must be at least 8 characters';
    if (!text.contains(RegExp(r'[A-Za-z]')) ||
        !text.contains(RegExp(r'[0-9]'))) {
      return 'Include at least one letter and one number';
    }
    return null;
  }

  static String? fullName(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.length < 2) return 'Enter your full name';
    return null;
  }

  static String? publicId(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    if (!_publicIdRegex.hasMatch(normalized)) {
      return '4-24 chars: lowercase letters, numbers, or _';
    }
    return null;
  }
}
