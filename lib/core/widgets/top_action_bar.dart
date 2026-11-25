import 'package:material_ui/material_ui.dart';
import '../constants/app_icons.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';

class TopActionBar extends StatelessWidget {
  const TopActionBar({
    super.key,
    required this.title,
    this.showBrandLogo = false,
    this.onSearchTap,
    this.onNotificationsTap,
    this.hasUnreadNotifications = false,
  });

  final String title;
  final bool showBrandLogo;
  final VoidCallback? onSearchTap;
  final VoidCallback? onNotificationsTap;
  final bool hasUnreadNotifications;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (showBrandLogo) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/images/logo.jpg',
                    width: 28,
                    height: 28,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'PocketYaar',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ] else
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              if (showBrandLogo) const Spacer(),
              if (onSearchTap != null)
                _CircleIconButton(
                  icon: AppIcons.search,
                  surface: surface,
                  border: border,
                  onTap: onSearchTap!,
                ),
              if (onNotificationsTap != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Stack(
                  children: [
                    _CircleIconButton(
                      icon: AppIcons.bell,
                      surface: surface,
                      border: border,
                      onTap: onNotificationsTap!,
                    ),
                    if (hasUnreadNotifications)
                      PositionedDirectional(
                        end: 8,
                        top: 8,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.negativeRed,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
          if (showBrandLogo) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.surface,
    required this.border,
    required this.onTap,
  });

  final IconData icon;
  final Color surface;
  final Color border;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: surface,
      shape: CircleBorder(side: BorderSide(color: border)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 18),
        ),
      ),
    );
  }
}
