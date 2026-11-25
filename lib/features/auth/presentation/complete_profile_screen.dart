import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/currencies.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../profile/data/profile_model.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/providers/profile_provider.dart';
import '../providers/auth_provider.dart';

class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() =>
      _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _publicIdController = TextEditingController();
  final _phoneController = TextEditingController();

  String _selectedCurrency = SupportedCurrencies.defaultCurrency;
  String? _avatarUrl;
  bool? _isIdAvailable;
  bool _checkingId = false;
  bool _saving = false;
  String? _errorText;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    _publicIdController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _onPublicIdChanged(String value) {
    _debounce?.cancel();
    final err = AppValidators.publicId(value);
    if (err != null) {
      setState(() {
        _isIdAvailable = false;
        _checkingId = false;
      });
      return;
    }

    setState(() => _checkingId = true);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final ok = await ref
            .read(profileRepositoryProvider)
            .isPublicIdAvailable(value);
        if (mounted) {
          setState(() {
            _isIdAvailable = ok;
            _checkingId = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _checkingId = false);
      }
    });
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      imageQuality: 80,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final ext = file.name.split('.').last;
    try {
      final url = await ref
          .read(currentProfileProvider.notifier)
          .uploadAvatar(bytes: bytes, fileExtension: ext);
      if (mounted && url != null) {
        setState(() => _avatarUrl = url);
      }
    } catch (e) {
      if (mounted) setState(() => _errorText = e.toString());
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isIdAvailable == false) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() {
      _saving = true;
      _errorText = null;
    });

    try {
      final locale = ref.read(localeProvider);
      final profile = UserProfile(
        id: user.id,
        publicId: _publicIdController.text.trim().toLowerCase(),
        fullName: _nameController.text.trim(),
        email: user.email ?? '',
        phone: _phoneController.text.trim(),
        avatarUrl: _avatarUrl,
        defaultCurrency: _selectedCurrency,
        preferredLanguage: locale.languageCode,
        profileCompleted: true,
      );
      await ref.read(currentProfileProvider.notifier).saveProfile(profile);
      if (mounted) context.go(RoutePaths.home);
    } catch (e) {
      if (mounted) setState(() => _errorText = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('complete_profile_title'))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.t('complete_profile_subtitle'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
              Center(
                child: GestureDetector(
                  onTap: _pickAvatar,
                  child: Stack(
                    children: [
                      UserAvatar(
                        name: _nameController.text.isEmpty
                            ? 'U'
                            : _nameController.text,
                        imageUrl: _avatarUrl,
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
                          child: const Icon(
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
              const SizedBox(height: AppSpacing.xl),
              AppCard(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppTextField(
                        controller: _nameController,
                        label: l10n.t('full_name'),
                        validator: AppValidators.fullName,
                        prefixIcon: const Icon(AppIcons.user, size: 18),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppTextField(
                        controller: _publicIdController,
                        label: l10n.t('public_id'),
                        hint: l10n.t('public_id_hint'),
                        helperText: l10n.t('public_id_helper'),
                        validator: AppValidators.publicId,
                        onChanged: _onPublicIdChanged,
                        prefixIcon: const Icon(AppIcons.atSign, size: 18),
                        suffixIcon: _checkingId
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : _isIdAvailable == null
                                ? null
                                : Icon(
                                    _isIdAvailable!
                                        ? AppIcons.checkCircle2
                                        : AppIcons.xCircle,
                                    color: _isIdAvailable!
                                        ? AppColors.positiveGreen
                                        : AppColors.negativeRed,
                                    size: 18,
                                  ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppTextField(
                        controller: _phoneController,
                        label: l10n.t('phone_optional'),
                        keyboardType: TextInputType.phone,
                        prefixIcon: const Icon(AppIcons.phone, size: 18),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        l10n.t('default_currency'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.xs + 2),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedCurrency,
                        items: SupportedCurrencies.all
                            .map(
                              (c) => DropdownMenuItem(
                                value: c.code,
                                child: Text(
                                  locale.languageCode == 'ur'
                                      ? c.nameUr
                                      : c.nameEn,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedCurrency = v);
                        },
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
                        label: l10n.t('finish_setup'),
                        isLoading: _saving,
                        onPressed: _submit,
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
