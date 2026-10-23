import 'package:flutter_test/flutter_test.dart';
import 'package:tui_khon_mobile/core/services/vietnamese_nlp_service.dart';
import 'package:tui_khon_mobile/features/home/models/category_model.dart';
import 'package:tui_khon_mobile/features/home/models/monthly_summary.dart';
import 'package:tui_khon_mobile/features/home/models/transaction_model.dart';
import 'package:tui_khon_mobile/features/home/models/wallet_model.dart';
import 'package:tui_khon_mobile/features/quick_record/data/quick_record_repository.dart';

void main() {
  const food = CategoryModel(id: 'c1', name: 'Ăn uống', type: TransactionType.expense, icon: 'restaurant');
  const home = CategoryModel(id: 'c2', name: 'Nhà ở & Tiện ích', type: TransactionType.expense, icon: 'home_work');
  const salary = CategoryModel(id: 'c3', name: 'Lương', type: TransactionType.income, icon: 'payments');
  const cash = WalletModel(id: 'w1', name: 'Tiền mặt');
  const momo = WalletModel(id: 'w2', name: 'Ví MoMo');

  group('TransactionModel', () {
    test('fromJson parses a transactions row and resolves names', () {
      final tx = TransactionModel.fromJson(
        {
          'id': 't1',
          'type': 'expense',
          'amount': 65000,
          'note': 'Ăn phở',
          'occurred_at': '2026-10-24T05:30:00+00:00',
          'source': 'voice',
          'receipt_path': null,
          'wallet_id': 'w1',
          'category_id': 'c1',
        },
        categories: {'c1': food},
        wallets: {'w1': cash},
      );
      expect(tx.amount, 65000);
      expect(tx.signedAmount, -65000);
      expect(tx.categoryName, 'Ăn uống');
      expect(tx.walletName, 'Tiền mặt');
      expect(tx.badgeText, 'Voice');
      expect(tx.occurredAt.isUtc, isFalse);
    });

    test('title falls back to the category name', () {
      final tx = TransactionModel(
        id: 't',
        type: TransactionType.income,
        amount: 1,
        walletId: 'w1',
        occurredAt: DateTime(2026),
        categoryName: 'Lương',
      );
      expect(tx.title, 'Lương');
    });
  });

  group('TransactionDraft', () {
    test('fromAiJson reads the ai-quick-record draft', () {
      final draft = TransactionDraft.fromAiJson({
        'type': 'income',
        'amount': 300000000,
        'category_id': 'c3',
        'category_name': 'Thu nhập khác',
        'wallet_id': 'w1',
        'wallet_name': 'Tiền mặt',
        'note': 'Trúng số',
        'occurred_at': '2026-10-24T12:00:00+07:00',
        'source': 'ai',
        'merchant': null,
      });
      expect(draft.isIncome, isTrue);
      expect(draft.amount, 300000000);
      expect(draft.source, TransactionSource.ai);
      expect(draft.isValid, isTrue);
    });

    test('toInsertJson matches the transactions columns', () {
      final json = TransactionDraft(
        type: TransactionType.expense,
        amount: 80000,
        walletId: 'w1',
        categoryId: 'c1',
        note: '  Đổ xăng ',
        occurredAt: DateTime.utc(2026, 10, 24, 1),
        source: TransactionSource.voice,
      ).toInsertJson(clientId: 'abc');
      expect(json, {
        'type': 'expense',
        'amount': 80000,
        'wallet_id': 'w1',
        'category_id': 'c1',
        'note': 'Đổ xăng',
        'occurred_at': '2026-10-24T01:00:00.000Z',
        'source': 'voice',
        'receipt_path': null,
        'client_id': 'abc',
      });
    });

    test('toInsertJson requires a wallet', () {
      const draft = TransactionDraft(type: TransactionType.expense, amount: 1);
      expect(draft.toInsertJson, throwsStateError);
    });
  });

  test('MonthlySummary parses get_monthly_summary output', () {
    // Captured from the RPC on a test database.
    final summary = MonthlySummary.fromJson({
      'to': '2026-10-31',
      'from': '2026-10-01',
      'month': '2026-10-01',
      'by_day': [
        {'day': '2026-10-24', 'income': 0, 'expense': 225000},
      ],
      'income': 0,
      'budgets': [
        {
          'id': 'b1',
          'spent': 225000,
          'category_id': 'c1',
          'limit_amount': 200000,
          'category_name': 'Ăn uống',
        },
      ],
      'expense': 225000,
      'previous': {'income': 0, 'expense': 150000},
      'by_category': [
        {'icon': 'restaurant', 'name': 'Ăn uống', 'type': 'expense', 'count': 4, 'total': 225000},
      ],
      'total_balance': -225000,
      'transaction_count': 4,
    });
    expect(summary.month, DateTime(2026, 10));
    expect(summary.expense, 225000);
    expect(summary.totalBalance, -225000);
    expect(summary.totalBudget, isNull); // only a category budget
    expect(summary.budgets.single.ratio, closeTo(1.125, 1e-9));
    expect(summary.expenseOn(DateTime(2026, 10, 24, 18)), 225000);
    expect(summary.expenseChangePercent, 50);
  });

  group('Offline NLP fallback', () {
    test('parses slang amounts and categories', () {
      final draft = VietnameseNlpService.parseInput('Ăn phở 65k');
      expect(draft.amount, 65000);
      expect(draft.type, TransactionType.expense);
      expect(draft.categoryName, 'Ăn uống');
    });

    test('"thuê căn hộ" is a housing expense, not income or food', () {
      final draft = VietnameseNlpService.parseInput('Tiền thuê căn hộ 4 triệu');
      expect(draft.type, TransactionType.expense);
      expect(draft.categoryName, 'Nhà ở & Tiện ích');
      expect(draft.amount, 4000000);
    });

    test('salary is income', () {
      final draft = VietnameseNlpService.parseInput('Lương tháng này 15 triệu');
      expect(draft.type, TransactionType.income);
      expect(draft.categoryName, 'Lương');
    });

    test('resolveDraftNames maps names to the user ids', () {
      final draft = resolveDraftNames(
        VietnameseNlpService.parseInput('cafe 35k momo'),
        const [food, home, salary],
        const [cash, momo],
      );
      expect(draft.categoryId, 'c1');
      expect(draft.walletId, 'w2');
    });

    test('resolveDraftNames falls back to the first wallet', () {
      final draft = resolveDraftNames(
        VietnameseNlpService.parseInput('đổ xăng 80k'),
        const [food],
        const [cash, momo],
      );
      expect(draft.walletId, 'w1');
      expect(draft.categoryId, isNull); // "Di chuyển" is not in this list
    });
  });
}
