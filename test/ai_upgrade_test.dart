import 'package:tui_khon_mobile/features/quick_record/presentation/category_rules_screen.dart';
import 'package:tui_khon_mobile/core/offline/local_store.dart';
import 'package:tui_khon_mobile/core/offline/offline_wallet_repository.dart';
import 'package:tui_khon_mobile/core/offline/duplicate_service.dart';
import 'package:tui_khon_mobile/features/quick_record/data/quick_record_learning.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tui_khon_mobile/core/services/voice_input_service.dart';
import 'package:tui_khon_mobile/features/home/models/category_model.dart';
import 'package:tui_khon_mobile/features/home/models/wallet_model.dart';
import 'package:tui_khon_mobile/features/home/providers/home_providers.dart';
import 'package:tui_khon_mobile/features/quick_record/presentation/quick_record_screen.dart';
import 'package:tui_khon_mobile/features/receipt/data/receipt_repository.dart';
import 'package:tui_khon_mobile/features/home/data/wallet_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tui_khon_mobile/core/services/vietnamese_nlp_service.dart';
import 'package:tui_khon_mobile/features/home/models/transaction_model.dart';
import 'package:tui_khon_mobile/features/quick_record/data/quick_record_batch.dart';
import 'package:tui_khon_mobile/features/quick_record/data/quick_record_repository.dart';

