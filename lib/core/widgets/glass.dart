import 'dart:ui';

import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Bounded backdrop blur, a tinted surface and a bright rim. Blur is reserved
/// for floating controls; ordinary list cards use the cheaper unblurred mode.
class GlassCard extends StatelessWidget {
  const GlassCard(
      {super.key,
      required this.child,
      this.padding = EdgeInsets.zero,
      this.radius = 24,
      this.blur = false,
      this.tint = Colors.white});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool blur;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final opaque = MediaQuery.of(context).highContrast;
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              tint.withValues(alpha: opaque ? 1 : .88),
              tint.withValues(alpha: opaque ? 1 : .66)
            ]),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: .85)),
      ),
      child: Material(
          type: MaterialType.transparency,
          child: Padding(padding: padding, child: child)),
    );
    return Container(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
                color: AppColors.primary.withValues(alpha: .045),
                blurRadius: 24,
                offset: const Offset(0, 8))
          ]),
      child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: blur && !opaque
              ? BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: surface)
              : surface),
    );
  }
}

class NotebookBackground extends StatelessWidget {
  const NotebookBackground({super.key, required this.child, this.ai = false});
  final Widget child;
  final bool ai;
  @override
  Widget build(BuildContext context) => DecoratedBox(
      decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: ai
                  ? const [
                      Color(0xFFF1F0FF),
                      Color(0xFFFCFCFF),
                      Color(0xFFF0F6F3)
                    ]
                  : const [
                      Color(0xFFE5F5E9),
                      Color(0xFFFAFBF6),
                      Color(0xFFEDF6ED)
                    ],
              stops: const [0, .45, 1])),
      child: child);
}

class TintedIcon extends StatelessWidget {
  const TintedIcon(this.icon,
      {super.key, this.color = AppColors.primary, this.size = 44});
  final IconData icon;
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          color: color.withValues(alpha: .11),
          borderRadius: BorderRadius.circular(size * .36)),
      child: Icon(icon, color: color, size: size * .49));
}

class EmeraldButton extends StatelessWidget {
  const EmeraldButton(
      {super.key, required this.label, required this.onPressed, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => DecoratedBox(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
              colors: [Color(0xFF006D50), Color(0xFF00A878)]),
          boxShadow: [
            BoxShadow(
                color: AppColors.primary.withValues(alpha: .18),
                blurRadius: 16,
                offset: const Offset(0, 6))
          ]),
      child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
              backgroundColor: Colors.transparent,
              disabledBackgroundColor: const Color(0xFFB2C5BA),
              minimumSize: const Size(0, 52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) ...[
              Icon(icon, size: 19),
              const SizedBox(width: 8)
            ],
            Flexible(
                child: Text(label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700))),
          ])));
}
