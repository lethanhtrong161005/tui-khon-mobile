import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline/local_store.dart';
import '../../../core/services/vietnamese_nlp_service.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../planning/models/planning_models.dart';
import '../../reminders/models/payable.dart';
import '../../reports/monthly_report.dart';

enum FinanceQueryKind {
  summary,
  comparison,
  ranking,
  transactions,
  balances,
  budgets,
  debts,
  payables,
  goals,
}

class FinanceQueryFailure implements Exception {
  const FinanceQueryFailure(this.code, [this.detail = '']);
  final String code, detail;
}

String _norm(String value) => VietnameseNlpService.normalizeText(value);
DateTime vietnamCalendar(DateTime instant) {
  final vn = instant.toUtc().add(const Duration(hours: 7));
  return DateTime.utc(vn.year, vn.month, vn.day);
}

String financeDate(DateTime date) => date.toIso8601String().substring(0, 10);

class FinanceQueryPlan {
  const FinanceQueryPlan({
    required this.kind,
    required this.from,
    required this.to,
    this.type,
    this.categoryId,
    this.walletId,
    this.search = '',
    this.debtType,
    this.overdueOnly = false,
    this.periodFilter = false,
  });
  final FinanceQueryKind kind;

  /// Calendar dates in Vietnam; `to` is exclusive.
  final DateTime from, to;
  final String? type, categoryId, walletId, debtType;
  final String search;
  final bool overdueOnly, periodFilter;

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'from': financeDate(from),
    'to': financeDate(to),
    'type': type,
    'category_id': categoryId,
    'wallet_id': walletId,
    'search': search,
    'debt_type': debtType,
    'overdue_only': overdueOnly,
    'period_filter': periodFilter,
  };

  factory FinanceQueryPlan.fromJson(Map<String, dynamic> json) {
    DateTime date(String key) {
      final value = json[key];
      if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value))
        throw const FinanceQueryFailure('invalid');
      final result = DateTime.tryParse('${value}T00:00:00Z');
      if (result == null || financeDate(result) != value)
        throw const FinanceQueryFailure('invalid');
      return result;
    }

    final kind = FinanceQueryKind.values
        .where((k) => k.name == json['kind'])
        .firstOrNull;
    final from = date('from'), to = date('to');
    if (kind == null ||
        !to.isAfter(from) ||
        to.difference(from).inDays > 3660 ||
        from.year < 2000 ||
        to.year > 2200 ||
        ![null, 'income', 'expense'].contains(json['type']) ||
        ![null, 'borrow', 'lend'].contains(json['debt_type']) ||
        (json['search'] != null &&
            (json['search'] is! String ||
                (json['search'] as String).length > 100)) ||
        (json['overdue_only'] != null && json['overdue_only'] is! bool) ||
        (json['period_filter'] != null && json['period_filter'] is! bool) ||
        (json['category_id'] != null && json['category_id'] is! String) ||
        (json['wallet_id'] != null && json['wallet_id'] is! String))
      throw const FinanceQueryFailure('invalid');
    return FinanceQueryPlan(
      kind: kind,
      from: from,
      to: to,
      type: json['type'] as String?,
      categoryId: json['category_id'] as String?,
      walletId: json['wallet_id'] as String?,
      search: json['search'] as String? ?? '',
      debtType: json['debt_type'] as String?,
      overdueOnly: json['overdue_only'] == true,
      periodFilter: json['period_filter'] == true,
    );
  }
}

class FinanceQueryEntry {
  const FinanceQueryEntry(
    this.id,
    this.label,
    this.amount, {
    this.target,
    this.date,
    this.type,
  });
  final String id, label;
  final int amount;
  final int? target;
  final DateTime? date;
  final String? type;
}

class FinanceQueryResult {
  const FinanceQueryResult({
    required this.plan,
    required this.entries,
    required this.revision,
    required this.pending,
    this.income = 0,
    this.expense = 0,
    this.previousIncome,
    this.previousExpense,
    this.quotaUsed,
    this.quotaLimit,
    this.categoryName,
    this.walletName,
  });
  final FinanceQueryPlan plan;
  final List<FinanceQueryEntry> entries;
  final int revision, pending, income, expense;
  final int? previousIncome, previousExpense, quotaUsed, quotaLimit;
  final String? categoryName, walletName;
}

typedef FinancePlanRequest = Future<Map<String, dynamic>> Function(
  Map<String, dynamic> body,
);

