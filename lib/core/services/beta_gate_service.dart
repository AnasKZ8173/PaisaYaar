import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/env.dart';

/// Tamper-resistant 1-month BETA expiration guard.
///
/// Combines server UTC time (via HTTPS Date header from Supabase),
/// monotonic high-water-mark storage, and a persistent lock flag so
/// rolling back the device clock cannot bypass expiration.
class BetaGateService {
  BetaGateService._();

  static const _storage = FlutterSecureStorage();
  static const _kHwmKey = 'py_b_hwm_v1';
  static const _kLockKey = 'py_b_lck_v1';

  // 1 month from 2026-11-25 -> 2026-12-25 23:59:59 UTC
  static DateTime get _expiryUtc =>
      DateTime.utc(2020 + 6, 6 + 6, 20 + 5, 23, 59, 59);

  static Future<DateTime?> _fetchServerUtcNow() async {
    if (kIsWeb || !Env.isConfigured) return null;
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 4);
      final req = await client.headUrl(Uri.parse('${Env.supabaseUrl}/rest/v1/'));
      req.headers.set('apikey', Env.supabaseAnonKey);
      final res = await req.close().timeout(const Duration(seconds: 4));
      await res.drain<void>();
      client.close(force: true);

      final dateHeader = res.headers.value(HttpHeaders.dateHeader);
      if (dateHeader == null) return null;
      return HttpDate.parse(dateHeader).toUtc();
    } catch (_) {
      return null;
    }
  }

  static Future<bool> isExpired({DateTime? nowOverride}) async {
    final expiry = _expiryUtc;
    final deviceNow = (nowOverride ?? DateTime.now()).toUtc();

    if (deviceNow.isAfter(expiry)) {
      await _persistLock();
      return true;
    }

    String? locked;
    String? hwmRaw;
    try {
      locked = await _storage.read(key: _kLockKey);
      hwmRaw = await _storage.read(key: _kHwmKey);
    } catch (_) {
      // Ignore storage errors in unsupported test runners.
    }

    if (locked == '1') return true;

    final hwmMs = int.tryParse(hwmRaw ?? '');
    final hwm = hwmMs != null
        ? DateTime.fromMillisecondsSinceEpoch(hwmMs, isUtc: true)
        : null;

    if (hwm != null && hwm.isAfter(expiry)) {
      await _persistLock();
      return true;
    }

    final serverNow = await _fetchServerUtcNow();
    final effectiveNow = serverNow ?? deviceNow;

    if (effectiveNow.isAfter(expiry)) {
      await _persistLock();
      return true;
    }

    // Detect clock rollback (> 6 hours behind last verified high-water mark)
    if (serverNow == null &&
        hwm != null &&
        deviceNow.isBefore(hwm.subtract(const Duration(hours: 6)))) {
      return true;
    }

    if (hwm == null || effectiveNow.isAfter(hwm)) {
      try {
        await _storage.write(
          key: _kHwmKey,
          value: effectiveNow.millisecondsSinceEpoch.toString(),
        );
      } catch (_) {}
    }

    return false;
  }

  static Future<void> _persistLock() async {
    try {
      await _storage.write(key: _kLockKey, value: '1');
    } catch (_) {}
  }
}

final betaExpiredProvider = FutureProvider<bool>((ref) async {
  return BetaGateService.isExpired();
});
