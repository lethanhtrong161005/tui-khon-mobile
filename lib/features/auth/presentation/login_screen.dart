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

  Future<void> _handleEmailLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (!isValidEmail(email)) {
      showAuthMessage(context, 'Vui lòng nhập email hợp lệ');
      return;
    }
    if (password.isEmpty) {
      showAuthMessage(context, 'Vui lòng nhập mật khẩu');
      return;
    }

    setState(() => _isLoading = true);
    final auth = ref.read(authRepositoryProvider);
    try {
      await auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'email_not_confirmed') {
        // Account exists but the signup code was never entered: send a new one.
        try {
          await auth.resendSignupOtp(email);
        } catch (_) {
          // The OTP screen lets the user request another code anyway.
        }
        if (!mounted) return;
        showAuthMessage(context, 'Email chưa xác thực. Mã mới đã được gửi tới $email');
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => OtpVerificationScreen(email: email, purpose: OtpPurpose.signup)),
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
    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
    } on GoogleSignInException catch (e) {
      if (mounted && e.code != GoogleSignInExceptionCode.canceled) showAuthMessage(context, friendlyError(e));
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                const AuthBrandHeader(
                  title: 'Túi Khôn',
                  subtitle: 'Quản lý tài chính cá nhân & Trợ lý Gemini AI',
                ),
                const SizedBox(height: 32),

                // 1. Google Sign-In Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _handleGoogleSignIn,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: BorderSide(color: AppColors.outlineVariant.withOpacity(0.4)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 1,
                      shadowColor: Colors.black.withOpacity(0.04),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.g_mobiledata, color: Colors.red, size: 30),
                        SizedBox(width: 8),
                        Text(
                          'Tiếp tục với Google',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Divider "hoặc email"
                Row(
                  children: [
                    Expanded(child: Divider(color: AppColors.outlineVariant.withOpacity(0.4))),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12.0),
                      child: Text(
                        'HOẶC EMAIL',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.outline,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: AppColors.outlineVariant.withOpacity(0.4))),
                  ],
                ),

                const SizedBox(height: 20),

                AuthTextField(
                  controller: _emailController,
                  icon: Icons.alternate_email_rounded,
                  hint: 'Email (vd: ban@gmail.com)',
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                ),
                const SizedBox(height: 12),
                AuthTextField(
                  controller: _passwordController,
                  icon: Icons.lock_outline,
                  hint: 'Nhập mật khẩu',
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => _handleEmailLogin(),
                ),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ForgotPasswordScreen(initialEmail: _emailController.text.trim()),
                              ),
                            ),
                    child: const Text(
                      'Quên mật khẩu?',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                AuthPrimaryButton(label: 'Đăng Nhập', isLoading: _isLoading, onPressed: _handleEmailLogin),

                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Chưa có tài khoản?',
                      style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
                    ),
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                      child: const Text(
                        'Đăng ký ngay',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Security & Privacy guarantee footer
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shield, color: AppColors.primary, size: 15),
                    SizedBox(width: 6),
                    Text(
                      'Kết nối mã hóa • Dữ liệu chỉ bạn xem được',
                      style: TextStyle(fontSize: 11, color: AppColors.outline),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
