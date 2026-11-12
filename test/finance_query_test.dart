import 'package:flutter_test/flutter_test.dart';
import 'package:tui_khon_mobile/core/offline/local_store.dart';
import 'package:tui_khon_mobile/features/finance_query/data/finance_query_repository.dart';

void main() {
  late LocalStore store;
  late FinanceQueryRepository repository;
  setUp(() async {
    store = LocalStore.memory('query-user');
    repository = FinanceQueryRepository(
      store,
      now: () => DateTime.utc(2026, 11, 7),
    );
    await store.put('wallets', {
      'id': 'cash',
      'name': 'Tiền mặt',
      'initial_balance': 1000000,
    });
    await store.put('categories', {
      'id': 'food',
      'name': 'Ăn uống',
      'type': 'expense',
    });
    for (final row in [
      {
        'id': 'a',
        'amount': 65000,
        'type': 'expense',
        'occurred_at': '2026-10-31T17:00:00Z',
      },
      {
        'id': 'b',
        'amount': 20000,
        'type': 'expense',
        'occurred_at': '2026-11-02T11:00:00Z',
      },
      {
        'id': 'c',
        'amount': 50000,
        'type': 'expense',
        'occurred_at': '2026-10-20T11:00:00Z',
      },
      {
        'id': 'd',
        'amount': 200000,
        'type': 'income',
        'occurred_at': '2026-11-01T11:00:00Z',
      },
    ]) {
      await store.put('transactions', {
        ...row,
        'category_id': 'food',
        'wallet_id': 'cash',
        'note': 'Cà phê',
      });
    }
    await store.put('budgets', {
      'id': 'budget',
      'month': '2026-11-01',
      'limit_amount': 100000,
    });
  });
  tearDown(() => store.close());
  test('Vietnam calendar includes midnight boundary and unsynced local writes without mutations', () async {
    final before = await store.pendingCount();
    final result = await repository.ask('Tháng này ăn uống hết bao nhiêu?');
    expect(result.expense, 85000);
    expect(result.categoryName, 'Ăn uống');
    expect(result.pending, before);
    expect(await store.pendingCount(), before);
    expect(result.entries.length, 3);
  });
  test(
    'calendar comparisons use this month when both periods are mentioned',
    () async {
      final result = await repository.ask('So sánh tháng này với tháng trước');
      expect(result.expense, 85000);
      expect(result.previousExpense, 50000);
      expect(result.previousIncome, 0);
      expect(result.income, 200000);
    },
  );
  test('ranking, balances, budget remaining and quoted search use exact notebook data', () async {
    expect(
      (await repository.ask('Top danh mục tháng này')).entries.single.amount,
      85000,
    );
    expect(
      (await repository.ask('Số dư tiền mặt')).entries.single.amount,
      1065000,
    );
    expect(
      (await repository.ask('Ngân sách tháng này')).entries.single.amount,
      15000,
    );
    expect((await repository.ask('Tìm giao dịch "Cà phê"')).entries.length, 3);
  });
  test(
    'follow-up retains category and changes only the requested period',
    () async {
      final first = await repository.ask('Chi ăn uống tháng này');
      final result = await repository.ask(
        'Còn tháng trước?',
        previous: first.plan,
      );
      expect(result.plan.categoryId, 'food');
      expect(result.expense, 50000);
    },
  );
  test('week begins Monday and invalid dates are rejected', () async {
    final result = await repository.ask('Chi tuần này');
    expect(result.plan.from, DateTime.utc(2026, 11, 2));
    expect(result.plan.to, DateTime.utc(2026, 11, 9));
    await expectLater(
      repository.ask('Chi từ 31/02/2026'),
      throwsA(isA<FinanceQueryFailure>()),
    );
  });
  test('missing or duplicate names require clarification', () async {
    await store.put('wallets', {
      'id': 'other',
      'name': 'Tiền mặt',
      'initial_balance': 0,
    });
    await expectLater(
      repository.ask('Số dư tiền mặt'),
      throwsA(isA<FinanceQueryFailure>()),
    );
  });
  test(
    'unsupported questions and write requests cannot silently execute',
    () async {
      await expectLater(
        repository.ask('Xóa khoản chi cà phê'),
        throwsA(isA<FinanceQueryFailure>()),
      );
      await expectLater(
        repository.ask('Chi trên 2 triệu'),
        throwsA(isA<FinanceQueryFailure>()),
      );
      await expectLater(
        repository.ask('Tư vấn bất kỳ'),
        throwsA(isA<FinanceQueryFailure>()),
      );
    },
  );
  test('deleted transactions are excluded and data changes invalidate earlier evidence', () async {
    final result = await repository.ask('Chi tháng này');
    await store.remove('transactions', 'b');
    expect((await repository.ask('Chi tháng này')).expense, 65000);
    expect(result.revision, isNot(store.revision));
  });
  test(
    'AI plans are allowlisted and unknown account IDs cannot query data',
    () async {
      final remote = FinanceQueryRepository(
        store,
        request: (_) async => {
          'plan': {
            'kind': 'summary',
            'from': '2026-11-01',
            'to': '2026-12-01',
            'wallet_id': 'someone-else',
          },
        },
        now: () => DateTime.utc(2026, 11, 7),
      );
      await expectLater(
        remote.ask('Phân tích cách khác'),
        throwsA(isA<FinanceQueryFailure>()),
      );
      expect(
        () => FinanceQueryPlan.fromJson({
          'kind': 'delete',
          'from': '2026-11-01',
          'to': '2026-12-01',
        }),
        throwsA(isA<FinanceQueryFailure>()),
      );
    },
  );
  test(
    'clarification keeps its original question without sending ledger amounts',
    () async {
      Map<String, dynamic>? request;
      final remote = FinanceQueryRepository(
        store,
        request: (body) async {
          request = body;
          return {
            'plan': {
              'kind': 'summary',
              'from': '2026-11-01',
              'to': '2026-12-01',
              'category_id': 'food',
            },
          };
        },
      );
      await remote.ask(
        'Ăn uống',
        clarificationFor: 'Phân tích khoản thuộc danh mục nào đó',
      );
      expect(
        request!['context_question'],
        'Phân tích khoản thuộc danh mục nào đó',
      );
      expect(request!.keys, isNot(contains('transactions')));
      expect(request!['wallets'].toString(), isNot(contains('1000000')));
    },
  );
  test('debts, goals and payable end-of-month recurrence follow existing domain models', () {
    final data = <String, List<Map<String, dynamic>>>{
      for (final key in [
        'transactions',
        'categories',
        'wallets',
        'budgets',
        'debts',
        'goals',
        'payables',
        'payable_occurrences',
      ])
        key: [],
    };
    data['debts'] = [
      {
        'id': 'debt',
        'type': 'borrow',
        'person_name': 'Lan',
        'amount': 500000,
        'paid_amount': 200000,
        'due_date': '2026-11-05',
        'status': 'partial',
      },
    ];
    data['goals'] = [
      {
        'id': 'goal',
        'name': 'Laptop',
        'target_amount': 10000000,
        'saved_amount': 3000000,
      },
    ];
    data['payables'] = [
      {
        'id': 'bill',
        'name': 'Tiền nhà',
        'amount': 2000000,
        'due_date': '2026-01-31',
        'recurrence': 'monthly',
      },
    ];
    FinanceQueryResult run(FinanceQueryKind kind, DateTime from, DateTime to) =>
        FinanceQueryRepository.evaluate(
          FinanceQueryPlan(kind: kind, from: from, to: to),
          data,
          revision: 0,
          pending: 0,
          today: DateTime.utc(2026, 11, 7),
        );
    expect(
      run(
        FinanceQueryKind.debts,
        DateTime.utc(2026, 11),
        DateTime.utc(2026, 12),
      ).entries.single.amount,
      300000,
    );
    final goal = run(
      FinanceQueryKind.goals,
      DateTime.utc(2026, 11),
      DateTime.utc(2026, 12),
    ).entries.single;
    expect(goal.amount, 3000000);
    expect(goal.target, 10000000);
    final bills = run(
      FinanceQueryKind.payables,
      DateTime.utc(2026, 2),
      DateTime.utc(2026, 3),
    );
    expect(bills.entries.single.date, DateTime.utc(2026, 2, 28));
    data['payable_occurrences'] = [
      {'id': bills.entries.single.id, 'status': 'paid'},
    ];
    expect(
      run(
        FinanceQueryKind.payables,
        DateTime.utc(2026, 2),
        DateTime.utc(2026, 3),
      ).entries,
      isEmpty,
    );
  });
}