class FinanceQueryRepository {
  FinanceQueryRepository(this.store, {this.request, DateTime Function()? now})
    : now = now ?? DateTime.now;
  final LocalStore store;
  final FinancePlanRequest? request;
  final DateTime Function() now;

  Future<FinanceQueryResult> ask(
    String question, {
    FinanceQueryPlan? previous,
    String? clarificationFor,
  }) async {
    if (question.trim().isEmpty || question.length > 500)
      throw const FinanceQueryFailure('unsupported');
    final revision = store.revision;
    final data = await store.readSnapshot([
      'transactions',
      'wallets',
      'categories',
      'budgets',
      'debts',
      'goals',
      'payables',
      'payable_occurrences',
    ]);
    var plan = parseLocal(
      clarificationFor == null ? question : '$clarificationFor $question',
      data,
      previous: previous,
    );
    int? quotaUsed, quotaLimit;
    if (plan == null) {
      if (request == null) throw const FinanceQueryFailure('offline');
      Map<String, dynamic> response;
      try {
        response = await request!({
          'question': question,
          if (clarificationFor != null) 'context_question': clarificationFor,
          'today': financeDate(vietnamCalendar(now())),
          if (previous != null) 'previous': previous.toJson(),
          'categories': data['categories']!
              .map((r) => {'id': r['id'], 'name': r['name'], 'type': r['type']})
              .toList(),
          'wallets': data['wallets']!
              .map((r) => {'id': r['id'], 'name': r['name']})
              .toList(),
        });
      } on FinanceQueryFailure {
        rethrow;
      } catch (_) {
        throw const FinanceQueryFailure('offline');
      }
      final clarification = response['clarification'];
      if (clarification is String && clarification.isNotEmpty)
        throw FinanceQueryFailure('clarification', clarification);
      if (response['plan'] is! Map) throw const FinanceQueryFailure('invalid');
      plan = FinanceQueryPlan.fromJson(
        Map<String, dynamic>.from(response['plan'] as Map),
      );
      final quota = response['quota'] as Map?;
      quotaUsed = (quota?['used'] as num?)?.toInt();
      quotaLimit = (quota?['limit'] as num?)?.toInt();
    }
    _validate(plan, data);
    if (store.revision != revision) throw const FinanceQueryFailure('changed');
    final pending = await store.pendingCount();
    final result = evaluate(
      plan,
      data,
      revision: revision,
      pending: pending,
      today: vietnamCalendar(now()),
      quotaUsed: quotaUsed,
      quotaLimit: quotaLimit,
    );
    if (store.revision != revision) throw const FinanceQueryFailure('changed');
    return result;
  }

