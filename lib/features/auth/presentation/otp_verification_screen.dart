import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/error_messages.dart';
import '../providers/auth_providers.dart';
import 'reset_password_screen.dart';
import 'widgets/auth_widgets.dart';

enum OtpPurpose { signup, recovery }

/// OtpVerificationScreen checks the 6-digit code emailed by Supabase.
///  * signup   → the account is confirmed and signed in; AuthGate shows the dashboard.
///  * recovery → the user is signed in temporarily and must choose a new password.
class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({super.key, required this.email, required this.purpose});

  final String email;
  final OtpPurpose purpose;

  @override
  ConsumerState<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  static const _otpLength = 6;
  static const _resendCooldown = 60;

  final _codeController = TextEditingController();
  Timer? _timer;
  int _secondsLeft = _resendCooldown;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendCooldown);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) timer.cancel();
    });
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.length != _otpLength) {
      showAuthMessage(context, 'Vui lòng nhập đủ $_otpLength số');
      return;
    }

    setState(() => _isLoading = true);
    final auth = ref.read(authRepositoryProvider);
    final recoveryPending = ref.read(passwordRecoveryPendingProvider.notifier);
    try {
      if (widget.purpose == OtpPurpose.signup) {
        await auth.verifySignupOtp(email: widget.email, token: code);
        // Signed in: AuthGate pops this screen and shows the dashboard.
      } else {
        // Set before verifying: the session it creates must not open the dashboard yet.
        recoveryPending.state = true;
        await auth.verifyRecoveryOtp(email: widget.email, token: code);
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ResetPasswordScreen()));
      }
    } catch (e) {
      if (widget.purpose == OtpPurpose.recovery) recoveryPending.state = false;
      if (mounted) {
        _codeController.clear();
        showAuthMessage(context, friendlyError(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resend() async {
    final auth = ref.read(authRepositoryProvider);
    try {
      if (widget.purpose == OtpPurpose.signup) {
        await auth.resendSignupOtp(widget.email);
      } else {
        await auth.sendPasswordResetOtp(widget.email);
      }
      if (!mounted) return;
      _startCooldown();
      showAuthMessage(context, 'Đã gửi lại mã tới ${widget.email}');
    } catch (e) {
      if (mounted) showAuthMessage(context, friendlyError(e));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSignup = widget.purpose == OtpPurpose.signup;
    return AuthScaffold(
      children: [
        AuthBrandHeader(
          title: isSignup ? 'Xác thực email' : 'Nhập mã đặt lại',
          subtitle: 'Mã gồm $_otpLength số đã được gửi tới\n${widget.email}',
          icon: Icons.mark_email_read_outlined,
        ),
        const SizedBox(height: 28),
        AuthTextField(
          controller: _codeController,
          icon: Icons.pin_outlined,
          hint: '• • • • • •',
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.oneTimeCode],
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 10),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(_otpLength),
          ],
          onSubmitted: (_) => _verify(),
        ),
        const SizedBox(height: 24),
        AuthPrimaryButton(
          label: isSignup ? 'Xác thực' : 'Tiếp tục',
          isLoading: _isLoading,
          onPressed: _verify,
          icon: Icons.check,
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _secondsLeft > 0 || _isLoading ? null : _resend,
          child: Text(
            _secondsLeft > 0 ? 'Gửi lại mã sau ${_secondsLeft}s' : 'Gửi lại mã',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: _secondsLeft > 0 ? AppColors.outline : AppColors.primary,
            ),
          ),
        ),
        const Text(
          'Không thấy email? Hãy kiểm tra mục Spam / Quảng cáo.',
          style: TextStyle(fontSize: 12, color: AppColors.outline),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
