import '../../../core/theme/semantic_colors.dart';
import '../../../l10n/app_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/utils/error_messages.dart';
import '../providers/auth_providers.dart';
import 'otp_verification_screen.dart';
import 'widgets/auth_widgets.dart';

/// RegisterScreen creates an email/password account, then moves to the
/// 6-digit OTP screen. Profile, default wallet and categories are created
/// by the database trigger `handle_new_user`.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();

  Future<void> _handleRegister() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() => _isLoading = true);
    try {
      final needsOtp = await ref
          .read(authRepositoryProvider)
          .signUp(email: email, password: password, displayName: name);
      if (!mounted) return;
      // Without email confirmation Supabase signs in right away and AuthGate takes over.
      if (needsOtp) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => OtpVerificationScreen(
                  email: email, purpose: OtpPurpose.signup)),
        );
      }
    } catch (e) {
      if (mounted) showAuthMessage(context, friendlyError(e, context: context));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _google() async {
    if (_isLoading) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
    } on GoogleSignInException catch (e) {
      if (mounted && e.code != GoogleSignInExceptionCode.canceled)
        showAuthMessage(context, friendlyError(e, context: context));
    } catch (e) {
      if (mounted) showAuthMessage(context, friendlyError(e, context: context));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      AuthScaffold(layout: AuthLayout.register, busy: _isLoading, children: [
        const SizedBox(height: 16),
        AuthBrandHeader(
            title: appL10n(context).msgCreateAccount118,
            subtitle: appL10n(context).msgRecordExpensesByVoiceScanReceipts119),
        const SizedBox(height: 20),
        Form(
            key: _formKey,
            child: AutofillGroup(
                child: Column(children: [
              AuthTextField(
                  controller: _nameController,
                  enabled: !_isLoading,
                  icon: Icons.person_outline_rounded,
                  hint: appL10n(context).msgDisplayNameEGMinhQuan120,
                  helperText: appL10n(context).msgThisNameWillAppearInThe121,
                  autofillHints: const [AutofillHints.name],
                  validator: (v) => (v ?? '').trim().isEmpty
                      ? appL10n(context).msgEnterADisplayName122
                      : null),
              const SizedBox(height: 12),
              AuthTextField(
                  controller: _emailController,
                  enabled: !_isLoading,
                  icon: Icons.mail_outline_rounded,
                  hint: 'Email',
                  helperText: appL10n(context).msgUseThisEmailToSignIn123,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  validator: (v) => isValidEmail(v ?? '')
                      ? null
                      : appL10n(context).msgEnterAValidEmailAddress91),
              const SizedBox(height: 12),
              AuthTextField(
                  controller: _passwordController,
                  enabled: !_isLoading,
                  icon: Icons.lock_outline_rounded,
                  hint: appL10n(context).msgPasswordAtLeastCharacters124,
                  isPassword: true,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (v) => (v ?? '').length < 6
                      ? appL10n(context).msgUseAtLeastCharacters125
                      : null),
              const SizedBox(height: 12),
              AuthTextField(
                  controller: _confirmController,
                  enabled: !_isLoading,
                  icon: Icons.lock_outline_rounded,
                  hint: appL10n(context).msgConfirmPassword126,
                  isPassword: true,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.done,
                  validator: (v) =>
                      (v ?? '').isEmpty || v != _passwordController.text
                          ? appL10n(context).msgPasswordsDoNotMatch127
                          : null,
                  onSubmitted: (_) => _handleRegister()),
            ]))),
        const SizedBox(height: 16),
        AuthPrimaryButton(
            label: appL10n(context).msgRegister128,
            isLoading: _isLoading,
            onPressed: _handleRegister),
        const SizedBox(height: 12),
        Text(appL10n(context).msgTIKhNWillSend129,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 11, color: appPalette(context).onSurfaceVariant)),
        AuthDivider(appL10n(context).msgOrRegisterWith130),
        GoogleAuthButton(register: true, busy: _isLoading, onPressed: _google),
        const SizedBox(height: 8),
        Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(appL10n(context).msgAlreadyHaveAnAccount131,
                  style: TextStyle(
                      fontSize: 12,
                      color: appPalette(context).onSurfaceVariant)),
              TextButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  child: Text(appL10n(context).msgSignIn104)),
            ]),
      ]);
}
