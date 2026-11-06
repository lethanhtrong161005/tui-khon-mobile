import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tui_khon_mobile/features/advisor/models/advisor_models.dart';
import 'package:tui_khon_mobile/features/home/models/monthly_summary.dart';
import 'package:tui_khon_mobile/features/home/models/transaction_model.dart';
import 'package:tui_khon_mobile/features/planning/data/planning_repository.dart';
import 'package:tui_khon_mobile/features/planning/models/planning_models.dart';
import 'package:tui_khon_mobile/features/receipt/data/receipt_repository.dart';

void main() {
  group('DebtModel', () {
    final today = DateTime(2026, 10, 24, 15);

    test('parses a debts row and computes what is left', () {
      final debt = DebtModel.fromJson({
        'id': 'd',
        'type': 'lend',
        'person_name': 'Lan',
        'phone': null,
        'amount': 500000,
        'paid_amount': 200000,
        'due_date': '2026-10-24',
        'note': 'Học phí',
        'status': 'active',
      });
      expect(debt.type, DebtType.lend);
      expect(debt.remaining, 300000);
      expect(debt.isDue(today), isTrue);
      expect(debt.dueLabel(today), 'Đến hạn hôm nay');
    });

    test('due labels', () {
      DebtModel due(DateTime d) => DebtModel(type: DebtType.borrow, personName: 'A', amount: 1, dueDate: d);
      expect(due(DateTime(2026, 10, 25)).dueLabel(today), 'Hạn ngày mai');
      expect(due(DateTime(2026, 10, 28)).dueLabel(today), 'Còn 4 ngày');
      expect(due(DateTime(2026, 10, 21)).dueLabel(today), 'Quá hạn 3 ngày');
      expect(due(DateTime(2026, 10, 28)).isDue(today), isFalse);
      expect(const DebtModel(type: DebtType.borrow, personName: 'A', amount: 1).dueLabel(today), isNull);
    });

    test('toJson trims and drops empty optional fields', () {
      final json = DebtModel(
        type: DebtType.borrow,
        personName: ' Minh ',
        amount: 100,
        phone: ' ',
        dueDate: DateTime(2026, 11, 2),
      ).toJson();
      expect(json, {
        'type': 'borrow',
        'person_name': 'Minh',
        'phone': null,
        'amount': 100,
        'due_date': '2026-11-02',
        'note': null,
      });
    });
  });

  test('GoalModel progress is capped', () {
    final goal = GoalModel.fromJson({
      'id': 'g',
      'name': 'Laptop',
      'icon': 'laptop_mac',
      'color': null,
      'target_amount': 1000,
      'saved_amount': 1500,
      'deadline': null,
      'status': 'completed',
    });
    expect((goal.progress, goal.remaining, goal.isCompleted), (1.0, 0, true));
  });

  test('monthKey is the first day of the month', () {
    expect(monthKey(DateTime(2026, 1, 31)), '2026-01-01');
  });

  test('TransactionFilter equality and month range', () {
    final a = TransactionFilter(month: DateTime(2026, 12, 15));
    expect(a.start, DateTime(2026, 12));
    expect(a.end, DateTime(2027, 1));
    expect(a, TransactionFilter(month: DateTime(2026, 12, 1)));
    expect(a.copyWith(type: () => TransactionType.income) == a, isFalse);
    expect(a.copyWith(type: () => TransactionType.income).copyWith(type: () => null), a);
  });

  test('PickedReceipt derives MIME type from the file name', () {
    final bytes = Uint8List(1);
    expect(PickedReceipt.fromFile(bytes, name: 'IMG_1.HEIC').mimeType, 'image/heic');
    final jpeg = PickedReceipt.fromFile(bytes, name: 'photo.jpeg');
    expect((jpeg.mimeType, jpeg.extension), ('image/jpeg', 'jpg'));
  });

  test('AdvisorReport parses the "no spending yet" response', () {
    final report = AdvisorReport.fromJson({
      'period': {'from': '2026-09-25', 'to': '2026-10-24', 'range': 30},
      'totals': {'income': 0, 'expense': 0, 'previousIncome': 0, 'previousExpense': 0, 'expenseChange': null},
      'summary': 'Chưa có khoản chi nào trong 30 ngày qua.',
      'insights': [],
      'forecast': {'nextMonth': 0, 'riskCategories': [], 'baseline': 0},
    });
    expect((report.range, report.expenseChange, report.quotaUsed), (30, null, null));
  });

  test('PeriodSummary sums spending per week', () {
    final summary = PeriodSummary(byDay: [
      DailyTotal(day: DateTime(2026, 10, 18), expense: 100),
      DailyTotal(day: DateTime(2026, 10, 20), expense: 50),
      DailyTotal(day: DateTime(2026, 10, 24), expense: 25),
    ]);
    expect(summary.expenseBetween(DateTime(2026, 10, 18), DateTime(2026, 10, 24)), 175);
  });
}
