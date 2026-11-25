/// Pure Dart service for accurate integer-minor-unit expense splitting.
class SplitCalculatorService {
  const SplitCalculatorService._();

  /// Splits [totalMinor] equally among [participantUserIds].
  ///
  /// Uses integer division and distributes the remainder (+1 minor unit each)
  /// deterministically in list order so the sum always equals [totalMinor].
  static Map<String, int> calculateEqualSplit({
    required int totalMinor,
    required List<String> participantUserIds,
  }) {
    if (totalMinor <= 0) {
      throw ArgumentError.value(totalMinor, 'totalMinor', 'Must be positive');
    }
    if (participantUserIds.isEmpty) {
      throw ArgumentError('At least one participant is required');
    }

    final uniqueIds = participantUserIds.toSet().toList();
    final count = uniqueIds.length;
    final base = totalMinor ~/ count;
    final remainder = totalMinor % count;

    final result = <String, int>{};
    for (var i = 0; i < count; i++) {
      result[uniqueIds[i]] = base + (i < remainder ? 1 : 0);
    }
    return result;
  }

  /// Validates that exact participant shares are non-negative and sum to [totalMinor].
  static String? validateExactSplit({
    required int totalMinor,
    required Map<String, int> exactSharesMinor,
  }) {
    if (totalMinor <= 0) return 'Total amount must be positive';
    if (exactSharesMinor.isEmpty) return 'Select at least one participant';

    var sum = 0;
    for (final entry in exactSharesMinor.entries) {
      if (entry.value < 0) return 'Participant shares cannot be negative';
      sum += entry.value;
    }
    if (sum != totalMinor) {
      return 'Participant shares must equal the expense total';
    }
    return null;
  }

  /// Validates that payer contributions are positive and sum to [totalMinor].
  static String? validatePayers({
    required int totalMinor,
    required Map<String, int> payerAmountsMinor,
  }) {
    if (totalMinor <= 0) return 'Total amount must be positive';
    if (payerAmountsMinor.isEmpty) return 'At least one payer is required';

    var sum = 0;
    for (final entry in payerAmountsMinor.entries) {
      if (entry.value <= 0) return 'Each payer contribution must be positive';
      sum += entry.value;
    }
    if (sum != totalMinor) {
      return 'Payer contributions must equal the expense total';
    }
    return null;
  }
}