  FinanceQueryPlan? parseLocal(
    String question,
    Map<String, List<Map<String, dynamic>>> data, {
    FinanceQueryPlan? previous,
  }) {
    final q = _norm(question);
    if (RegExp(r'\b(xoa|sua|them|ghi giao dich|delete|update|insert)\b')
        .hasMatch(q))
      throw const FinanceQueryFailure('readOnly');
    final today = vietnamCalendar(now());
    DateTime from = DateTime.utc(today.year, today.month),
        to = DateTime.utc(today.year, today.month + 1);
    var explicitPeriod = false;
    final explicit = RegExp(r'thang\s+(\d{1,2})(?:[/-](\d{4}))?').firstMatch(q);
    final explicitDates = RegExp(r'(\d{1,2})/(\d{1,2})/(\d{4})')
        .allMatches(q)
        .toList();
    if (explicitDates.isNotEmpty) {
      DateTime parsed(RegExpMatch m) {
        final d = DateTime.utc(
          int.parse(m[3]!),
          int.parse(m[2]!),
          int.parse(m[1]!),
        );
        if (d.day != int.parse(m[1]!) || d.month != int.parse(m[2]!))
          throw const FinanceQueryFailure('invalid');
        return d;
      }

      from = parsed(explicitDates.first);
      to = parsed(explicitDates.last).add(const Duration(days: 1));
      explicitPeriod = true;
    } else if (explicit != null) {
      final month = int.parse(explicit[1]!);
      if (month < 1 || month > 12) throw const FinanceQueryFailure('invalid');
      from = DateTime.utc(int.parse(explicit[2] ?? '${today.year}'), month);
      to = DateTime.utc(from.year, from.month + 1);
      explicitPeriod = true;
    } else if (q.contains('hom qua') || q.contains('yesterday')) {
      from = today.subtract(const Duration(days: 1));
      to = today;
      explicitPeriod = true;
    } else if (q.contains('hom nay') || q.contains('today')) {
      from = today;
      to = today.add(const Duration(days: 1));
      explicitPeriod = true;
    } else if (q.contains('tuan nay') ||
        q.contains('this week') ||
        q.contains('tuan truoc') ||
        q.contains('last week')) {
      from = today.subtract(Duration(days: today.weekday - 1));
      if (q.contains('truoc') || q.contains('last'))
        from = from.subtract(const Duration(days: 7));
      to = from.add(const Duration(days: 7));
      explicitPeriod = true;
    } else if ((q.contains('thang truoc') || q.contains('last month')) &&
        !q.contains('thang nay') &&
        !q.contains('this month')) {
      from = DateTime.utc(today.year, today.month - 1);
      to = DateTime.utc(today.year, today.month);
      explicitPeriod = true;
    } else if (q.contains('nam nay') || q.contains('this year')) {
      from = DateTime.utc(today.year);
      to = DateTime.utc(today.year + 1);
      explicitPeriod = true;
    } else {
      final days = RegExp(r'(\d+)\s*(?:ngay|days)\s*(?:qua|gan day|recent)?')
          .firstMatch(q);
      if (days != null) {
        final n = int.parse(days[1]!);
        if (n < 1 || n > 3660) throw const FinanceQueryFailure('invalid');
        to = today.add(const Duration(days: 1));
        from = to.subtract(Duration(days: n));
        explicitPeriod = true;
      }
    }
    final kind = switch (q) {
      _ when RegExp(r'ngan sach|budget|han muc').hasMatch(q) =>
        FinanceQueryKind.budgets,
      _ when RegExp(r'phai tra|hoa don den han|payable|bill due').hasMatch(q) =>
        FinanceQueryKind.payables,
      _ when RegExp(r'\bno\b|cho vay|khoan vay|debt|borrow|lend').hasMatch(q) =>
        FinanceQueryKind.debts,
      _ when RegExp(r'muc tieu|tiet kiem|goal|saving').hasMatch(q) =>
        FinanceQueryKind.goals,
      _ when RegExp(r'so du|balance|con bao nhieu tien').hasMatch(q) =>
        FinanceQueryKind.balances,
      _ when RegExp(r'so sanh|tang|giam|compare|comparison').hasMatch(q) =>
        FinanceQueryKind.comparison,
      _ when RegExp(r'top|nhieu nhat|xep hang|ranking').hasMatch(q) =>
        FinanceQueryKind.ranking,
      _
          when RegExp(r'tim|liet ke|giao dich|search|transactions|list')
              .hasMatch(q) =>
        FinanceQueryKind.transactions,
      _
          when RegExp(
            r'\bchi\b|\bthu\b|tong|bao nhieu|spent|spend|spending|income|expense|total',
          ).hasMatch(q) =>
        FinanceQueryKind.summary,
      _ => null,
    };
    final followUp =
        previous != null &&
        explicitPeriod &&
        RegExp(
          r'^(con|the|vay|and|what about)?\s*(thang|tuan|hom|nam|last|this)',
        ).hasMatch(q);
    if (kind == null && !followUp) return null;
    if (RegExp(r'thang\s+\d{1,2}').allMatches(q).length > 1) return null;
    // Queries with operators outside this small grammar go to the structured planner.
    if (RegExp(
      r'lon hon|nho hon|tren \d|duoi \d|tru |ngoai |except|greater|less than|\d+\s*trieu',
    ).hasMatch(q))
      return null;
    String? matched(String entity) {
      final matches = data[entity]!
          .where(
            (r) =>
                _norm('${r['name']}').length > 2 &&
                q.contains(_norm('${r['name']}')),
          )
          .toList();
      if (matches.length > 1)
        throw FinanceQueryFailure(
          'ambiguous',
          matches.map((r) => '${r['name']}').join(', '),
        );
      return matches.firstOrNull?['id'] as String?;
    }

    final categoryId = matched('categories'), walletId = matched('wallets');
    String? type;
    final income = RegExp(r'\bthu\b|income').hasMatch(q),
        expense = RegExp(r'\bchi\b|expense|spending|spent').hasMatch(q);
    if (income != expense) type = income ? 'income' : 'expense';
    final quoted = RegExp('["“](.+?)["”]').firstMatch(question)?[1];
    var search =
        quoted ??
        (kind == FinanceQueryKind.debts
            ? data['debts']!
                  .map((r) => '${r['person_name']}')
                  .where((s) => q.contains(_norm(s)))
                  .firstOrNull
            : kind == FinanceQueryKind.goals
            ? data['goals']!
                  .map((r) => '${r['name']}')
                  .where((s) => q.contains(_norm(s)))
                  .firstOrNull
            : null);
    // Conservative local grammar: do not silently drop an unknown qualifier.
    // A complex request is delegated to the structured planner or kept for retry.
    var residual = q;
    for (final name in [
      if (categoryId != null)
        data['categories']!.firstWhere((r) => r['id'] == categoryId)['name'],
      if (walletId != null)
        data['wallets']!.firstWhere((r) => r['id'] == walletId)['name'],
      if (search != null) search,
    ]) {
      residual = residual.replaceAll(_norm('$name'), ' ');
    }
    residual = residual.replaceAll(
      RegExp(
        r'\d{1,2}/\d{1,2}/\d{4}|thang\s+\d{1,2}(?:[/-]\d{4})?|\d+\s*(?:ngay|days)',
      ),
      ' ',
    );
    residual = residual.replaceAll(
      RegExp(
        r'\b(?:so sanh|so du|ngan sach|han muc|danh muc|giao dich|thu nhap|chi tieu|muc tieu|tiet kiem|phai tra|cho vay|di vay|khoan vay|qua han|nhieu nhat|xep hang|hom nay|hom qua|thang nay|thang truoc|tuan nay|tuan truoc|nam nay|gan day|con lai|bao nhieu|het bao nhieu|how much|this month|last month|this week|last week|this year|what about)\b',
      ),
      ' ',
    );
    residual = residual.replaceAll(
      RegExp(
        r'\b(?:chi|thu|tong|het|duoc|da|toi|ai|con|the|vay|va|voi|trong|cua|tu|den|qua|nay|truoc|tim|liet ke|top|xem|khoan|tien|no|spend|spent|spending|income|expense|expenses|total|balance|budgets?|debts?|borrow|lend|goals?|savings?|payables?|bills?|due|compare|comparison|ranking|search|transactions|list|did|i|my|and|the|on)\b',
      ),
      ' ',
    );
    residual = residual.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
    if (residual.isNotEmpty) {
      if ([
            FinanceQueryKind.transactions,
            FinanceQueryKind.debts,
            FinanceQueryKind.goals,
            FinanceQueryKind.payables,
          ].contains(kind) &&
          !RegExp(
            r'\d|hoan thanh|tat toan|chua tra|da tra|paid|completed|settled',
          ).hasMatch(residual)) {
        search ??= residual;
      } else {
        return null;
      }
    }
    return FinanceQueryPlan(
      kind: kind ?? previous!.kind,
      from: from,
      to: to,
      type: type ?? (followUp ? previous.type : null),
      categoryId: categoryId ?? (followUp ? previous.categoryId : null),
      walletId: walletId ?? (followUp ? previous.walletId : null),
      search: search ?? (followUp ? previous.search : ''),
      debtType: q.contains('no toi') || q.contains('cho vay')
          ? 'lend'
          : q.contains('toi no') || q.contains('di vay')
          ? 'borrow'
          : null,
      overdueOnly: q.contains('qua han') || q.contains('overdue'),
      periodFilter: explicitPeriod,
    );
  }

