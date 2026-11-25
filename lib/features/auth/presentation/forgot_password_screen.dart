import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../data/auth_repository.dart';

enum _RecoveryStage { email, otp, newPassword }

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();

  _RecoveryStage _stage = _RecoveryStage.email;
  bool _isLoading = false;
  String? _errorText;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .sendPasswordResetOtp(_emailController.text);
      if (mounted) setState(() => _stage = _RecoveryStage.otp);
    } catch (e) {
      if (mounted) setState(() => _errorText = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyResetOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      await ref.read(authRepositoryProvider).verifyRecoveryOtp(
            email: _emailController.text,
            token: _otpController.text,
          );
      if (mounted) setState(() => _stage = _RecoveryStage.newPassword);
    } catch (e) {
      if (mounted) setState(() => _errorText = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .setPassword(_passwordController.text);
      if (mounted) context.go(RoutePaths.home);
    } catch (e) {
      if (mounted) setState(() => _errorText = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.t('reset_password_title'),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.t('reset_password_subtitle'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
              AppCard(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_stage == _RecoveryStage.email)
                        AppTextField(
                          controller: _emailController,
                          label: l10n.t('email'),
                          hint: l10n.t('email_hint'),
                          keyboardType: TextInputType.emailAddress,
                          validator: AppValidators.email,
                          prefixIcon: const Icon(AppIcons.mail, size: 18),
                        ),
                      if (_stage == _RecoveryStage.otp)
                        AppTextField(
                          controller: _otpController,
                          label: l10n.t('otp_label'),
                          hint: '123456',
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          validator: AppValidators.otpCode,
                          prefixIcon:
                              const Icon(AppIcons.shieldCheck, size: 18),
                        ),
                      if (_stage == _RecoveryStage.newPassword)
                        AppTextField(
                          controller: _passwordController,
                          label: l10n.t('new_password'),
                          obscureText: true,
                          validator: AppValidators.password,
                          prefixIcon: const Icon(AppIcons.lock, size: 18),
                        ),
                      if (_errorText != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          _errorText!,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.negativeRed),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      AppButton(
                        label: switch (_stage) {
                          _RecoveryStage.email => l10n.t('send_code'),
                          _RecoveryStage.otp => l10n.t('verify_continue'),
                          _RecoveryStage.newPassword =>
                            l10n.t('update_password'),
                        },
                        isLoading: _isLoading,
                        onPressed: switch (_stage) {
                          _RecoveryStage.email => _sendReset,
                          _RecoveryStage.otp => _verifyResetOtp,
                          _RecoveryStage.newPassword => _updatePassword,
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
