import 'package:material_ui/material_ui.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/app_card.dart';

class BetaExpiredScreen extends StatelessWidget {
  const BetaExpiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/images/logo.jpg',
                    width: 96,
                    height: 96,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'PocketYaar BETA',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.xl),
                AppCard(
                  backgroundColor: AppColors.negativeRedSoft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        AppIcons.lock,
                        color: AppColors.negativeRed,
                        size: 30,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'BETA Version Expired',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppColors.negativeRed,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
                        'This 1-month BETA testing build has expired. Please contact the developer for the latest version.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