  static void _validate(
    FinanceQueryPlan plan,
    Map<String, List<Map<String, dynamic>>> data,
  ) {
    // Validate even locally parsed plans through the same wire contract.
    FinanceQueryPlan.fromJson(plan.toJson());
    if (plan.categoryId != null &&
            !data['categories']!.any((r) => r['id'] == plan.categoryId) ||
        plan.walletId != null &&
            !data['wallets']!.any((r) => r['id'] == plan.walletId))
      throw const FinanceQueryFailure('invalid');
    final snapshots = [
      FinanceQueryKind.balances,
      FinanceQueryKind.debts,
      FinanceQueryKind.goals,
    ];
    if (plan.kind == FinanceQueryKind.balances && plan.periodFilter ||
        snapshots.contains(plan.kind) && plan.categoryId != null ||
        [
              FinanceQueryKind.debts,
              FinanceQueryKind.goals,
              FinanceQueryKind.payables,
              FinanceQueryKind.budgets,
            ].contains(plan.kind) &&
            plan.walletId != null) {
      throw const FinanceQueryFailure('invalid');
    }
    if (plan.kind == FinanceQueryKind.budgets &&
        (plan.from.day != 1 ||
            plan.to != DateTime.utc(plan.from.year, plan.from.month + 1))) {
      throw const FinanceQueryFailure('monthlyBudget');
    }
  }

