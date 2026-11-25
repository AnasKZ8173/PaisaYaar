import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/services/connectivity_provider.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final internetAsync = ref.watch(internetStatusProvider);

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
                    width: 108,
                    height: 108,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'PocketYaar',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Personal Finance & Group Expenses',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xxl),
                internetAsync.when(
                  loading: () => const CircularProgressIndicator(
                    color: AppColors.accentGreen,
                  ),
                  error: (_, _) => _OfflineCard(
                    onRetry: () => ref.invalidate(internetStatusProvider),
                  ),
                  data: (isOnline) => isOnline
                      ? const CircularProgressIndicator(
                          color: AppColors.accentGreen,
                        )
                      : _OfflineCard(
                          onRetry: () => ref.invalidate(internetStatusProvider),
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

class _OfflineCard extends StatelessWidget {
  const _OfflineCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      backgroundColor: AppColors.negativeRedSoft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            AppIcons.alertTriangle,
            color: AppColors.negativeRed,
            size: 28,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No Internet Connection',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.negativeRed,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Please turn on Wi-Fi or mobile data to load your PocketYaar account.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Retry Connection',
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
