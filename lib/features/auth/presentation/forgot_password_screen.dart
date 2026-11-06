import '../../../core/theme/semantic_colors.dart';
import '../../../l10n/app_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  late final TextEditingController _emailController =
      TextEditingController(text: widget.initialEmail);
  bool _isLoading = false;

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (!isValidEmail(email)) {
      showAuthMessage(context, appL10n(context).msgEnterAValidEmailAddress91);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).sendPasswordResetOtp(email);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(
                email: email, purpose: OtpPurpose.recovery)),
      );
    } catch (e) {
      if (mounted) showAuthMessage(context, friendlyError(e, context: context));
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
        AuthBrandHeader(
          title: appL10n(context).msgForgotPassword92,
          subtitle: appL10n(context).msgEnterYourRegisteredEmailTI93,
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
        AuthPrimaryButton(
            label: appL10n(context).msgSendCode94,
            isLoading: _isLoading,
            onPressed: _sendCode,
            icon: Icons.send),
        const SizedBox(height: 12),
        Text(
          appL10n(context).msgTheCodeExpiresInMinutes95,
          style: TextStyle(fontSize: 12, color: appPalette(context).outline),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
