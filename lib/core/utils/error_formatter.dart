import 'dart:async';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Converts raw network/Supabase exceptions into clean, user-friendly messages.
class ErrorFormatter {
  ErrorFormatter._();

  static bool isNetworkError(Object error) {
    final text = error.toString().toLowerCase();
    return error is SocketException ||
        error is TimeoutException ||
        text.contains('clientexception') ||
        text.contains('socketexception') ||
        text.contains('failed host lookup') ||
        text.contains('network is unreachable') ||
        text.contains('connection refused') ||
        text.contains('timed out');
  }

  static String friendly(Object error) {
    if (isNetworkError(error)) {
      return 'No internet connection or server timed out. Please check your Wi-Fi or mobile data and try again.';
    }
    if (error is AuthException) {
      final msg = error.message.toLowerCase();
      if (msg.contains('invalid login credentials')) {
        return 'Incorrect email or password. Please try again.';
      }
      if (msg.contains('user already registered')) {
        return 'An account with this email already exists. Please sign in.';
      }
      if (msg.contains('rate limit')) {
        return 'Too many attempts. Please wait a moment and try again.';
      }
      return error.message;
    }
    if (error is PostgrestException) {
      return error.message;
    }
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    if (raw.length > 140) {
      return 'Something went wrong. Please try again.';
    }
    return raw;
  }
}
