import 'dart:convert';
import 'package:crypto/crypto.dart';

typedef ReportRow = Map<String, dynamic>;

class MonthlyReport {
  MonthlyReport(
      {required this.month,
      required this.income,
      required this.expense,
      required this.previousIncome,
      required this.previousExpense,
      required this.byCategory,
      this.categoryDetails = const [],
      required this.budgets,
      required this.grounding,
      required this.fingerprint,
      required this.generatedAt});
  final DateTime month, generatedAt;
  final int income, expense, previousIncome, previousExpense;
  final Map<String, int> byCategory;
  final List<ReportRow> categoryDetails;
  final List<ReportRow> budgets;
  final ReportRow grounding;
  final String fingerprint;
  int get balance => income - expense;

  static MonthlyReport compute(DateTime selected, List<ReportRow> transactions,
      List<ReportRow> categories, List<ReportRow> allBudgets) {
    // Match get_period_summary SQL's Asia/Ho_Chi_Minh calendar on every device.
    final month = DateTime.utc(selected.year, selected.month);
    final end = DateTime.utc(month.year, month.month + 1);
    final previous = DateTime.utc(month.year, month.month - 1);
    final relevant = transactions.where((r) {
      if (r['deleted'] == true) return false;
      final d = DateTime.tryParse('${r['occurred_at']}')
          ?.toUtc()
          .add(const Duration(hours: 7));
      return d != null && !d.isBefore(previous) && d.isBefore(end);
    }).toList();
    var income = 0, expense = 0, previousIncome = 0, previousExpense = 0;
    final byId = <String, int>{};
    for (final row in relevant) {
      final d = DateTime.parse('${row['occurred_at']}')
          .toUtc()
          .add(const Duration(hours: 7));
      final amount = (row['amount'] as num).toInt();
      if (d.isBefore(month)) {
        if (row['type'] == 'income') {
          previousIncome += amount;
        } else if (row['type'] == 'expense') {
          previousExpense += amount;
        }
      } else if (row['type'] == 'income') {
        income += amount;
      } else if (row['type'] == 'expense') {
        expense += amount;
        final id = '${row['category_id'] ?? ''}';
        byId[id] = (byId[id] ?? 0) + amount;
      }
    }
    final budgets = allBudgets.where((r) {
      if (r['deleted'] == true) return false;
      final d = DateTime.tryParse('${r['month']}');
      return d != null && d.year == month.year && d.month == month.month;
    }).toList();
    String name(dynamic id) =>
        categories
            .where((c) => c['id'] == id)
            .map((c) => '${c['name']}')
            .firstOrNull ??
        'Chưa phân loại';
    // Canonical ordering prevents database row ordering from invalidating cache.
    List<String> canonical(List<ReportRow> rows) => rows.map((r) {
          final keys = r.keys.toList()..sort();
          return jsonEncode({for (final k in keys) k: r[k]});
        }).toList()
          ..sort();
    final fingerprint = sha256
        .convert(utf8.encode(jsonEncode([
          month.toIso8601String(),
          canonical(relevant),
          canonical(categories),
          canonical(budgets),
        ])))
        .toString();
    final grouped = <String, int>{};
    for (final entry in byId.entries) {
      final label = name(entry.key);
      grouped[label] = (grouped[label] ?? 0) + entry.value;
    }
    ReportRow evidence(bool current) {
      final rows = relevant.where((r) {
        final d = DateTime.parse('${r['occurred_at']}')
            .toUtc()
            .add(const Duration(hours: 7));
        return current == !d.isBefore(month);
      }).toList();
      final grouped = <String, ReportRow>{};
      for (final r in rows) {
        final key = '${r['type']}|${r['category_id']}';
        final group = grouped.putIfAbsent(
            key,
            () => {
                  'type': r['type'],
                  'category_id': r['category_id'],
                  'name': name(r['category_id']),
                  'total': 0,
                  'count': 0,
                });
        group['total'] = (group['total'] as int) + (r['amount'] as num).toInt();
        group['count'] = (group['count'] as int) + 1;
      }
      return {
        'income': current ? income : previousIncome,
        'expense': current ? expense : previousExpense,
        'transaction_count': rows.length,
        'by_category': grouped.values.toList(),
        if (current)
          'budgets': [
            for (final b in budgets)
              {
                'category_id': b['category_id'],
                'limit_amount': b['limit_amount'],
                'spent': b['category_id'] == null
                    ? expense
                    : byId['${b['category_id']}'] ?? 0,
              }
          ],
      };
    }

    return MonthlyReport(
        month: month,
        income: income,
        expense: expense,
        previousIncome: previousIncome,
        previousExpense: previousExpense,
        byCategory: grouped,
        categoryDetails: [
          for (final entry in byId.entries)
            {
              'id': entry.key,
              'name': name(entry.key),
              'amount': entry.value,
              'color': categories
                  .where((c) => c['id'] == entry.key)
                  .firstOrNull?['color'],
              'icon': categories
                  .where((c) => c['id'] == entry.key)
                  .firstOrNull?['icon'],
            }
        ],
        grounding: {'current': evidence(true), 'previous': evidence(false)},
        budgets: [
          for (final b in budgets)
            {
              ...b,
              'icon': categories
                  .where((c) => c['id'] == b['category_id'])
                  .firstOrNull?['icon'],
              'color': categories
                  .where((c) => c['id'] == b['category_id'])
                  .firstOrNull?['color'],
              'name': b['category_id'] == null
                  ? 'Tổng chi tiêu'
                  : name(b['category_id']),
              'spent': b['category_id'] == null
                  ? expense
                  : byId['${b['category_id']}'] ?? 0,
            }
        ],
        fingerprint: fingerprint,
        generatedAt: DateTime.now());
  }
}