void main() {
  test('local batch writes atomically and rolls back invalid drafts', () async {
    final store = LocalStore.memory('user-a');
    addTearDown(store.close);
    final writer = OfflineWalletRepository(store);
    const valid = TransactionDraft(
        type: TransactionType.expense, amount: 10000, walletId: 'cash');
    await expectLater(
        writer.addTransactions([valid, valid.copyWith(amount: 0)]),
        throwsStateError);
    expect(await store.rows('transactions'), isEmpty);
    expect(await store.pendingCount(), 0);
    await writer.addTransactions([valid, valid.copyWith(amount: 20000)]);
    expect(await store.rows('transactions'), hasLength(2));
    expect(await store.pendingCount(), 2);
  });

  test('learning persists per account and ignores deleted or archived targets',
      () async {
    final store = LocalStore.memory('user-a');
    final otherStore = LocalStore.memory('user-b');
    addTearDown(store.close);
    addTearDown(otherStore.close);
    final learning = QuickRecordLearning(store);
    const original = TransactionDraft(
        type: TransactionType.expense,
        amount: 35000,
        walletId: 'cash',
        categoryId: 'food',
        note: 'Coffee');
    await learning.remember(
        original, original.copyWith(categoryId: 'other', walletId: 'bank'));
    const categories = [
      CategoryModel(id: 'other', name: 'Other', type: TransactionType.expense)
    ];
    const wallets = [WalletModel(id: 'bank', name: 'Bank', type: 'bank')];
    final learned =
        await QuickRecordLearning(store).apply(original, categories, wallets);
    expect(learned.categoryId, 'other');
    expect(learned.walletId, 'cash');
    expect(learned.amount, 35000);
    final isolated = await QuickRecordLearning(otherStore)
        .apply(original, categories, wallets);
    expect(isolated.categoryId, 'food');
    expect(isolated.walletId, 'cash');
    final stale = await learning.apply(original, [], []);
    expect(stale.categoryId, 'food');
    expect(stale.walletId, 'cash');
  });

  test('Vietnamese normalization handles composed and combining accents', () {
    expect(
        VietnameseNlpService.normalizeText('  CÀ  PHÊ ĐẮNG  '), 'ca phe dang');
    expect(
        VietnameseNlpService.normalizeText(
            'ca\u0300 phe\u0302 Đa\u0306\u0301ng'),
        'ca phe dang');
  });

  test(
      'matching merchant rule takes precedence over generic regardless of id order',
      () async {
    final store = LocalStore.memory('user-a');
    addTearDown(store.close);
    await store.put('category_rules', {
      'id': 'a-generic',
      'keyword': 'Cà   phê',
      'merchant': null,
      'category_id': 'food',
      'enabled': true
    });
    await store.put('category_rules', {
      'id': 'z-merchant',
      'keyword': 'ca phe',
      'merchant': '  HIGHLANDS  ',
      'category_id': 'work',
      'enabled': true
    });
    const categories = [
      CategoryModel(id: 'food', name: 'Food', type: TransactionType.expense),
      CategoryModel(id: 'work', name: 'Work', type: TransactionType.expense),
    ];
    const matching = TransactionDraft(
        type: TransactionType.expense,
        amount: 35000,
        categoryId: 'other',
        note: ' CÀ PHÊ ',
        merchant: 'highlands');
    final learning = QuickRecordLearning(store);
    expect((await learning.apply(matching, categories, [])).categoryId, 'work');
    const otherMerchant = TransactionDraft(
        type: TransactionType.expense,
        amount: 35000,
        categoryId: 'other',
        note: 'ca phe',
        merchant: 'Other shop');
    expect((await learning.apply(otherMerchant, categories, [])).categoryId,
        'food');
    const noMerchant = TransactionDraft(
        type: TransactionType.expense,
        amount: 35000,
        categoryId: 'other',
        note: 'ca phe');
    expect(
        (await learning.apply(noMerchant, categories, [])).categoryId, 'food');
    await learning.remember(matching, matching.copyWith(categoryId: 'food'));
    final rows = await store.rows('category_rules');
    expect(rows.length, 2);
    expect(rows.singleWhere((r) => r['id'] == 'z-merchant')['merchant'],
        'highlands');
    expect(
        rows.singleWhere((r) => r['id'] == 'z-merchant')['keyword'], 'ca phe');
  });

  test('non-category edits never create or re-enable learning rules', () async {
    final store = LocalStore.memory('user-a');
    addTearDown(store.close);
    final learning = QuickRecordLearning(store);
    const original = TransactionDraft(
        type: TransactionType.expense,
        amount: 35000,
        walletId: 'cash',
        categoryId: 'food',
        note: 'Coffee');
    await learning.remember(original,
        original.copyWith(note: 'Other note', amount: 40000, walletId: 'bank'));
    expect(await store.rows('category_rules'), isEmpty);
    await learning.remember(original, original.copyWith(categoryId: 'other'));
    final row = (await store.rows('category_rules')).single;
    await store.put('category_rules', {...row, 'enabled': false});
    await learning.remember(original, original.copyWith(amount: 45000));
    expect((await store.rows('category_rules')).single['enabled'], false);
  });

  testWidgets('rules screen lists category and persists toggle and deletion',
      (tester) async {
    final store = LocalStore.memory('user-a');
    addTearDown(store.close);
    await store.put('category_rules', {
      'id': 'rule-a',
      'keyword': 'coffee',
      'category_id': 'food',
      'enabled': true
    });
    await tester.pumpWidget(ProviderScope(overrides: [
      localStoreProvider.overrideWithValue(store),
      categoriesProvider.overrideWith((ref) async => [
            const CategoryModel(
                id: 'food', name: 'Food', type: TransactionType.expense)
          ]),
    ], child: const MaterialApp(home: CategoryRulesScreen())));
    await tester.pumpAndSettle();
    expect(find.text('coffee'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect((await store.rows('category_rules')).single['enabled'], false);
    await tester.tap(find.byTooltip('Xóa quy tắc'));
    await tester.pumpAndSettle();
    expect(await store.rows('category_rules'), isEmpty);
    expect(find.text('Chưa có quy tắc phân loại'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('category correction learns only after successful selected save',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = LocalStore.memory('user-a');
    addTearDown(store.close);
    final wallet = _FailingOfflineWallet(store);
    await tester.pumpWidget(ProviderScope(overrides: [
      localStoreProvider.overrideWithValue(store),
      walletRepositoryProvider.overrideWithValue(wallet),
      duplicateServiceProvider.overrideWithValue(null),
      categoriesProvider.overrideWith((ref) async => [
            const CategoryModel(
                id: 'cat-food', name: 'Food', type: TransactionType.expense),
            const CategoryModel(
                id: 'cat-other', name: 'Other', type: TransactionType.expense),
          ]),
      walletsProvider.overrideWith((ref) async =>
          [const WalletModel(id: 'wallet-cash', name: 'Cash', type: 'cash')]),
      quickRecordRepositoryProvider.overrideWithValue(_MultiQuickRecord()),
      voiceInputProvider.overrideWithValue(_NoVoice()),
    ], child: const MaterialApp(home: QuickRecordScreen())));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'payments');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sửa').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Other').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu giao dịch').last);
    await tester.pumpAndSettle();
    expect(await store.rows('category_rules'), isEmpty);
    await tester.ensureVisible(find.text('Lưu đã chọn (2)'));
    await tester.tap(find.text('Lưu đã chọn (2)'));
    await tester.pumpAndSettle();
    expect(await store.rows('category_rules'), isEmpty);
    wallet.fail = false;
    await tester.tap(find.text('Lưu đã chọn (2)'));
    await tester.pumpAndSettle();
    expect((await store.rows('category_rules')).single['category_id'],
        'cat-other');
    expect(await store.rows('transactions'), hasLength(2));
    await tester.pumpWidget(const SizedBox());
  });

  test('incomplete item metadata and ambiguous offline amounts are retained',
      () {
    final item = QuickRecordItem.fromJson({
      'draft': {'type': 'expense', 'amount': 0, 'note': 'Books'},
      'source_text': 'mua sách',
      'question': 'Sách bao nhiêu?',
      'missing_fields': ['amount'],
    });
    final result = QuickRecordResult(items: [item]);
    expect(result.allDrafts.single.amount, 0);
    expect(result.allItems.single.sourceText, 'mua sách');
    expect(result.allItems.single.needsClarification, true);
    final drafts = VietnameseNlpService.parseMultiple(
        'cafe 35k; phở 65; mua sách',
        includeIncomplete: true);
    expect(drafts.map((d) => d.amount), [35000, 0, 0]);
    expect(VietnameseNlpService.parseInput('phở 65 nghìn').amount, 65000);
  });

  testWidgets(
      'card followup replaces only incomplete item without saving complete item twice',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final wallet = _BatchWallet();
    final quickRecord = _IncompleteQuickRecord();
    await tester.pumpWidget(ProviderScope(overrides: [
      walletRepositoryProvider.overrideWithValue(wallet),
      localStoreProvider.overrideWithValue(null),
      duplicateServiceProvider.overrideWithValue(null),
      quickRecordRepositoryProvider.overrideWithValue(quickRecord),
      voiceInputProvider.overrideWithValue(_NoVoice()),
    ], child: const MaterialApp(home: QuickRecordScreen())));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'coffee 41k; mua sách');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect(find.byType(CheckboxListTile), findsNWidgets(2));
    expect(
        tester
            .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
            .map((c) => c.value),
        [true, false]);
    await tester.ensureVisible(find.text('Lưu đã chọn (1)'));
    await tester.tap(find.text('Lưu đã chọn (1)'));
    await tester.pumpAndSettle();
    expect(wallet.batches.single.single.amount, 41000);
    await tester.tap(find.text('Bổ sung'));
    await tester.pumpAndSettle();
    expect(find.text('Bổ sung: mua sách'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '80k');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect(quickRecord.history.map((t) => t.text),
        ['mua sách', 'Sách bao nhiêu?']);
    expect(find.text('Đã lưu vào sổ'), findsOneWidget);
    expect(find.text('Bổ sung'), findsNothing);
    await tester.ensureVisible(find.text('Lưu đã chọn (1)'));
    await tester.tap(find.text('Lưu đã chọn (1)'));
    await tester.pumpAndSettle();
    expect(wallet.batches.map((b) => b.single.amount), [41000, 80000]);
    expect(find.text('Đã lưu vào sổ'), findsNWidgets(2));
  });

  testWidgets('selected cards save through optional batch capability',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final wallet = _BatchWallet();
    await tester.pumpWidget(ProviderScope(overrides: [
      walletRepositoryProvider.overrideWithValue(wallet),
      localStoreProvider.overrideWithValue(null),
      duplicateServiceProvider.overrideWithValue(null),
      quickRecordRepositoryProvider.overrideWithValue(_MultiQuickRecord()),
      voiceInputProvider.overrideWithValue(_NoVoice()),
    ], child: const MaterialApp(home: QuickRecordScreen())));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'two payments');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect(find.byType(CheckboxListTile), findsNWidgets(2));
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Lưu đã chọn (1)'));
    await tester.tap(find.text('Lưu đã chọn (1)'));
    await tester.pumpAndSettle();
    expect(wallet.batches, hasLength(1));
    expect(wallet.batches.single.map((d) => d.amount), [42000]);
    expect(find.text('Đã lưu vào sổ'), findsOneWidget);
  });

  testWidgets('legacy partial failure retries only unsaved selected drafts',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final wallet = _FailOnceWallet();
    await tester.pumpWidget(ProviderScope(overrides: [
      walletRepositoryProvider.overrideWithValue(wallet),
      localStoreProvider.overrideWithValue(null),
      duplicateServiceProvider.overrideWithValue(null),
      quickRecordRepositoryProvider.overrideWithValue(_MultiQuickRecord()),
      voiceInputProvider.overrideWithValue(_NoVoice()),
    ], child: const MaterialApp(home: QuickRecordScreen())));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'payments');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Lưu đã chọn (2)'));
    await tester.tap(find.text('Lưu đã chọn (2)'));
    await tester.pumpAndSettle();
    expect(wallet.writes, [41000]);
    expect(find.text('Đã lưu vào sổ'), findsOneWidget);
    await tester.ensureVisible(find.text('Lưu đã chọn (1)'));
    await tester.tap(find.text('Lưu đã chọn (1)'));
    await tester.pumpAndSettle();
    expect(wallet.writes, [41000, 42000]);
    expect(find.text('Đã lưu vào sổ'), findsNWidgets(2));
  });

  testWidgets('duplicates start unselected and remain explicitly selectable',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final wallet = _BatchWallet();
    await tester.pumpWidget(ProviderScope(overrides: [
      walletRepositoryProvider.overrideWithValue(wallet),
      localStoreProvider.overrideWithValue(null),
      duplicateServiceProvider.overrideWithValue(null),
      quickRecordRepositoryProvider
          .overrideWithValue(_MultiQuickRecord(duplicate: true)),
      voiceInputProvider.overrideWithValue(_NoVoice()),
    ], child: const MaterialApp(home: QuickRecordScreen())));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'repeated payments');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    final cards = tester
        .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
        .toList();
    expect(cards.map((c) => c.value), [true, false]);
    expect(find.textContaining('Có thể trùng'), findsOneWidget);
    await tester.tap(find.byType(CheckboxListTile).last);
    await tester.pumpAndSettle();
    expect(find.text('Lưu đã chọn (2)'), findsOneWidget);
  });

  test('old single draft responses remain compatible', () {
    const draft =
        TransactionDraft(type: TransactionType.expense, amount: 50000);
    expect(const QuickRecordResult(draft: draft).allDrafts, [draft]);
    expect(const QuickRecordResult(question: 'Amount?').allDrafts, isEmpty);
  });

  test('multi draft results take precedence and are capped at ten', () {
    final drafts = List.generate(12,
        (i) => TransactionDraft(type: TransactionType.expense, amount: i + 1));
    final result = QuickRecordResult(draft: drafts.last, drafts: drafts);
    expect(result.draft, drafts.first);
    expect(result.allDrafts.length, 10);
    expect(result.allDrafts.first.amount, 1);
    expect(result.allDrafts.last.amount, 10);
  });

  test('offline clauses preserve independent amounts and sources', () {
    final drafts = VietnameseNlpService.parseMultiple('cafe 35k; xăng 80k',
        source: TransactionSource.voice);
    expect(drafts.map((d) => d.amount), [35000, 80000]);
    expect(drafts.map((d) => d.source), everyElement(TransactionSource.voice));
    expect(VietnameseNlpService.parseMultiple('chưa có số tiền'), isEmpty);
    expect(
        VietnameseNlpService.parseMultiple(
                List.filled(12, 'cafe 35k').join(';'))
            .length,
        10);
  });

  test('duplicate candidates use ten minute window, type, wallet and amount',
      () {
    final draft = TransactionDraft(
        type: TransactionType.expense,
        amount: 35000,
        walletId: 'cash',
        occurredAt: DateTime.parse('2026-10-27T18:00:00Z'));
    expect(
        isPossibleDuplicate(draft,
            draft.copyWith(occurredAt: DateTime.parse('2026-10-27T18:07:00Z'))),
        isTrue);
    expect(
        isPossibleDuplicate(draft,
            draft.copyWith(occurredAt: DateTime.parse('2026-10-28T18:00:00Z'))),
        isFalse);
    expect(
        isPossibleDuplicate(draft, draft.copyWith(walletId: 'bank')), isFalse);
    expect(
        isPossibleDuplicate(
            draft, draft.copyWith(type: TransactionType.income)),
        isFalse);
    expect(isPossibleDuplicate(draft, draft.copyWith(amount: 35001)), isFalse);
    expect(
        isPossibleDuplicate(
            draft,
            const TransactionDraft(
                type: TransactionType.expense,
                amount: 35000,
                walletId: 'cash')),
        isFalse);
  });
}

