import '../../../../core/theme/semantic_colors.dart';
import '../../../../l10n/app_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/config/env.dart';
import '../../../../core/theme/appearance.dart';

/// Shared building blocks for the auth screens (login, register, OTP, reset).

bool isValidEmail(String value) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());

void showAuthMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
}

enum AuthLayout { secondary, login, register }

class _AuthStyle extends InheritedWidget {
  const _AuthStyle({required this.compact, required super.child});
  final bool compact;
  static bool isCompact(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_AuthStyle>()?.compact ??
      false;
  @override
  bool updateShouldNotify(_AuthStyle oldWidget) => compact != oldWidget.compact;
}

/// Logo + title + subtitle shown at the top of every auth screen.
class AuthBrandHeader extends StatelessWidget {
  const AuthBrandHeader(
      {super.key,
      required this.title,
      required this.subtitle,
      this.icon = Icons.account_balance_wallet});

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final compact = _AuthStyle.isCompact(context);
    return Column(
      children: [
        Container(
          width: compact ? 68 : 76,
          height: compact ? 68 : 76,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [appPalette(context).primary, AppColors.primaryContainer],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(compact ? 20 : 24),
            boxShadow: [
              BoxShadow(
                color: appPalette(context).primary.withValues(alpha: .16),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: compact
              ? const CustomPaint(painter: const _AuthLogoPainter())
              : Icon(icon, size: 38, color: Colors.white),
        ),
        SizedBox(height: compact ? 14 : 16),
        Text(
          title,
          style: TextStyle(
            fontSize: compact ? 24 : 26,
            fontWeight: FontWeight.w800,
            color: appPalette(context).onSurface,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: compact ? 8 : 6),
        Text(
          subtitle,
          style: TextStyle(
              fontSize: 13,
              color: appPalette(context).onSurfaceVariant,
              height: 1.4),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _AuthLogoPainter extends CustomPainter {
  const _AuthLogoPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final wallet = Rect.fromCenter(
        center: center + const Offset(0, 1), width: 32, height: 25);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            wallet.translate(0, -5), const Radius.circular(4)),
        Paint()..color = const Color(0xFF92DDC3));
    canvas.drawRRect(RRect.fromRectAndRadius(wallet, const Radius.circular(4)),
        Paint()..color = Colors.white);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(wallet.right - 9, wallet.top + 7, 13, 12),
            const Radius.circular(3)),
        Paint()..color = const Color(0xFF2BAF8A));
    canvas.drawCircle(Offset(wallet.right - 3, wallet.top + 13), 2,
        Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_AuthLogoPainter oldDelegate) => false;
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
    this.enabled = true,
    this.validator,
    this.helperText,
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
  final bool enabled;
  final String? Function(String?)? validator;
  final String? helperText;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  bool _obscured = true;
  final _fieldKey = GlobalKey<FormFieldState<String>>();
  Locale? _locale;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = Localizations.maybeLocaleOf(context);
    if (_locale != next && _fieldKey.currentState?.hasError == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fieldKey.currentState?.validate();
      });
    }
    _locale = next;
  }

