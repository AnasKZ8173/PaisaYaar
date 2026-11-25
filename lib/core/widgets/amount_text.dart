import 'package:material_ui/material_ui.dart';
import '../constants/app_colors.dart';
import '../constants/currencies.dart';
import '../services/currency_formatter.dart';

class AmountText extends StatelessWidget {
  const AmountText({
    super.key,
    required this.amountMinor,
    this.currencyCode = SupportedCurrencies.defaultCurrency,
    this.style,
    this.showSign = false,
    this.colorBySign = false,
  });

  final int amountMinor;
  final String currencyCode;
  final TextStyle? style;
  final bool showSign;
  final bool colorBySign;

  @override
  Widget build(BuildContext context) {
    Color? color = style?.color;
    if (colorBySign) {
      if (amountMinor > 0) {
        color = AppColors.positiveGreen;
      } else if (amountMinor < 0) {
        color = AppColors.negativeRed;
      }
    }

    return Text(
      CurrencyFormatter.formatMinor(
        amountMinor,
        currencyCode: currencyCode,
        showSign: showSign,
      ),
      textDirection: TextDirection.ltr,
      style: (style ?? Theme.of(context).textTheme.titleMedium)?.copyWith(
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
