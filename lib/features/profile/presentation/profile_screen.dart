import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/currencies.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/top_action_bar.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/data/auth_repository.dart';
import '../data/profile_model.dart';
import '../providers/profile_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openEditProfileSheet(UserProfile profile) async {
    final nameCtrl = TextEditingController(text: profile.fullName);
    final phoneCtrl = TextEditingController(text: profile.phone ?? '');
    var avatarUrl = profile.avatarUrl;
    var saving = false;
    var uploading = false;

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.xl,
            AppSpacing.xl,
            MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Edit Profile',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: GestureDetector(
                  onTap: uploading
                      ? null
                      : () async {
                          final file = await ImagePicker().pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 512,
                            imageQuality: 80,
                          );
                          if (file == null) return;
                          setModalState(() => uploading = true);
                          try {
                            final bytes = await file.readAsBytes();
                            final ext = file.name.split('.').last;
                            final url = await ref
                                .read(currentProfileProvider.notifier)
                                .uploadAvatar(bytes: bytes, fileExtension: ext);
                            if (url != null) {
                              setModalState(() => avatarUrl = url);
                            }
                          } finally {
                            if (ctx.mounted) {
                              setModalState(() => uploading = false);
                            }
                          }
                        },
                  child: Stack(
                    children: [
                      UserAvatar(
                        name: nameCtrl.text.isEmpty ? 'U' : nameCtrl.text,
                        imageUrl: avatarUrl,
                        radius: 40,
                      ),
                      PositionedDirectional(
                        end: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: AppColors.accentGreen,
                            shape: BoxShape.circle,
                          ),
                          child: uploading
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  AppIcons.camera,
                                  size: 14,
                                  color: Colors.white,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: nameCtrl,
                label: 'Full name',
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: phoneCtrl,
                label: 'Phone number (optional)',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Save Changes',
                isLoading: saving,
                onPressed: () async {
                  if (nameCtrl.text.trim().length < 2) return;
                  setModalState(() => saving = true);
                  try {
                    await ref
                        .read(currentProfileProvider.notifier)
                        .saveProfile(
                          profile.copyWith(
                            fullName: nameCtrl.text.trim(),
                            phone: phoneCtrl.text.trim(),
                            avatarUrl: avatarUrl,
                          ),
                        );
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  } finally {
                    if (ctx.mounted) setModalState(() => saving = false);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final currentLocale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);
    final searchResults = ref.watch(publicUserSearchProvider(_searchQuery));

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(currentProfileProvider);
        },
        child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: TopActionBar(
              title: l10n.t('profile_title'),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              110,
            ),
            sliver: SliverList.list(
              children: [
                // Profile Header Card
                AppCard(
                  child: Row(
                    children: [
                      UserAvatar(
                        name: profile?.fullName ?? 'Splitly User',
                        imageUrl: profile?.avatarUrl,
                        radius: 28,
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile?.fullName ?? 'User',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '@${profile?.publicId ?? ''}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: AppColors.accentGreen,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            if (profile?.email.isNotEmpty == true) ...[
                              const SizedBox(height: 2),
                              Text(
                                profile!.email,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Edit Profile',
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: profile == null
                            ? null
                            : () => _openEditProfileSheet(profile),
                      ),
                      IconButton(
                        tooltip: l10n.t('copy_id'),
                        icon: const Icon(AppIcons.copy, size: 18),
                        onPressed: profile == null
                            ? null
                            : () {
                                Clipboard.setData(
                                  ClipboardData(text: profile.publicId),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(l10n.t('copied_id'))),
                                );
                              },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Public User Search by Unique ID (privacy-safe RPC)
                Text(
                  l10n.t('friends_section'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: InputDecoration(
                          hintText: l10n.t('search_users_hint'),
                          prefixIcon: const Icon(AppIcons.search, size: 18),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(AppIcons.x, size: 16),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (_searchQuery.trim().length < 4)
                        Text(
                          l10n.t('search_users_empty'),
                          style: Theme.of(context).textTheme.bodySmall,
                        )
                      else
                        searchResults.when(
                          loading: () => const Padding(
                            padding: EdgeInsets.all(AppSpacing.md),
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                          error: (e, _) => Text(e.toString()),
                          data: (users) {
                            if (users.isEmpty) {
                              return Text(
                                l10n.t('no_users_found'),
                                style: Theme.of(context).textTheme.bodySmall,
                              );
                            }
                            return Column(
                              children: users
                                  .map(
                                    (u) => ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: UserAvatar(
                                        name: u.fullName,
                                        imageUrl: u.avatarUrl,
                                        radius: 18,
                                      ),
                                      title: Text(u.fullName),
                                      subtitle: Text('@${u.publicId}'),
                                    ),
                                  )
                                  .toList(),
                            );
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Preferences & Settings
                Text(
                  l10n.t('settings_section'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(AppIcons.languages, size: 20),
                        title: Text(l10n.t('language_setting')),
                        trailing: SegmentedButton<String>(
                          segments: [
                            ButtonSegment(
                              value: 'en',
                              label: Text(l10n.t('language_english')),
                            ),
                            const ButtonSegment(
                              value: 'ur',
                              label: Text('اردو'),
                            ),
                          ],
                          selected: {currentLocale.languageCode},
                          onSelectionChanged: (sel) {
                            final code = sel.first;
                            ref.read(localeProvider.notifier).setLocale(code);
                            if (profile != null) {
                              ref
                                  .read(currentProfileProvider.notifier)
                                  .saveProfile(
                                    profile.copyWith(preferredLanguage: code),
                                  );
                            }
                          },
                          style: const ButtonStyle(
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(AppIcons.sunMoon, size: 20),
                        title: Text(l10n.t('theme_setting')),
                        trailing: SegmentedButton<ThemeMode>(
                          segments: [
                            ButtonSegment(
                              value: ThemeMode.light,
                              label: Text(l10n.t('theme_light')),
                            ),
                            ButtonSegment(
                              value: ThemeMode.dark,
                              label: Text(l10n.t('theme_dark')),
                            ),
                          ],
                          selected: {
                            themeMode == ThemeMode.dark
                                ? ThemeMode.dark
                                : ThemeMode.light,
                          },
                          onSelectionChanged: (sel) {
                            ref
                                .read(themeModeProvider.notifier)
                                .setThemeMode(sel.first);
                          },
                          style: const ButtonStyle(
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(AppIcons.coins, size: 20),
                        title: Text(l10n.t('currency_setting')),
                        trailing: Text(
                          profile?.defaultCurrency ??
                              SupportedCurrencies.defaultCurrency,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                AppButton(
                  label: l10n.t('sign_out'),
                  variant: AppButtonVariant.outline,
                  icon: AppIcons.logOut,
                  onPressed: () async {
                    final ok = await AppConfirmDialog.show(
                      context,
                      title: l10n.t('sign_out'),
                      message: l10n.t('sign_out_confirm'),
                      confirmLabel: l10n.t('sign_out'),
                      isDestructive: true,
                    );
                    if (!ok) return;
                    await ref.read(authRepositoryProvider).signOut();
                  },
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }
}