  @override
  Widget build(BuildContext context) {
    final compact = _AuthStyle.isCompact(context);
    final field = TextFormField(
      key: _fieldKey,
      controller: widget.controller,
      enabled: widget.enabled,
      validator: widget.validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      obscureText: widget.isPassword && _obscured,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      onFieldSubmitted: widget.onSubmitted,
      inputFormatters: widget.inputFormatters,
      textAlign: widget.textAlign,
      autocorrect: !widget.isPassword,
      enableSuggestions: !widget.isPassword,
      style: widget.style ?? const TextStyle(fontSize: 14),
      onEditingComplete: widget.textInputAction == TextInputAction.next
          ? () => FocusScope.of(context).nextFocus()
          : null,
      decoration: InputDecoration(
        hintText: widget.hint,
        helperText: compact ? null : widget.helperText,
        isDense: compact,
        constraints: compact ? const BoxConstraints(minHeight: 56) : null,
        helperMaxLines: 2,
        errorMaxLines: 3,
        helperStyle: TextStyle(
            fontSize: 10, color: appPalette(context).onSurfaceVariant),
        prefixIcon:
            Icon(widget.icon, color: appPalette(context).primary, size: 21),
        suffixIcon: widget.isPassword
            ? IconButton(
                tooltip: _obscured
                    ? appL10n(context).msgShowPassword138
                    : appL10n(context).msgHidePassword139,
                onPressed: widget.enabled
                    ? () => setState(() => _obscured = !_obscured)
                    : null,
                icon: Icon(
                    _obscured
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 21))
            : null,
        hintStyle: TextStyle(fontSize: 13, color: appPalette(context).outline),
        counterText: '',
        filled: true,
        fillColor: appPalette(context).surfaceContainer.withValues(alpha: .95),
        contentPadding:
            EdgeInsets.symmetric(horizontal: 16, vertical: compact ? 16 : 19),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: BorderSide(
                color: adaptiveSurface(context, const Color(0xFFE1EBE4)))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: BorderSide(
                color: adaptiveSurface(context, const Color(0xFFE1EBE4)))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide:
                BorderSide(color: appPalette(context).primary, width: 1.5)),
      ),
    );
    if (!compact || widget.helperText == null) return field;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      field,
      Padding(
          padding: const EdgeInsets.only(left: 14, top: 6),
          child: Text(widget.helperText!,
              style: TextStyle(
                  fontSize: 10,
                  height: 1.3,
                  color: appPalette(context).onSurfaceVariant))),
    ]);
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
    if (_AuthStyle.isCompact(context)) {
      return DecoratedBox(
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                  colors: const [Color(0xFF007A58), Color(0xFF009D75)]),
              boxShadow: [
                BoxShadow(
                    color: appPalette(context).primary.withValues(alpha: .14),
                    blurRadius: 12,
                    offset: const Offset(0, 4))
              ]),
          child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                  onPressed: isLoading ? null : onPressed,
                  style: FilledButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFADCABC),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22))),
                  child: isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: const CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                              Flexible(
                                  child: Text(label,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700))),
                              if (icon != null) ...[
                                const SizedBox(width: 7),
                                Icon(icon, size: 19)
                              ],
                            ]))));
    }
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: appPalette(context).primary,
          foregroundColor: appPalette(context).onPrimary,
          disabledBackgroundColor: appPalette(context).primary.withOpacity(0.6),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 3,
          shadowColor: appPalette(context).primary.withOpacity(0.3),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: const CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
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
  const AuthScaffold(
      {super.key,
      required this.children,
      this.onBack,
      this.showBack = true,
      this.busy = false,
      this.layout = AuthLayout.secondary});
  final List<Widget> children;
  final VoidCallback? onBack;
  final bool showBack;
  final bool busy;
  final AuthLayout layout;

  @override
  Widget build(BuildContext context) {
    final compact = layout != AuthLayout.secondary;
    final back = IconButton(
        tooltip: appL10n(context).msgBack140,
        onPressed: busy ? null : onBack ?? () => Navigator.maybePop(context),
        icon: const Icon(Icons.arrow_back_rounded));
    return _AuthStyle(
        compact: compact,
        child: PopScope(
            canPop: !busy,
            child: Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              body: Stack(children: [
                Positioned.fill(
                    child: IgnorePointer(
                        child: ExcludeSemantics(
                            child: CustomPaint(
                                painter: _AuthLeaves(
                                    dark: Theme.of(context).brightness ==
                                        Brightness.dark))))),
                SafeArea(
                  child: LayoutBuilder(
                      builder: (context, bounds) => SingleChildScrollView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: EdgeInsets.fromLTRB(
                              24, compact ? 16 : 12, 24, compact ? 16 : 24),
                          child: Center(
                              child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                      maxWidth: compact ? 440 : 460),
                                  child: Stack(children: [
                                    Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          if (showBack && !compact)
                                            Align(
                                                alignment: Alignment.centerLeft,
                                                child: back),
                                          ...children,
                                        ]),
                                    const Positioned(
                                        right: 0,
                                        top: 0,
                                        child: const AppearanceButton()),
                                    if (showBack && compact)
                                      Positioned(left: 0, top: 0, child: back),
                                  ]))))),
                ),
              ]),
            )));
  }
}

class AuthDivider extends StatelessWidget {
  const AuthDivider(this.label, {super.key});
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
      padding: EdgeInsets.symmetric(
          vertical: _AuthStyle.isCompact(context) ? 12 : 20),
      child: Row(children: [
        const Expanded(child: const Divider()),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: appPalette(context).onSurfaceVariant))),
        const Expanded(child: const Divider()),
      ]));
}

