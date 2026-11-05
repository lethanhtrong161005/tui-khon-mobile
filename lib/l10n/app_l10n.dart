import 'package:flutter/material.dart';
import 'generated/app_localizations.dart';
export 'generated/app_localizations.dart';

AppLocalizations appL10n(BuildContext? context) =>
    (context == null
        ? null
        : Localizations.of<AppLocalizations>(context, AppLocalizations)) ??
    lookupAppLocalizations(const Locale('vi'));
