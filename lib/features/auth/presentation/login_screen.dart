import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/router/route_names.dart';
import '../../../core/services/connectivity_provider.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../data/auth_repository.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorText;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _showOfflineAlert() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('No Internet Connection'),
        content: const Text(
          'Please connect to Wi-Fi or mobile data before signing in.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final online = await ConnectivityService.hasInternet();
    if (!online) {
      if (mounted) await _showOfflineAlert();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      await ref.read(authRepositoryProvider).signInWithPassword(
            email: _emailController.text,
            password: _passwordController.text,
          );
    } catch (e) {
      if (mounted) {
        if (ErrorFormatter.isNetworkError(e)) {
          await _showOfflineAlert();
        } else {
          setState(() => _errorText = ErrorFormatter.friendly(e));
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currentLocale = ref.watch(localeProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          'assets/images/logo.jpg',
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        l10n.t('app_name'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 'en', label: Text('EN')),
                      ButtonSegment(value: 'ur', label: Text('اردو')),
                    ],
                    selected: {currentLocale.languageCode},
                    onSelectionChanged: (selection) {
                      ref.read(localeProvider.notifier).setLocale(selection.first);
                    },
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxxl),
              Text(
                l10n.t('login_title'),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.t('login_subtitle'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
              if (!SupabaseConfig.isReady) ...[
                AppCard(
                  backgroundColor: AppColors.warningAmberSoft,
                  child: Row(
                    children: [
                      const Icon(
                        AppIcons.alertTriangle,
                        color: AppColors.warningAmber,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          l10n.t('supabase_not_configured'),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.lightTextPrimary,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              AppCard(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppTextField(
                        controller: _emailController,
                        label: l10n.t('email'),
                        hint: l10n.t('email_hint'),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: AppValidators.email,
                        prefixIcon: const Icon(AppIcons.mail, size: 18),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppTextField(
                        controller: _passwordController,
                        label: l10n.t('password'),
                        hint: l10n.t('password_hint'),
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Password is required' : null,
                        prefixIcon: const Icon(AppIcons.lock, size: 18),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? AppIcons.eye
                                : AppIcons.eyeOff,
                            size: 18,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton(
                          onPressed: () => context.push(RoutePaths.forgotPassword),
                          child: Text(l10n.t('forgot_password')),
                        ),
                      ),
                      if (_errorText != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _errorText!,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.negativeRed),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        label: l10n.t('sign_in'),
                        isLoading: _isLoading,
                        onPressed: SupabaseConfig.isReady ? _submit : null,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    l10n.t('no_account'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  TextButton(
                    onPressed: () => context.push(RoutePaths.register),
                    child: Text(l10n.t('create_account')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
