import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
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
                ? 'Mã xác thực mới đã được gửi tới $email'
                : 'Email chưa xác thực. Bạn có thể gửi lại mã ở màn tiếp theo.');
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => OtpVerificationScreen(
                  email: email, purpose: OtpPurpose.signup)),
        );
      } else {
        showAuthMessage(context, friendlyError(e));
      }
    } catch (e) {
      if (mounted) showAuthMessage(context, friendlyError(e));
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
        showAuthMessage(context, friendlyError(e));
    } catch (e) {
      if (mounted) showAuthMessage(context, friendlyError(e));
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
            const AuthBrandHeader(
                title: 'Túi Khôn',
                subtitle: 'Quản lý tài chính cá nhân &\nTrợ lý Gemini AI'),
            const AuthHeroIllustration(),
            GoogleAuthButton(onPressed: _handleGoogleSignIn, busy: _isLoading),
            const AuthDivider('Hoặc đăng nhập bằng'),
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
                          : 'Vui lòng nhập email hợp lệ'),
                  const SizedBox(height: 14),
                  AuthTextField(
                      controller: _passwordController,
                      enabled: !_isLoading,
                      icon: Icons.lock_outline_rounded,
                      hint: 'Mật khẩu',
                      isPassword: true,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      validator: (v) =>
                          (v ?? '').isEmpty ? 'Vui lòng nhập mật khẩu' : null,
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
                    child: const Text('Quên mật khẩu?'))),
            const SizedBox(height: 8),
            AuthPrimaryButton(
                label: 'Đăng nhập',
                isLoading: _isLoading,
                onPressed: _handleEmailLogin),
            const SizedBox(height: 10),
            Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Chưa có tài khoản?',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.onSurfaceVariant)),
                  TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const RegisterScreen())),
                      child: const Text('Đăng ký ngay')),
                ]),
            const SizedBox(height: 12),
            const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.shield_outlined, size: 17, color: AppColors.primary),
              SizedBox(width: 8),
              Flexible(
                  child: Text('Ghi chép riêng theo tài khoản của bạn',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.onSurfaceVariant)))
            ]),
          ]);
}
