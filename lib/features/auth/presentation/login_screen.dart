import '../../../core/theme/semantic_colors.dart';
import '../../../l10n/app_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/error_messages.dart';
import '../providers/auth_providers.dart';
import 'forgot_password_screen.dart';
import 'otp_verification_screen.dart';
import 'register_screen.dart';
import 'widgets/auth_widgets.dart';

/// LoginScreen is the entry gate when no Supabase session exists.
/// Supports Google Sign-In and email + password; on success [AuthGate]
/// switches to the dashboard automatically.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();

  Future<void> _handleEmailLogin() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() => _isLoading = true);
    final auth = ref.read(authRepositoryProvider);
    try {
      await auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'email_not_confirmed') {
        // Account exists but the signup code was never entered: send a new one.
        var sent = false;
        try {
          await auth.resendSignupOtp(email);
          sent = true;
        } catch (_) {
          // The OTP screen lets the user request another code anyway.
        }
        if (!mounted) return;
        showAuthMessage(
            context,
            sent
                ? appL10n(context)
                    .msgANewVerificationCodeWasSent96((email).toString())
                : appL10n(context).msgYourEmailIsNotVerifiedYou97);
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => OtpVerificationScreen(
                  email: email, purpose: OtpPurpose.signup)),
        );
      } else {
        showAuthMessage(context, friendlyError(e, context: context));
      }
    } catch (e) {
      if (mounted) showAuthMessage(context, friendlyError(e, context: context));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
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
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
          layout: AuthLayout.login,
          showBack: false,
          busy: _isLoading,
          children: [
            const SizedBox(height: 16),
            AuthBrandHeader(
                title: 'Túi Khôn',
                subtitle: appL10n(context)
                    .msgPersonalFinanceNotebookGeminiAiAssistant99),
            const AuthHeroIllustration(),
            GoogleAuthButton(onPressed: _handleGoogleSignIn, busy: _isLoading),
            AuthDivider(appL10n(context).msgOrSignInWith100),
            Form(
                key: _formKey,
                child: AutofillGroup(
                    child: Column(children: [
                  AuthTextField(
                      controller: _emailController,
                      enabled: !_isLoading,
                      icon: Icons.mail_outline_rounded,
                      hint: 'Email',
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      validator: (v) => isValidEmail(v ?? '')
                          ? null
                          : appL10n(context).msgEnterAValidEmailAddress91),
                  const SizedBox(height: 14),
                  AuthTextField(
                      controller: _passwordController,
                      enabled: !_isLoading,
                      icon: Icons.lock_outline_rounded,
                      hint: appL10n(context).msgPassword101,
                      isPassword: true,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      validator: (v) => (v ?? '').isEmpty
                          ? appL10n(context).msgEnterYourPassword102
                          : null,
                      onSubmitted: (_) => _handleEmailLogin()),
                ]))),
            Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => ForgotPasswordScreen(
                                    initialEmail:
                                        _emailController.text.trim()))),
                    child: Text(appL10n(context).msgForgotPassword103))),
            const SizedBox(height: 8),
            AuthPrimaryButton(
                label: appL10n(context).msgSignIn104,
                isLoading: _isLoading,
                onPressed: _handleEmailLogin),
            const SizedBox(height: 10),
            Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(appL10n(context).msgDonTHaveAnAccount105,
                      style: TextStyle(
                          fontSize: 12,
                          color: appPalette(context).onSurfaceVariant)),
                  TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const RegisterScreen())),
                      child: Text(appL10n(context).msgRegisterNow106)),
                ]),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.shield_outlined,
                  size: 17, color: appPalette(context).primary),
              const SizedBox(width: 8),
              Flexible(
                  child: Text(
                      appL10n(context).msgYourRecordsArePrivateToYour107,
                      style: TextStyle(
                          fontSize: 11,
                          color: appPalette(context).onSurfaceVariant)))
            ]),
          ]);
}
