/// Supported currencies with PKR as the default.
class CurrencyInfo {
  const CurrencyInfo({
    required this.code,
    required this.symbol,
    required this.nameEn,
    required this.nameUr,
    this.minorUnitFactor = 100,
  });

  final String code;
  final String symbol;
  final String nameEn;
  final String nameUr;
  final int minorUnitFactor;
}

class SupportedCurrencies {
  SupportedCurrencies._();

  static const String defaultCurrency = 'PKR';

  static const List<CurrencyInfo> all = [
    CurrencyInfo(
      code: 'PKR',
      symbol: 'Rs.',
      nameEn: 'Pakistani Rupee (PKR)',
      nameUr: 'پاکستانی روپیہ (PKR)',
    ),
    CurrencyInfo(
      code: 'USD',
      symbol: '\$',
      nameEn: 'US Dollar (USD)',
      nameUr: 'امریکی ڈالر (USD)',
    ),
    CurrencyInfo(
      code: 'EUR',
      symbol: '€',
      nameEn: 'Euro (EUR)',
      nameUr: 'یورو (EUR)',
    ),
    CurrencyInfo(
      code: 'GBP',
      symbol: '£',
      nameEn: 'British Pound (GBP)',
      nameUr: 'برطانوی پاؤنڈ (GBP)',
    ),
    CurrencyInfo(
      code: 'AED',
      symbol: 'AED',
      nameEn: 'UAE Dirham (AED)',
      nameUr: 'اماراتی درہم (AED)',
    ),
    CurrencyInfo(
      code: 'SAR',
      symbol: 'SAR',
      nameEn: 'Saudi Riyal (SAR)',
      nameUr: 'سعودی ریال (SAR)',
    ),
  ];

  static CurrencyInfo byCode(String code) {
    return all.firstWhere(
      (c) => c.code.toUpperCase() == code.toUpperCase(),
      orElse: () => all.first,
    );
  }
}
