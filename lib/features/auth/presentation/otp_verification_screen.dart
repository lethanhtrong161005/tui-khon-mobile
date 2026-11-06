import '../../../core/theme/semantic_colors.dart';
import '../../../l10n/app_l10n.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/error_messages.dart';
import '../providers/auth_providers.dart';
import 'reset_password_screen.dart';
import 'widgets/auth_widgets.dart';

enum OtpPurpose { signup, recovery }

/// OtpVerificationScreen checks the 6-digit code emailed by Supabase.
///  * signup   → the account is confirmed and signed in; AuthGate shows the dashboard.
///  * recovery → the user is signed in temporarily and must choose a new password.
class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen(
      {super.key, required this.email, required this.purpose});

  final String email;
  final OtpPurpose purpose;

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
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
      showAuthMessage(context,
          appL10n(context).msgEnterAllDigits108((_otpLength).toString()));
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
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const ResetPasswordScreen()));
      }
    } catch (e) {
      if (widget.purpose == OtpPurpose.recovery) recoveryPending.state = false;
      if (mounted) {
        _codeController.clear();
        showAuthMessage(context, friendlyError(e, context: context));
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
      showAuthMessage(context,
          appL10n(context).msgANewCodeWasSentTo109((widget.email).toString()));
    } catch (e) {
      if (mounted) showAuthMessage(context, friendlyError(e, context: context));
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
          title: isSignup
              ? appL10n(context).msgVerifyEmail110
              : appL10n(context).msgEnterResetCode111,
          subtitle: appL10n(context).msgADigitCodeWasSentTo112(
              (_otpLength).toString(), (widget.email).toString()),
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
          style: const TextStyle(
              fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 10),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(_otpLength),
          ],
          onSubmitted: (_) => _verify(),
        ),
        const SizedBox(height: 24),
        AuthPrimaryButton(
          label: isSignup
              ? appL10n(context).msgVerify113
              : appL10n(context).msgContinue114,
          isLoading: _isLoading,
          onPressed: _verify,
          icon: Icons.check,
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _secondsLeft > 0 || _isLoading ? null : _resend,
          child: Text(
            _secondsLeft > 0
                ? appL10n(context).msgResendInS115((_secondsLeft).toString())
                : appL10n(context).msgResendCode116,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: _secondsLeft > 0
                  ? appPalette(context).outline
                  : appPalette(context).primary,
            ),
          ),
        ),
        Text(
          appL10n(context).msgNoEmailCheckYourSpamOr117,
          style: TextStyle(fontSize: 12, color: appPalette(context).outline),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