class GoogleAuthButton extends StatelessWidget {
  const GoogleAuthButton(
      {super.key,
      required this.onPressed,
      this.register = false,
      this.busy = false});
  final VoidCallback onPressed;
  final bool register;
  final bool busy;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        OutlinedButton(
            onPressed: busy
                ? null
                : Env.isGoogleConfigured
                    ? onPressed
                    : () => showAuthMessage(context,
                        appL10n(context).msgGoogleSignInIsNotConfigured141),
            style: OutlinedButton.styleFrom(
                backgroundColor: appPalette(context).surfaceContainer,
                foregroundColor: appPalette(context).onSurface,
                minimumSize: const Size(double.infinity, 56),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                side: BorderSide(
                    color: adaptiveSurface(context, const Color(0xFFE5EDE7))),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22))),
            child: Row(children: [
              Image.asset('assets/images/google-g.png',
                  width: 24, height: 24, excludeFromSemantics: true),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(
                      register
                          ? appL10n(context).msgRegisterWithGoogle142
                          : appL10n(context).msgContinueWithGoogle143,
                      textAlign: TextAlign.center,
                      maxLines: MediaQuery.textScalerOf(context).scale(1) <= 1.2
                          ? 1
                          : null,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700))),
              const SizedBox(width: 12),
              const Icon(Icons.chevron_right_rounded, size: 21)
            ])),
        if (!Env.isGoogleConfigured)
          Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(appL10n(context).msgGoogleNotConfigured144,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 10,
                      height: 1.3,
                      color: appPalette(context).outline))),
      ]);
}

class _AuthLeaves extends CustomPainter {
  const _AuthLeaves({this.dark = false});
  final bool dark;
  @override
  void paint(Canvas canvas, Size size) {
    if (dark) {
      canvas.drawRect(
          Offset.zero & size, Paint()..color = const Color(0xFF0C211A));
      return;
    }
    final rect = Offset.zero & size;
    canvas.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: const [
                Color(0xFFF8FCF7),
                Color(0xFFF1F8EF),
                Color(0xFFF8FCF5)
              ]).createShader(rect));
    void leaf(Path path, Rect area, List<Color> colors) {
      canvas.drawPath(
          path,
          Paint()
            ..shader = LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: colors)
                .createShader(area));
    }

    final left = Path()
      ..moveTo(-18, size.height * .26)
      ..cubicTo(
          118, size.height * .17, 49, size.height * .07, 0, size.height * .14)
      ..lineTo(-18, size.height * .26);
    leaf(left, Rect.fromLTWH(0, size.height * .1, 100, 180),
        [const Color(0xFFDCF5E3), const Color(0xFFBDE8CD)]);
    final leftFold = Path()
      ..moveTo(0, size.height * .25)
      ..lineTo(30, size.height * .18)
      ..lineTo(30, size.height * .23)
      ..close();
    canvas.drawPath(leftFold,
        Paint()..color = const Color(0xFFA7DDBE).withValues(alpha: .5));
    final right = Path()
      ..moveTo(size.width, size.height * .17)
      ..cubicTo(size.width - 112, size.height * .21, size.width - 40,
          size.height * .37, size.width, size.height * .42)
      ..close();
    leaf(right, Rect.fromLTWH(size.width - 95, size.height * .17, 95, 240),
        [const Color(0xFFE3F6E7), const Color(0xFFCAEBD5)]);
    final fold = Path()
      ..moveTo(size.width, size.height * .28)
      ..quadraticBezierTo(
          size.width - 56, size.height * .35, size.width, size.height * .42)
      ..close();
    canvas.drawPath(
        fold, Paint()..color = const Color(0xFFB4E0C4).withValues(alpha: .45));
    canvas.drawOval(Rect.fromLTWH(-50, size.height - 45, 120, 150),
        Paint()..color = const Color(0xFFDDF3E3).withValues(alpha: .65));
    canvas.drawOval(Rect.fromLTWH(size.width - 55, size.height - 35, 130, 140),
        Paint()..color = const Color(0xFFDDF3E3).withValues(alpha: .65));
  }

  @override
  bool shouldRepaint(_AuthLeaves oldDelegate) => dark != oldDelegate.dark;
}

/// All artwork (including leaves and shadow) is contained inside this frame.
class AuthHeroIllustration extends StatelessWidget {
  const AuthHeroIllustration({super.key});
  static const asset = 'assets/images/auth-wallet-3d.png';
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
      child: SizedBox(
          key: const ValueKey('auth-hero-frame'),
          height: 132,
          width: double.infinity,
          child: Image.asset(asset,
              fit: BoxFit.contain,
              alignment: Alignment.bottomCenter,
              filterQuality: FilterQuality.medium)));
}
