import 'package:intl/intl.dart';
import '../constants/currencies.dart';

/// Formats integer minor units (e.g., paisa) into clean currency strings.
class CurrencyFormatter {
  CurrencyFormatter._();

  static String formatMinor(
    int amountMinor, {
    String currencyCode = SupportedCurrencies.defaultCurrency,
    bool showSign = false,
  }) {
    final info = SupportedCurrencies.byCode(currencyCode);
    final isNegative = amountMinor < 0;
    final absMinor = amountMinor.abs();
    final major = absMinor / info.minorUnitFactor;

    final hasDecimals = absMinor % info.minorUnitFactor != 0;
    final numberFormat = NumberFormat.currency(
      symbol: '',
      decimalDigits: hasDecimals ? 2 : 0,
    );
    final formattedNumber = numberFormat.format(major).trim();

    final prefix = isNegative
        ? '-'
        : (showSign && amountMinor > 0 ? '+' : '');

    return '$prefix${info.symbol} $formattedNumber';
  }
}