  static FinanceQueryResult evaluate(
    FinanceQueryPlan plan,
    Map<String, List<Map<String, dynamic>>> data, {
    required int revision,
    required int pending,
    required DateTime today,
    int? quotaUsed,
    int? quotaLimit,
  }) {
    String? name(String entity, String? id) =>
        data[entity]!.where((r) => r['id'] == id).firstOrNull?['name']
            as String?;
    int amount(Map<String, dynamic> row, String key) =>
        (row[key] as num? ?? 0).toInt();
    bool period(DateTime day) =>
        !day.isBefore(plan.from) && day.isBefore(plan.to);
    bool search(String value) =>
        plan.search.isEmpty || _norm(value).contains(_norm(plan.search));
    final tx = data['transactions']!
        .where(
          (r) =>
              r['deleted'] != true &&
              (plan.type == null || r['type'] == plan.type) &&
              (plan.categoryId == null ||
                  r['category_id'] == plan.categoryId) &&
              (plan.walletId == null || r['wallet_id'] == plan.walletId) &&
              search('${r['note'] ?? ''}'),
        )
        .toList();
    DateTime day(Map<String, dynamic> r) =>
        vietnamCalendar(DateTime.parse(r['occurred_at'] as String));
    final current = tx.where((r) => period(day(r))).toList();
    var income = 0, expense = 0;
    for (final r in current) {
      if (r['type'] == 'income') {
        income += amount(r, 'amount');
      } else {
        expense += amount(r, 'amount');
      }
    }
    int? previousIncome, previousExpense;
    final entries = <FinanceQueryEntry>[];
    switch (plan.kind) {
      case FinanceQueryKind.summary:
      case FinanceQueryKind.transactions:
      case FinanceQueryKind.comparison:
        current.sort(
          (a, b) => '${b['occurred_at']}'.compareTo('${a['occurred_at']}'),
        );
        entries.addAll(
          current.map(
            (r) => FinanceQueryEntry(
              '${r['id']}',
              '${r['note'] ?? name('categories', r['category_id'] as String?) ?? ''}',
              amount(r, 'amount'),
              date: DateTime.parse(r['occurred_at'] as String),
              type: r['type'] as String?,
            ),
          ),
        );
        if (plan.kind == FinanceQueryKind.comparison) {
          final calendarMonth =
              plan.from.day == 1 &&
              plan.to == DateTime.utc(plan.from.year, plan.from.month + 1);
          final start = calendarMonth
              ? DateTime.utc(plan.from.year, plan.from.month - 1)
              : plan.from.subtract(plan.to.difference(plan.from));
          previousIncome = 0;
          previousExpense = 0;
          for (final r in tx.where(
            (r) => !day(r).isBefore(start) && day(r).isBefore(plan.from),
          )) {
            if (r['type'] == 'income') {
              previousIncome = previousIncome! + amount(r, 'amount');
            } else {
              previousExpense = previousExpense! + amount(r, 'amount');
            }
          }
        }
      case FinanceQueryKind.ranking:
        final groups = <String, int>{};
        for (final r in current.where(
          (r) => plan.type != null || r['type'] == 'expense',
        )) {
          final key = '${r['category_id'] ?? ''}';
          groups[key] = (groups[key] ?? 0) + amount(r, 'amount');
        }
        entries.addAll(
          groups.entries.map(
            (e) => FinanceQueryEntry(
              e.key,
              name('categories', e.key) ?? '',
              e.value,
            ),
          ),
        );
        entries.sort((a, b) => b.amount.compareTo(a.amount));
      case FinanceQueryKind.balances:
        for (final w in data['wallets']!.where(
          (r) =>
              r['is_archived'] != true &&
              (plan.walletId == null || r['id'] == plan.walletId),
        )) {
          final balance = data['transactions']!
              .where((r) => r['wallet_id'] == w['id'] && r['deleted'] != true)
              .fold<int>(
                amount(w, 'initial_balance'),
                (sum, r) =>
                    sum +
                    (r['type'] == 'income' ? 1 : -1) * amount(r, 'amount'),
              );
          entries.add(FinanceQueryEntry('${w['id']}', '${w['name']}', balance));
        }
      case FinanceQueryKind.budgets:
        final report = MonthlyReport.compute(
          plan.from,
          data['transactions']!,
          data['categories']!,
          data['budgets']!,
        );
        for (final b in report.budgets.where(
          (b) => plan.categoryId == null || b['category_id'] == plan.categoryId,
        )) {
          final spent = (b['spent'] as num).toInt(),
              limit = amount(b, 'limit_amount');
          entries.add(
            FinanceQueryEntry(
              '${b['id']}',
              name('categories', b['category_id'] as String?) ?? '',
              limit - spent,
              target: limit,
            ),
          );
        }
      case FinanceQueryKind.debts:
        for (final row in data['debts']!) {
          final debt = DebtModel.fromJson(row);
          if (plan.periodFilter &&
              (debt.dueDate == null ||
                  !period(
                    DateTime.utc(
                      debt.dueDate!.year,
                      debt.dueDate!.month,
                      debt.dueDate!.day,
                    ),
                  )))
            continue;
          if (debt.isSettled ||
              debt.remaining <= 0 ||
              !search(debt.personName) ||
              plan.debtType != null && debt.type.name != plan.debtType ||
              plan.overdueOnly && (debt.daysUntilDue(today) ?? 1) >= 0)
            continue;
          entries.add(
            FinanceQueryEntry(
              debt.id!,
              debt.personName,
              debt.remaining,
              date: debt.dueDate,
              type: debt.type.name,
            ),
          );
        }
      case FinanceQueryKind.payables:
        final paid = data['payable_occurrences']!
            .where((r) => r['status'] == 'paid')
            .map((r) => r['id'])
            .toSet();
        for (final row in data['payables']!) {
          final payable = Payable.fromJson(row);
          if (!payable.active || !search(payable.title)) continue;
          for (final date in payable.through(
            plan.to.subtract(const Duration(days: 1)),
          )) {
            final calendar = DateTime.utc(date.year, date.month, date.day);
            if (!period(calendar) ||
                paid.contains(payable.occurrenceId(date)) ||
                plan.overdueOnly && !calendar.isBefore(today))
              continue;
            entries.add(
              FinanceQueryEntry(
                payable.occurrenceId(date),
                payable.title,
                payable.amount,
                date: calendar,
              ),
            );
          }
        }
      case FinanceQueryKind.goals:
        for (final row in data['goals']!) {
          final goal = GoalModel.fromJson(row);
          if (plan.periodFilter &&
              (goal.deadline == null ||
                  !period(
                    DateTime.utc(
                      goal.deadline!.year,
                      goal.deadline!.month,
                      goal.deadline!.day,
                    ),
                  )))
            continue;
          if (search(goal.name))
            entries.add(
              FinanceQueryEntry(
                goal.id!,
                goal.name,
                goal.savedAmount,
                target: goal.targetAmount,
                date: goal.deadline,
              ),
            );
        }
    }
    return FinanceQueryResult(
      plan: plan,
      entries: entries,
      revision: revision,
      pending: pending,
      income: income,
      expense: expense,
      previousIncome: previousIncome,
      previousExpense: previousExpense,
      quotaUsed: quotaUsed,
      quotaLimit: quotaLimit,
      categoryName: name('categories', plan.categoryId),
      walletName: name('wallets', plan.walletId),
    );
  }
}

final financeQueryRepositoryProvider = Provider<FinanceQueryRepository?>((ref) {
  final store = ref.watch(localStoreProvider);
  if (store == null) return null;
  return FinanceQueryRepository(
    store,
    request: (body) async {
      try {
        final response = await ref
            .read(supabaseClientProvider)
            .functions
            .invoke('ai-finance-query', body: body)
            .timeout(const Duration(seconds: 35));
        return Map<String, dynamic>.from((response.data as Map)['data'] as Map);
      } on FunctionException catch (e) {
        if (e.status == 429) throw const FinanceQueryFailure('quota');
        if (e.status == 401) throw const FinanceQueryFailure('auth');
        rethrow;
      }
    },
  );
});
