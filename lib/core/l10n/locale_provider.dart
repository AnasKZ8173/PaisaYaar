import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/secure_storage_service.dart';

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier(this._storage) : super(const Locale('en')) {
    _load();
  }

  final SecureStorageService _storage;

  Future<void> _load() async {
    final code = await _storage.readLanguageCode();
    if (code == 'ur') {
      state = const Locale('ur');
    } else {
      state = const Locale('en');
    }
  }

  Future<void> setLocale(String languageCode) async {
    final normalized = languageCode == 'ur' ? 'ur' : 'en';
    state = Locale(normalized);
    await _storage.writeLanguageCode(normalized);
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier(ref.read(secureStorageServiceProvider));
});
