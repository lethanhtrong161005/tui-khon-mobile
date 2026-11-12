import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tui_khon_mobile/features/receipt/data/receipt_image.dart';
import 'package:tui_khon_mobile/features/receipt/data/receipt_ocr_service.dart';
import 'package:tui_khon_mobile/features/receipt/data/receipt_parser.dart';
import 'package:tui_khon_mobile/features/home/models/category_model.dart';
import 'package:tui_khon_mobile/features/home/models/wallet_model.dart';
import 'package:tui_khon_mobile/features/home/models/transaction_model.dart';
import 'package:tui_khon_mobile/core/offline/local_store.dart';
import 'package:tui_khon_mobile/core/supabase/supabase_providers.dart';
import 'package:tui_khon_mobile/core/services/voice_input_service.dart';
import 'package:tui_khon_mobile/core/theme/app_theme.dart';
import 'package:tui_khon_mobile/features/auth/providers/auth_providers.dart';
import 'package:tui_khon_mobile/features/home/presentation/widgets/notebook_navigation.dart';
import 'package:tui_khon_mobile/features/quick_record/data/quick_record_repository.dart';
import 'package:tui_khon_mobile/features/quick_record/presentation/quick_record_screen.dart';
import 'package:tui_khon_mobile/l10n/app_l10n.dart';

import '../test/fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('synthetic receipt exercises native OCR without cloud', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Native OCR QA'))),
    );
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(Colors.white, BlendMode.src);
    const lines = [
      'Saigon Co.op',
      'Co.opFood D512 Truong Tho',
      'PHIEU TINH TIEN',
      '01/11/2026 18:55',
      'Banh mi 7,600.00',
      'Tong tien 62,700.00',
      'Tong so luong hang 6.000',
      'Tien khach tra 62,700.00',
      'Tien tra lai 0.00',
      'Tong tien giam gia 1,100.00',
      'VAT 8% 2,074.07',
      'VAT 10% 3,154.55',
      'VIETCOMBANK 62,700.00',
    ];
    for (var i = 0; i < lines.length; i++) {
      final paragraph =
          (ui.ParagraphBuilder(
                  ui.ParagraphStyle(fontFamily: 'monospace', fontSize: 44),
                )
                ..pushStyle(ui.TextStyle(color: Colors.black))
                ..addText(lines[i]))
              .build()
            ..layout(const ui.ParagraphConstraints(width: 1300));
      canvas.drawParagraph(paragraph, Offset(60, 60 + i * 85));
    }
    final image = await recorder.endRecording().toImage(1400, 1300);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
    image.dispose();
    final receipt = await normalizeReceiptImage(bytes);
    final ocr = await NativeReceiptOcrService().recognize(receipt.bytes);
    final qaDirectory = await getApplicationSupportDirectory();
    await File('${qaDirectory.path}/receipt-qa-synthetic-ocr.txt')
        .writeAsString(ocr.text);
    await File('${qaDirectory.path}/receipt-qa-synthetic.png')
        .writeAsBytes(receipt.bytes);
    final result = ReceiptParser().parse(
      ocr,
      categories: [
        const CategoryModel(
          id: 'food',
          name: 'Ăn uống',
          type: TransactionType.expense,
        ),
      ],
      wallets: [
        const WalletModel(id: 'vcb', name: 'Vietcombank', type: 'bank'),
      ],
      receiptPath: 'qa/image.jpg',
    );
    expect(result.draft!.amount, 62700);
    expect(result.draft!.occurredAt, DateTime.utc(2026, 11, 1, 11, 55));
    expect(result.draft!.walletId, 'vcb');
    expect(result.draft!.merchant, isNotNull);
  });
  testWidgets(
    'native safe areas, source picker and local query with 200 percent text',
    (tester) async {
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
                onPressed: () => showNotebookActions(context),
                child: const Text('Open QA menu'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open QA menu'));
      await tester.pumpAndSettle();
      final menuContext = tester.element(find.byType(BottomSheet));
      final media = MediaQuery.of(menuContext);
      final last = find.text(appL10n(menuContext).msgRecordingReminder196);
      await tester.ensureVisible(last);
      await tester.pumpAndSettle();
      expect(
        tester.getBottomLeft(last).dy,
        lessThanOrEqualTo(media.size.height - media.viewPadding.bottom),
      );
      await tester.tap(find.byTooltip(appL10n(menuContext).closeMenu));
      await tester.pumpAndSettle();
      final store = LocalStore.memory('native-ui-qa');
      addTearDown(store.close);
      await store.put('wallets', {
        'id': 'qa-cash',
        'name': 'Tiền mặt',
        'initial_balance': 123456,
      });
      final before = await store.pendingCount();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStoreProvider.overrideWithValue(store),
            currentUserIdProvider.overrideWithValue('native-ui-qa'),
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
      final l = appL10n(tester.element(find.byType(QuickRecordScreen)));
      await tester.tap(find.byTooltip(l.msgScanReceipt192));
      await tester.pumpAndSettle();
      final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
      expect(sheet.backgroundColor!.a, 1);
      final sheetMedia = MediaQuery.of(
        tester.element(find.byType(BottomSheet)),
      );
      expect(
        tester.getBottomLeft(find.text(l.msgChoosePhotoFromLibrary393)).dy,
        lessThanOrEqualTo(
          sheetMedia.size.height - sheetMedia.viewPadding.bottom,
        ),
      );
      Navigator.of(tester.element(find.byType(BottomSheet))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.financeQueryMode));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Số dư tiền mặt');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(l.msgSendRecord391));
      await tester.pumpAndSettle();
      expect(find.textContaining('123.456'), findsNWidgets(2));
      expect(await store.rows('transactions'), isEmpty);
      expect(await store.pendingCount(), before);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'real provided receipt through native Latin OCR, without cloud or financial writes',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Receipt OCR QA'))),
      );
      final file = File(
        '${(await getApplicationSupportDirectory()).path}/receipt-qa.jpg',
      );
      expect(
        await file.exists(),
        true,
        reason: 'Install the isolated QA image in application support first; see docs/OCR_QA.md.',
      );
      final receipt = await normalizeReceiptImage(await file.readAsBytes());
      final ocr = await NativeReceiptOcrService().recognize(receipt.bytes);
      final result = ReceiptParser().parse(
        ocr,
        categories: [
          const CategoryModel(
            id: 'food',
            name: 'Ăn uống',
            type: TransactionType.expense,
          ),
        ],
        wallets: [
          const WalletModel(id: 'vcb', name: 'Vietcombank', type: 'bank'),
        ],
        receiptPath: 'qa/image.jpg',
      );
      // Private evidence only, not committed and not sent to Gemini.
      await File(
        '${(await getApplicationSupportDirectory()).path}/receipt-qa-ocr.txt',
      ).writeAsString(ocr.text);
      expect(result.draft!.amount, 62700);
      expect(result.draft!.occurredAt, DateTime.utc(2026, 11, 1, 11, 55));
      expect(result.draft!.walletId, 'vcb');
      expect(result.draft!.type, TransactionType.expense);
      expect(result.draft!.merchant, isNotNull);
    },
    skip: !const bool.fromEnvironment('RECEIPT_QA_PROVIDED'),
  );
}
