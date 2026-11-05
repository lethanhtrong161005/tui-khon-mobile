import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/app_lock_screen.dart';
import '../../l10n/app_l10n.dart';
import '../services/app_lock_service.dart';
import '../supabase/supabase_providers.dart';
import '../theme/appearance.dart';
import 'home_widget_controller.dart';

/// Lives above the Navigator, including forms already open when the app locks.
class HomeWidgetHost extends ConsumerStatefulWidget {
  const HomeWidgetHost(
      {super.key, required this.child, this.configured = true});
  final Widget child;
  final bool configured;
  @override
  ConsumerState<HomeWidgetHost> createState() => _HomeWidgetHostState();
}

class _HomeWidgetHostState extends ConsumerState<HomeWidgetHost>
    with WidgetsBindingObserver {
  Map<String, String>? _lastAppearance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Read lifecycle after all resume observers (including AuthGate) ran.
    scheduleMicrotask(_foreground);
  }

  void _foreground() {
    if (!mounted) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    ref.read(homeWidgetForegroundProvider.notifier).state =
        lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    scheduleMicrotask(_foreground);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(homeWidgetStartupProvider);
    final appearance = ref.watch(appearanceProvider);
    final strings = appL10n(context);
    final values = <String, String>{
      'theme': appearance.theme.name,
      'language': appearance.language,
      'effectiveLanguage': ref.watch(effectiveLocaleProvider).languageCode,
      'title': strings.homeWidgetTitle,
      'expense': strings.homeWidgetExpense,
      'income': strings.homeWidgetIncome,
      'quickRecord': strings.homeWidgetQuickRecord,
      'scanReceipt': strings.homeWidgetScanReceipt,
      for (final locale in const [Locale('vi'), Locale('en')])
        ..._labels(locale.languageCode, lookupAppLocalizations(locale)),
    };
    if (_lastAppearance == null ||
        values.entries.any((e) => _lastAppearance![e.key] != e.value)) {
      _lastAppearance = values;
      unawaited(ref.read(homeWidgetBridgeProvider).updateAppearance(values));
    }

    if (!widget.configured) return widget.child;
    ref.listen<String?>(currentUserIdProvider, (previous, next) {
      // An initially signed-out launch can continue after login. An explicit
      // account departure must never carry its queued action to another user.
      if (previous != null && previous != next) {
        ref.read(homeWidgetControllerProvider.notifier).clear();
        unawaited(ref.read(homeWidgetBridgeProvider).clearPendingAction());
      }
    });
    final user = ref.watch(currentUserIdProvider);
    final lock = ref.watch(appLockEnabledProvider);
    final unlocked = ref.watch(appUnlockedProvider);
    final hasOverlays = ref.watch(appNavigationObserverProvider).hasOverlays;
    final shield = user != null &&
        hasOverlays &&
        (lock.isLoading ||
            lock.hasError ||
            (lock.valueOrNull == true && !unlocked));
    return Stack(fit: StackFit.expand, children: [
      // Keep the Navigator mounted so drafts/controllers survive relocking.
      ExcludeSemantics(
          excluding: shield,
          child: IgnorePointer(ignoring: shield, child: widget.child)),
      if (shield)
        if (lock.isLoading || lock.hasError)
          const ColoredBox(
              color: Colors.black,
              child: Center(child: CircularProgressIndicator()))
        else
          const AppLockScreen(),
    ]);
  }

  Map<String, String> _labels(String language, AppLocalizations strings) => {
        '${language}_title': strings.homeWidgetTitle,
        '${language}_expense': strings.homeWidgetExpense,
        '${language}_income': strings.homeWidgetIncome,
        '${language}_quickRecord': strings.homeWidgetQuickRecord,
        '${language}_scanReceipt': strings.homeWidgetScanReceipt,
      };
}