class _MultiQuickRecord implements QuickRecordRepository {
  _MultiQuickRecord({this.duplicate = false});
  final bool duplicate;
  @override
  Future<int?> fetchTodayChatUsage() async => 0;
  @override
  Future<QuickRecordResult> scanReceipt(PickedReceipt receipt) async =>
      const QuickRecordResult();
  @override
  Future<QuickRecordResult> parse(
    String text, {
    required List<CategoryModel> categories,
    required List<WalletModel> wallets,
    bool voice = false,
    List<ChatTurn> history = const [],
  }) async =>
      QuickRecordResult(drafts: [
        for (final amount in [41000, duplicate ? 41000 : 42000])
          TransactionDraft(
              type: TransactionType.expense,
              amount: amount,
              walletId: 'wallet-cash',
              categoryId: 'cat-food',
              note: 'Payment',
              occurredAt: DateTime.now()),
      ]);
}

class _BatchWallet extends _TestWallet implements QuickRecordBatchWriter {
  final List<List<TransactionDraft>> batches = [];
  @override
  Future<void> addTransactions(List<TransactionDraft> drafts) async {
    batches.add(List.of(drafts));
    for (final draft in drafts) {
      await super.addTransaction(draft);
    }
  }
}

class _NoVoice implements VoiceInput {
  @override
  bool get isListening => false;
  @override
  Future<bool> start(
          {required void Function(String, bool) onResult,
          void Function()? onDone,
          void Function(String)? onError}) async =>
      false;
  @override
  Future<void> stop() async {}
}

