import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/error_messages.dart';
import '../providers/auth_providers.dart';
import 'otp_verification_screen.dart';
import 'widgets/auth_widgets.dart';

/// ForgotPasswordScreen sends a 6-digit reset code, then hands over to
/// [OtpVerificationScreen] (recovery) → [ResetPasswordScreen].
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  late final TextEditingController _emailController = TextEditingController(text: widget.initialEmail);
  bool _isLoading = false;

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (!isValidEmail(email)) {
      showAuthMessage(context, 'Vui lòng nhập email hợp lệ');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).sendPasswordResetOtp(email);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => OtpVerificationScreen(email: email, purpose: OtpPurpose.recovery)),
      );
    } catch (e) {
      if (mounted) showAuthMessage(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      children: [
        const AuthBrandHeader(
          title: 'Quên mật khẩu',
          subtitle: 'Nhập email đã đăng ký, Túi Khôn sẽ gửi\nmã 6 số để bạn đặt lại mật khẩu',
          icon: Icons.lock_reset,
        ),
        const SizedBox(height: 28),
        AuthTextField(
          controller: _emailController,
          icon: Icons.alternate_email_rounded,
          hint: 'Email',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.email],
          onSubmitted: (_) => _sendCode(),
        ),
        const SizedBox(height: 24),
        AuthPrimaryButton(label: 'Gửi mã', isLoading: _isLoading, onPressed: _sendCode, icon: Icons.send),
        const SizedBox(height: 12),
        const Text(
          'Mã có hiệu lực trong 10 phút.',
          style: TextStyle(fontSize: 12, color: AppColors.outline),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
