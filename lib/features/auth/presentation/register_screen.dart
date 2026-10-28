import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

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

  Future<void> _google() async {
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
  Widget build(BuildContext context) =>
      AuthScaffold(layout: AuthLayout.register, busy: _isLoading, children: [
        const SizedBox(height: 16),
        const AuthBrandHeader(
            title: 'Tạo tài khoản',
            subtitle:
                'Ghi chép chi tiêu bằng giọng nói, quét hóa đơn\nvà nhận tư vấn từ Gemini AI'),
        const SizedBox(height: 20),
        Form(
            key: _formKey,
            child: AutofillGroup(
                child: Column(children: [
              AuthTextField(
                  controller: _nameController,
                  enabled: !_isLoading,
                  icon: Icons.person_outline_rounded,
                  hint: 'Tên hiển thị (vd: Minh Quân)',
                  helperText: 'Tên này sẽ hiển thị trong ứng dụng',
                  autofillHints: const [AutofillHints.name],
                  validator: (v) => (v ?? '').trim().isEmpty
                      ? 'Vui lòng nhập tên hiển thị'
                      : null),
              const SizedBox(height: 12),
              AuthTextField(
                  controller: _emailController,
                  enabled: !_isLoading,
                  icon: Icons.mail_outline_rounded,
                  hint: 'Email',
                  helperText: 'Dùng email để đăng nhập và nhận mã xác thực',
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  validator: (v) => isValidEmail(v ?? '')
                      ? null
                      : 'Vui lòng nhập email hợp lệ'),
              const SizedBox(height: 12),
              AuthTextField(
                  controller: _passwordController,
                  enabled: !_isLoading,
                  icon: Icons.lock_outline_rounded,
                  hint: 'Mật khẩu (ít nhất 6 ký tự)',
                  isPassword: true,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (v) => (v ?? '').length < 6
                      ? 'Mật khẩu cần ít nhất 6 ký tự'
                      : null),
              const SizedBox(height: 12),
              AuthTextField(
                  controller: _confirmController,
                  enabled: !_isLoading,
                  icon: Icons.lock_outline_rounded,
                  hint: 'Nhập lại mật khẩu',
                  isPassword: true,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.done,
                  validator: (v) =>
                      (v ?? '').isEmpty || v != _passwordController.text
                          ? 'Mật khẩu nhập lại không khớp'
                          : null,
                  onSubmitted: (_) => _handleRegister()),
            ]))),
        const SizedBox(height: 16),
        AuthPrimaryButton(
            label: 'Đăng ký',
            isLoading: _isLoading,
            onPressed: _handleRegister),
        const SizedBox(height: 12),
        const Text('Túi Khôn sẽ gửi mã xác thực 6 số tới email của bạn.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
        const AuthDivider('Hoặc đăng ký bằng'),
        GoogleAuthButton(register: true, busy: _isLoading, onPressed: _google),
        const SizedBox(height: 8),
        Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Đã có tài khoản?',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.onSurfaceVariant)),
              TextButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  child: const Text('Đăng nhập')),
            ]),
      ]);
}