class _FailOnceWallet extends _TestWallet {
  final writes = <int>[];
  bool failed = false;
  @override
  Future<void> addTransaction(TransactionDraft draft) async {
    if (draft.amount == 42000 && !failed) {
      failed = true;
      throw StateError('Temporary write failure');
    }
    writes.add(draft.amount);
    await super.addTransaction(draft);
  }
}

class _FailingOfflineWallet extends OfflineWalletRepository {
  _FailingOfflineWallet(super.store);
  bool fail = true;
  @override
  Future<void> addTransactions(List<TransactionDraft> drafts) async {
    if (fail) throw StateError('Temporary failure');
    await super.addTransactions(drafts);
  }
}

class _IncompleteQuickRecord extends _MultiQuickRecord {
  List<ChatTurn> history = [];
  int calls = 0;
  @override
  Future<QuickRecordResult> parse(
    String text, {
    required List<CategoryModel> categories,
    required List<WalletModel> wallets,
    bool voice = false,
    List<ChatTurn> history = const [],
  }) async {
    this.history = history;
    calls++;
    TransactionDraft draft(int amount, String note) => TransactionDraft(
        type: TransactionType.expense,
        amount: amount,
        walletId: 'wallet-cash',
        categoryId: 'cat-food',
        note: note,
        occurredAt: DateTime.now());
    if (calls > 1)
      return QuickRecordResult(items: [
        QuickRecordItem(draft: draft(80000, 'Books'), sourceText: 'mua sách')
      ]);
    return QuickRecordResult(items: [
      QuickRecordItem(draft: draft(41000, 'Coffee'), sourceText: 'coffee 41k'),
      QuickRecordItem(
          draft: draft(0, 'Books'),
          sourceText: 'mua sách',
          question: 'Sách bao nhiêu?',
          missingFields: const ['amount']),
    ]);
  }
}

/// Minimal repository fixture keeps quick-record tests independent of seed enums.
class _TestWallet implements WalletRepository {
  final _transactions = <TransactionModel>[];
  @override
  Future<List<CategoryModel>> fetchCategories() async => const [
        CategoryModel(
            id: 'cat-food', name: 'Food', type: TransactionType.expense),
        CategoryModel(
            id: 'cat-other', name: 'Other', type: TransactionType.expense),
      ];
  @override
  Future<List<WalletModel>> fetchWallets() async =>
      const [WalletModel(id: 'wallet-cash', name: 'Cash', type: 'cash')];
  @override
  Future<List<TransactionModel>> fetchRecentTransactions(
          {int limit = 10}) async =>
      _transactions.reversed.take(limit).toList();
  @override
  Future<void> addTransaction(TransactionDraft draft) async {
    _transactions.add(TransactionModel.fromJson(
        {'id': 'tx-${_transactions.length}', ...draft.toInsertJson()}));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
