import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketyaar/app.dart';
import 'package:pocketyaar/core/l10n/app_localizations.dart';
import 'package:pocketyaar/core/services/connectivity_provider.dart';
import 'package:pocketyaar/core/services/currency_formatter.dart';
import 'package:pocketyaar/core/utils/validators.dart';

void main() {
  group('AppValidators', () {
    test('validates email format', () {
      expect(AppValidators.email('anas@example.com'), isNull);
      expect(AppValidators.email('invalid-email'), isNotNull);
      expect(AppValidators.email(''), isNotNull);
    });

    test('validates 6-digit OTP', () {
      expect(AppValidators.otpCode('123456'), isNull);
      expect(AppValidators.otpCode('12345'), isNotNull);
      expect(AppValidators.otpCode('abcdef'), isNotNull);
    });

    test('validates password strength', () {
      expect(AppValidators.password('Pass1234'), isNull);
      expect(AppValidators.password('short1'), isNotNull);
      expect(AppValidators.password('onlyletters'), isNotNull);
    });

    test('validates public user ID format', () {
      expect(AppValidators.publicId('anas_92'), isNull);
      expect(AppValidators.publicId('abc'), isNotNull);
      expect(AppValidators.publicId('Anas@123'), isNotNull);
    });
  });

  group('CurrencyFormatter', () {
    test('formats PKR integer minor units accurately', () {
      expect(CurrencyFormatter.formatMinor(1000000), 'Rs. 10,000');
      expect(CurrencyFormatter.formatMinor(-250000), '-Rs. 2,500');
      expect(
        CurrencyFormatter.formatMinor(15050, showSign: true),
        '+Rs. 150.50',
      );
    });
  });

  group('AppLocalizations', () {
    test('supports English and Urdu with parameter interpolation', () {
      const en = AppLocalizations(Locale('en'));
      const ur = AppLocalizations(Locale('ur'));

      expect(en.t('app_name'), 'PocketYaar');
      expect(ur.t('app_name'), 'پاکٹ یار');
      expect(
        en.t('verify_email_subtitle', {'email': 'a@b.com'}),
        'Enter the 6-digit code sent to a@b.com',
      );
    });
  });

  testWidgets('SplitlyApp renders Login screen and switches EN <-> UR', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          internetStatusProvider.overrideWith((ref) => Stream.value(true)),
        ],
        child: const SplitlyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);

    // Switch to Urdu
    await tester.tap(find.text('اردو'));
    await tester.pumpAndSettle();

    expect(find.text('خوش آمدید'), findsOneWidget);
    expect(find.text('سائن ان کریں'), findsOneWidget);
  });
}
