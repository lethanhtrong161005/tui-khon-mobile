import 'package:tui_khon_mobile/core/offline/local_store.dart';
import 'package:tui_khon_mobile/core/utils/id_generator.dart';

/// Isolated UI fixture, never seeded into a signed-in user's database.
Future<void> seedReportDebtFixture(LocalStore store) async {
  await store.setMeta('bootstrapped', 'true');
  final names = [
    'Nhà ở & Tiện ích',
    'Mua sắm & Tiêu dùng',
    'Đi chợ & Siêu thị',
    'Du lịch',
    'Ăn uống',
    'Di chuyển',
    'Sức khỏe',
    'Học tập',
    'Giải trí',
    'Gia đình',
    'Thể thao',
    'Quà tặng',
    'Điện thoại',
    'Thú cưng',
    'Khác'
  ];
  final amounts = [
    4652000,
    2341000,
    1965000,
    1894000,
    1836000,
    1600000,
    1200000,
    1000000,
    800000,
    600000,
    500000,
    400000,
    250000,
    182000,
    100000
  ];
  final colors = [
    '#00A878',
    '#7257D9',
    '#FFBD44',
    '#FF852C',
    '#F96457',
    '#3999E8'
  ];
  await store.writeBatch([
    const LocalMutation(
        'wallets', {'id': 'cash', 'name': 'Tiền mặt', 'is_archived': false}),
    const LocalMutation(
        'wallets', {'id': 'bank', 'name': 'Ngân hàng', 'is_archived': false}),
    const LocalMutation('wallets',
        {'id': 'archived', 'name': 'Nguồn đã lưu trữ', 'is_archived': true}),
    for (var i = 0; i < names.length; i++)
      LocalMutation('categories', {
        'id': 'c$i',
        'name': names[i],
        'type': 'expense',
        'color': colors[i % colors.length],
        'icon': i == 0
            ? 'home'
            : i == 4
                ? 'restaurant'
                : 'shopping_bag'
      }),
    for (var i = 0; i < names.length; i++)
      LocalMutation('transactions', {
        'id': 'tx$i',
        'wallet_id': 'cash',
        'category_id': 'c$i',
        'type': 'expense',
        'amount': amounts[i],
        'occurred_at': '2026-10-15T03:00:00Z'
      }),
    const LocalMutation('transactions', {
      'id': 'salary',
      'wallet_id': 'bank',
      'type': 'income',
      'amount': 30330000,
      'occurred_at': '2026-10-01T03:00:00Z'
    }),
    const LocalMutation('transactions', {
      'id': 'previous-income',
      'wallet_id': 'bank',
      'type': 'income',
      'amount': 26460000,
      'occurred_at': '2026-09-01T03:00:00Z'
    }),
    const LocalMutation('transactions', {
      'id': 'previous-expense',
      'wallet_id': 'bank',
      'type': 'expense',
      'amount': 20936000,
      'occurred_at': '2026-09-02T03:00:00Z'
    }),
    const LocalMutation('budgets', {
      'id': 'total-budget',
      'month': '2026-10-01',
      'limit_amount': 20000000
    }),
    for (final b in [
      ('b0', 'c0', 5000000),
      ('b1', 'c1', 3000000),
      ('b4', 'c4', 1500000),
      ('b5', 'c5', 2000000),
      ('b6', 'c6', 1200000)
    ])
      LocalMutation('budgets', {
        'id': b.$1,
        'category_id': b.$2,
        'month': '2026-10-01',
        'limit_amount': b.$3
      }),
    const LocalMutation('debts', {
      'id': 'qa-debt',
      'type': 'borrow',
      'person_name': 'Lan',
      'amount': 3000000,
      'due_date': '2026-11-10',
      'note': 'Mượn tiền mua laptop'
    }),
    const LocalMutation('debt_payments', {
      'id': 'qa-payment-1',
      'debt_id': 'qa-debt',
      'amount': 500000,
      'paid_at': '2026-10-12T02:30:00Z',
      'note': 'Thanh toán lần 1',
      'record_transaction': false
    }),
    LocalMutation('debt_payments', {
      'id': 'qa-payment-2',
      'debt_id': 'qa-debt',
      'amount': 500000,
      'paid_at': '2026-10-24T02:30:00Z',
      'note': 'Thanh toán lần 2',
      'record_transaction': true,
      'wallet_id': 'bank',
      'transaction_id': debtPaymentTransactionId('qa-payment-2')
    }),
  ]);
  // Fixture represents an acknowledged snapshot. Derived expense is deliberately
  // included, exercising the same local report calculation as the application.
  for (final op in await store.pending()) {
    await store.discardOperation(op['op_id'] as String);
  }
}
