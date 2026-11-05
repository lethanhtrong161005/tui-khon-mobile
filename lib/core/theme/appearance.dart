import '../../l10n/app_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Appearance {
  const Appearance({this.theme = ThemeMode.system, this.language = 'vi'});
  final ThemeMode theme;
  final String language;
}

class AppearanceController extends StateNotifier<Appearance> {
  AppearanceController(this.prefs)
      : super(Appearance(
            theme: ThemeMode.values
                    .where(
                        (v) => v.name == prefs?.getString('appearance_theme'))
                    .firstOrNull ??
                ThemeMode.system,
            language: ['vi', 'en', 'system']
                    .contains(prefs?.getString('appearance_language'))
                ? prefs?.getString('appearance_language') ?? 'vi'
                : 'vi'));
  final SharedPreferences? prefs;
  Future<void> _writes = Future.value();
  Future<void> change({ThemeMode? theme, String? language}) {
    final next = _writes.then((_) => _apply(theme: theme, language: language));
    _writes = next.catchError((Object _) {});
    return next;
  }

  Future<void> _apply({ThemeMode? theme, String? language}) async {
    if (language != null && !['vi', 'en', 'system'].contains(language)) {
      throw ArgumentError.value(language, 'language');
    }
    final previousTheme = prefs?.getString('appearance_theme');
    final previousLanguage = prefs?.getString('appearance_language');
    try {
      if (prefs != null) {
        if (theme != null &&
            !await prefs!.setString('appearance_theme', theme.name)) {
          throw StateError('Cannot save appearance');
        }
        if (language != null &&
            !await prefs!.setString('appearance_language', language)) {
          throw StateError('Cannot save language');
        }
      }
    } catch (_) {
      // SharedPreferences updates its in-memory cache even when persistence fails.
      // Restore both keys before surfacing the failure; the UI retains its state.
      if (prefs != null) {
        for (final entry in {
          'appearance_theme': previousTheme,
          'appearance_language': previousLanguage
        }.entries) {
          try {
            if (entry.value == null) {
              await prefs!.remove(entry.key);
            } else {
              await prefs!.setString(entry.key, entry.value!);
            }
          } catch (_) {/* Retain the original persistence error. */}
        }
      }
      rethrow;
    }
    state = Appearance(
        theme: theme ?? state.theme, language: language ?? state.language);
  }
}

final appearancePreferencesProvider =
    Provider<SharedPreferences?>((ref) => null);
final appearanceProvider =
    StateNotifierProvider<AppearanceController, Appearance>((ref) =>
        AppearanceController(ref.watch(appearancePreferencesProvider)));

Locale resolveAppearanceLocale(String language, Locale system) {
  if (language == 'system')
    return Locale(system.languageCode == 'en' ? 'en' : 'vi');
  return Locale(language == 'en' ? 'en' : 'vi');
}

Future<void> showAppearanceChoice(BuildContext context, WidgetRef ref,
    {bool language = false}) async {
  final strings = appL10n(context);
  final current = ref.read(appearanceProvider);
  final result = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => SafeArea(
          child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * .85),
              child: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                        language ? strings.chooseLanguage : strings.chooseTheme,
                        style: Theme.of(context).textTheme.titleLarge)),
                for (final item in language
                    ? [
                        ('vi', 'Tiếng Việt'),
                        ('en', 'English'),
                        ('system', strings.system)
                      ]
                    : [
                        ('system', strings.system),
                        ('light', strings.light),
                        ('dark', strings.dark)
                      ])
                  ListTile(
                      title: Text(item.$2),
                      trailing:
                          (language ? current.language : current.theme.name) ==
                                  item.$1
                              ? const Icon(Icons.check)
                              : null,
                      onTap: () => Navigator.pop(context, item.$1)),
                const SizedBox(height: 12),
              ])))));
  if (result == null) return;
  try {
    await ref.read(appearanceProvider.notifier).change(
        theme: language
            ? null
            : ThemeMode.values.firstWhere((v) => v.name == result),
        language: language ? result : null);
  } catch (_) {
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(appL10n(context).savePreferencesError)));
  }
}

class AppearanceButton extends ConsumerWidget {
  const AppearanceButton({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
            tooltip: appL10n(context).appearance,
            icon: const Icon(Icons.brightness_6_outlined),
            onPressed: () => showAppearanceChoice(context, ref)),
        IconButton(
            tooltip: appL10n(context).language,
            icon: const Icon(Icons.translate),
            onPressed: () =>
                showAppearanceChoice(context, ref, language: true)),
      ]);
}

class DeviceLocaleController extends StateNotifier<Locale>
    with WidgetsBindingObserver {
  DeviceLocaleController()
      : super(WidgetsBinding.instance.platformDispatcher.locale) {
    WidgetsBinding.instance.addObserver(this);
  }
  @override
  void didChangeLocales(List<Locale>? locales) {
    state = locales?.firstOrNull ?? const Locale('vi');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

final deviceLocaleProvider =
    StateNotifierProvider<DeviceLocaleController, Locale>(
        (ref) => DeviceLocaleController());
final effectiveLocaleProvider = Provider<Locale>((ref) =>
    resolveAppearanceLocale(ref.watch(appearanceProvider).language,
        ref.watch(deviceLocaleProvider)));
