import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tui_khon_mobile/core/offline/local_store.dart';
import 'package:tui_khon_mobile/core/services/voice_input_service.dart';
import 'package:tui_khon_mobile/core/supabase/supabase_providers.dart';
import 'package:tui_khon_mobile/core/theme/app_theme.dart';
import 'package:tui_khon_mobile/features/auth/providers/auth_providers.dart';
import 'package:tui_khon_mobile/features/finance_query/data/finance_query_repository.dart';
import 'package:tui_khon_mobile/features/home/presentation/widgets/notebook_navigation.dart';
import 'package:tui_khon_mobile/features/quick_record/data/quick_record_repository.dart';
import 'package:tui_khon_mobile/features/quick_record/presentation/quick_record_screen.dart';
import 'package:tui_khon_mobile/features/receipt/presentation/receipt_picker.dart';
import 'package:tui_khon_mobile/l10n/app_l10n.dart';

import 'fakes.dart';

void main() {
  for (final dark in [false, true]) {
    for (final locale in ['vi', 'en']) {
      testWidgets(
        'source sheet has opaque surface and safe bottom, $dark $locale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          tester.view.padding = const FakeViewPadding(top: 28, bottom: 48);
          tester.view.viewPadding = const FakeViewPadding(top: 28, bottom: 48);
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? AppTheme.dark : AppTheme.light,
              locale: Locale(locale),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(2)),
                child: child!,
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => unawaited(pickReceiptImage(context)),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          final l = appL10n(tester.element(find.byType(BottomSheet)));
          await tester.ensureVisible(find.text(l.msgChoosePhotoFromLibrary393));
          expect(
            tester.getBottomLeft(find.text(l.msgChoosePhotoFromLibrary393)).dy,
            lessThanOrEqualTo(520),
          );
          expect(
            tester
                .widget<BottomSheet>(find.byType(BottomSheet))
                .backgroundColor!
                .a,
            1,
          );
          expect(tester.takeException(), isNull);
          Navigator.of(tester.element(find.byType(BottomSheet))).pop();
          await tester.pumpAndSettle();
        },
      );
    }
  }
  testWidgets(
    'action menu last row stays above three-button navigation with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 28, bottom: 48);
      tester.view.viewPadding = const FakeViewPadding(top: 28, bottom: 48);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => unawaited(showNotebookActions(context)),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final last = find.text('Nhắc ghi chép');
      await tester.ensureVisible(last);
      await tester.pumpAndSettle();
      expect(tester.getBottomLeft(last).dy, lessThanOrEqualTo(520));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'query mode reads local data, preserves histories and never writes a transaction',
    (tester) async {
      final store = LocalStore.memory('qa');
      addTearDown(store.close);
      await store.put('wallets', {
        'id': 'cash',
        'name': 'Tiền mặt',
        'initial_balance': 123456,
      });
      final before = await store.pendingCount();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStoreProvider.overrideWithValue(store),
            currentUserIdProvider.overrideWithValue('qa'),
            profileProvider.overrideWith((ref) async => null),
            voiceInputProvider.overrideWithValue(
              FakeVoiceInput('Số dư tiền mặt'),
            ),
            quickRecordRepositoryProvider.overrideWithValue(
              FakeQuickRecordRepository(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const QuickRecordScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hỏi chi tiêu'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Số dư tiền mặt');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();
      expect(find.text('Số dư đã ghi chép'), findsOneWidget);
      expect(find.textContaining('123.456'), findsNWidgets(2));
      await tester.tap(find.text('Ghi giao dịch'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hỏi chi tiêu'));
      await tester.pumpAndSettle();
      expect(find.textContaining('123.456'), findsNWidgets(2));
      expect(await store.rows('transactions'), isEmpty);
      expect(await store.pendingCount(), before);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'changing account clears query history and discards pending old-account results',
    (tester) async {
      final a = LocalStore.memory('qa-a'), b = LocalStore.memory('qa-b');
      addTearDown(a.close);
      addTearDown(b.close);
      await a.put('wallets', {
        'id': 'cash-a',
        'name': 'Tiền mặt',
        'initial_balance': 314159,
      });
      await b.put('wallets', {
        'id': 'cash-b',
        'name': 'Tiền mặt',
        'initial_balance': 271828,
      });
      final account = StateProvider<String>((ref) => 'qa-a');
      final pending = Completer<Map<String, dynamic>>();
      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => ref.watch(account)),
          localStoreProvider.overrideWith(
            (ref) => ref.watch(account) == 'qa-a' ? a : b,
          ),
          financeQueryRepositoryProvider.overrideWith(
            (ref) => FinanceQueryRepository(
              ref.watch(localStoreProvider)!,
              request: (_) => pending.future,
            ),
          ),
          profileProvider.overrideWith((ref) async => null),
          voiceInputProvider.overrideWithValue(
            FakeVoiceInput('Số dư tiền mặt'),
          ),
          quickRecordRepositoryProvider.overrideWithValue(
            FakeQuickRecordRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            home: const QuickRecordScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hỏi chi tiêu'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Số dư tiền mặt');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();
      expect(find.textContaining('314.159'), findsNWidgets(2));
      await tester.enterText(
        find.byType(TextField),
        'Phân tích theo cách khác',
      );
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();
      container.read(account.notifier).state = 'qa-b';
      await tester.pumpAndSettle();
      pending.complete({
        'plan': {'kind': 'summary', 'from': '2026-11-01', 'to': '2026-12-01'},
      });
      await tester.pumpAndSettle();
      expect(find.textContaining('314.159'), findsNothing);
      expect(find.text('Phân tích theo cách khác'), findsNothing);
      expect(await b.rows('transactions'), isEmpty);
      await tester.enterText(find.byType(TextField), 'Số dư tiền mặt');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();
      expect(find.textContaining('271.828'), findsNWidgets(2));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
