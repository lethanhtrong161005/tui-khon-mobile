import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Presentation-only semantic palette. Never used to rewrite category colors.
ColorScheme appPalette(BuildContext? context) => context == null
    ? AppTheme.light.colorScheme
    : Theme.of(context).colorScheme;

Color adaptiveSurface(BuildContext context, Color light) =>
    Theme.of(context).brightness == Brightness.dark
        ? Theme.of(context).colorScheme.surfaceContainerLow
        : light;
