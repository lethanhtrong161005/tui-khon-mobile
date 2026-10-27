import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
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

  Future<void> _handleRegister() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    String? problem;
    if (name.isEmpty) {
      problem = 'Vui lòng nhập tên hiển thị';
    } else if (!isValidEmail(email)) {
      problem = 'Vui lòng nhập email hợp lệ';
    } else if (password.length < 6) {
      problem = 'Mật khẩu cần ít nhất 6 ký tự';
    } else if (password != _confirmController.text) {
      problem = 'Mật khẩu nhập lại không khớp';
    }
    if (problem != null) {
      showAuthMessage(context, problem);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final needsOtp =
          await ref.read(authRepositoryProvider).signUp(email: email, password: password, displayName: name);
      if (!mounted) return;
      // Without email confirmation Supabase signs in right away and AuthGate takes over.
      if (needsOtp) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => OtpVerificationScreen(email: email, purpose: OtpPurpose.signup)),
        );
      }
    } catch (e) {
      if (mounted) showAuthMessage(context, friendlyError(e));
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

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      children: [
        const AuthBrandHeader(
          title: 'Tạo tài khoản',
          subtitle: 'Ghi chép chi tiêu bằng giọng nói, quét hóa đơn\nvà nhận tư vấn từ Gemini AI',
          icon: Icons.person_add_alt_1,
        ),
        const SizedBox(height: 28),
        AutofillGroup(
          child: Column(
            children: [
              AuthTextField(
                controller: _nameController,
                icon: Icons.badge_outlined,
                hint: 'Tên hiển thị (vd: Minh Quân)',
                autofillHints: const [AutofillHints.name],
              ),
              const SizedBox(height: 12),
              AuthTextField(
                controller: _emailController,
                icon: Icons.alternate_email_rounded,
                hint: 'Email',
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
              ),
              const SizedBox(height: 12),
              AuthTextField(
                controller: _passwordController,
                icon: Icons.lock_outline,
                hint: 'Mật khẩu (ít nhất 6 ký tự)',
                isPassword: true,
                autofillHints: const [AutofillHints.newPassword],
              ),
              const SizedBox(height: 12),
              AuthTextField(
                controller: _confirmController,
                icon: Icons.lock_reset,
                hint: 'Nhập lại mật khẩu',
                isPassword: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _handleRegister(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        AuthPrimaryButton(label: 'Đăng ký', isLoading: _isLoading, onPressed: _handleRegister),
        const SizedBox(height: 12),
        const Text(
          'Túi Khôn sẽ gửi mã xác thực 6 số tới email của bạn.',
          style: TextStyle(fontSize: 12, color: AppColors.outline),
          textAlign: TextAlign.center,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Đã có tài khoản?', style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant)),
            TextButton(
              onPressed: _isLoading ? null : () => Navigator.pop(context),
              child: const Text(
                'Đăng nhập',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
