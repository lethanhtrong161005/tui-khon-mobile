import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tui_khon_mobile/core/utils/vnd_amount_input.dart';
import 'package:tui_khon_mobile/core/utils/currency_formatter.dart';
import 'package:tui_khon_mobile/core/widgets/form_sheet.dart';
import 'package:tui_khon_mobile/l10n/app_l10n.dart';

TextEditingValue input(String text, [int? offset]) => TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: offset ?? text.length));

void main() {
  test(
      'negative balances retain their minus without requesting a positive plus',
      () {
    for (final locale in ['vi', 'en']) {
      expect(CurrencyFormatter.formatVND(-1234567, locale: locale),
          startsWith('-'));
      expect(
          CurrencyFormatter.formatVND(-1234567, locale: locale, showSign: true),
          startsWith('-'));
      expect(CurrencyFormatter.formatVND(1234567, locale: locale),
          isNot(startsWith('+')));
      expect(
          CurrencyFormatter.formatVND(1234567, locale: locale, showSign: true),
          startsWith('+'));
    }
  });
  test('whole VND groups in both locales and round-trips exactly', () {
    for (final (locale, expected) in [
      ('vi', '1.234.567'),
      ('en', '1,234,567')
    ]) {
      final formatted = VndAmountInputFormatter(locale)
          .formatEditUpdate(input(''), input('1234567'));
      expect(formatted.text, expected);
      expect(formatted.selection.extentOffset, expected.length);
      expect(parseVndInput(formatted.text), 1234567);
    }
    expect(parseVndInput('9.999.999.999.999'), 9999999999999);
    expect(parseVndInput('-1.000'), -1000);
    for (final invalid in [
      '65,5',
      '1.234,56',
      '1e6',
      '65k',
      '12.34',
      '1,23,456'
    ]) {
      expect(parseVndInput(invalid), 0);
    }
  });

  test(
      'typing digit by digit, mid-string edits and selection replacements keep cursor',
      () {
    final formatter = VndAmountInputFormatter('vi');
    var value = input('');
    for (final digit in '1234567'.split('')) {
      value = formatter.formatEditUpdate(value, input(value.text + digit));
    }
    expect(value.text, '1.234.567');
    final edited = formatter.formatEditUpdate(value, input('1.2934.567', 4));
    expect(edited.text, '12.934.567');
    expect(edited.selection.extentOffset, 4);
    final replaced = formatter.formatEditUpdate(value, input('1.200.567', 5));
    expect(replaced.text, '1.200.567');
    expect(parseVndInput(replaced.text), 1200567);
  });

  test(
      'formatted pastes normalize; decimals, signs and excess digits are rejected',
      () {
    final formatter = VndAmountInputFormatter('vi');
    expect(
        formatter.formatEditUpdate(input(''), input('65,000')).text, '65.000');
    expect(formatter.formatEditUpdate(input(''), input('65\u00a0000')).text,
        '65.000');
    final old = input('1.000');
    for (final invalid in [
      '65,5',
      '1.234,56',
      '-100',
      '1e6',
      '65k',
      '12345678901234'
    ]) {
      expect(formatter.formatEditUpdate(old, input(invalid)), old);
    }
    expect(formatter.formatEditUpdate(old, input('')).text, '');
    expect(formatter.formatEditUpdate(input('0'), input('00012')).text, '12');
  });

  testWidgets(
      'MoneyField formats initial values, changes locale and keeps integer value',
      (t) async {
    final controller = TextEditingController(text: '1234567');
    addTearDown(controller.dispose);
    Future<void> pump(String locale) => t.pumpWidget(MaterialApp(
          locale: Locale(locale),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home:
              Scaffold(body: MoneyField(controller: controller, label: 'VND')),
        ));
    await pump('vi');
    await t.pumpAndSettle();
    expect(controller.text, '1.234.567');
    await t.enterText(find.byType(TextField), '65000');
    await t.pump();
    expect(controller.text, '65.000');
    expect(MoneyField.valueOf(controller), 65000);
    await pump('en');
    await t.pumpAndSettle();
    expect(controller.text, '65,000');
    expect(MoneyField.valueOf(controller), 65000);
  });
}
