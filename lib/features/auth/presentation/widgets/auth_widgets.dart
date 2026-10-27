import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';

/// Shared building blocks for the auth screens (login, register, OTP, reset).

bool isValidEmail(String value) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());

void showAuthMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
}

/// Logo + title + subtitle shown at the top of every auth screen.
class AuthBrandHeader extends StatelessWidget {
  const AuthBrandHeader(
      {super.key, required this.title, required this.subtitle, this.icon = Icons.account_balance_wallet});

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryContainer],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(icon, size: 38, color: Colors.white),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant, height: 1.4),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Rounded white input with a leading icon; password fields get a visibility toggle.
class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.icon,
    required this.hint,
    this.isPassword = false,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.autofillHints,
    this.onSubmitted,
    this.inputFormatters,
    this.textAlign = TextAlign.start,
    this.style,
  });

  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final bool isPassword;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final TextAlign textAlign;
  final TextStyle? style;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6)],
      ),
      child: TextField(
        controller: widget.controller,
        obscureText: widget.isPassword && _obscured,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        autofillHints: widget.autofillHints,
        onSubmitted: widget.onSubmitted,
        inputFormatters: widget.inputFormatters,
        textAlign: widget.textAlign,
        autocorrect: !widget.isPassword,
        enableSuggestions: !widget.isPassword,
        style: widget.style ?? const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          prefixIcon: Icon(widget.icon, color: AppColors.primary, size: 20),
          suffixIcon: widget.isPassword
              ? IconButton(
                  icon: Icon(
                    _obscured ? Icons.visibility_off : Icons.visibility,
                    color: AppColors.outline,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscured = !_obscured),
                )
              : null,
          hintText: widget.hint,
          hintStyle: TextStyle(fontSize: 13, color: AppColors.outline.withOpacity(0.7)),
          border: InputBorder.none,
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}

/// Full-width emerald button with a loading spinner.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon = Icons.arrow_forward,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withOpacity(0.6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 3,
          shadowColor: AppColors.primary.withOpacity(0.3),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  if (icon != null) ...[
                    const SizedBox(width: 6),
                    Icon(icon, size: 18),
                  ],
                ],
              ),
      ),
    );
  }
}

/// Scaffold shared by the secondary auth screens: back button + scrollable body.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.children, this.onBack});

  final List<Widget> children;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
          onPressed: onBack ?? () => Navigator.maybePop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
      ),
    );
  }
}
