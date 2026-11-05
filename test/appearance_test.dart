import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tui_khon_mobile/core/theme/appearance.dart';
import 'package:tui_khon_mobile/l10n/generated/app_localizations.dart';

void main() {
  test('defaults and unsupported locale fallback', () {
    final controller = AppearanceController(null);
    expect(controller.state.theme, ThemeMode.system);
    expect(controller.state.language, 'vi');
    expect(resolveAppearanceLocale('system', const Locale('fr')),
        const Locale('vi'));
    expect(resolveAppearanceLocale('system', const Locale('en', 'GB')),
        const Locale('en'));
    controller.dispose();
  });
  test('theme and language survive controller recreation independently',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final controller = AppearanceController(prefs);
    await controller.change(theme: ThemeMode.dark);
    await controller.change(language: 'en');
    final restored = AppearanceController(prefs);
    expect(restored.state.theme, ThemeMode.dark);
    expect(restored.state.language, 'en');
    controller.dispose();
    restored.dispose();
  });
  test('invalid saved preferences fall back without changing financial data',
      () async {
    SharedPreferences.setMockInitialValues({
      'appearance_theme': 'bad',
      'appearance_language': 'bad',
      'offline_account_id': 'keep'
    });
    final prefs = await SharedPreferences.getInstance();
    final controller = AppearanceController(prefs);
    expect(controller.state.theme, ThemeMode.system);
    expect(controller.state.language, 'vi');
    expect(prefs.getString('offline_account_id'), 'keep');
    controller.dispose();
  });
  test('Vietnamese and English catalogs expose localized display controls', () {
    final vi = lookupAppLocalizations(const Locale('vi'));
    final en = lookupAppLocalizations(const Locale('en'));
    expect(vi.appearance, 'Giao diện');
    expect(en.appearance, 'Appearance');
    expect(vi.language, 'Ngôn ngữ');
    expect(en.language, 'Language');
    expect(en.pendingSignOut(3), contains('3'));
  });
}
