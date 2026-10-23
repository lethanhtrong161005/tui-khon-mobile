// Models of the "Kế hoạch" screen: debts (sổ nợ) and savings goals.
// Budgets reuse [BudgetProgress] from monthly_summary.dart.

int _int(Object? v) => (v as num? ?? 0).toInt();
DateTime? _date(Object? v) => v == null ? null : DateTime.parse(v as String);

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// borrow = tôi nợ người khác, lend = người khác nợ tôi.
enum DebtType {
  borrow,
  lend;

  static DebtType fromValue(String? v) => v == 'lend' ? lend : borrow;

  String get label => this == borrow ? 'Tôi nợ' : 'Nợ tôi';
}

/// A row of `public.debts` — a note of money owed, not a money movement.
class DebtModel {
  final String? id;
  final DebtType type;
  final String personName;
  final String? phone;
  final int amount;
  final int paidAmount;
  final DateTime? dueDate;
  final String? note;
  final bool isSettled;

  const DebtModel({
    this.id,
    required this.type,
    required this.personName,
    required this.amount,
    this.phone,
    this.paidAmount = 0,
    this.dueDate,
    this.note,
    this.isSettled = false,
  });

  factory DebtModel.fromJson(Map<String, dynamic> json) => DebtModel(
        id: json['id'] as String,
        type: DebtType.fromValue(json['type'] as String?),
        personName: json['person_name'] as String,
        phone: json['phone'] as String?,
        amount: _int(json['amount']),
        paidAmount: _int(json['paid_amount']),
        dueDate: _date(json['due_date']),
        note: json['note'] as String?,
        isSettled: json['status'] == 'settled',
      );

  /// Columns for insert / update (user_id is filled by the database).
  Map<String, dynamic> toJson() => {
        'type': type.name,
        'person_name': personName.trim(),
        'phone': (phone == null || phone!.trim().isEmpty) ? null : phone!.trim(),
        'amount': amount,
        'due_date': dueDate == null ? null : _isoDate(dueDate!),
        'note': (note == null || note!.trim().isEmpty) ? null : note!.trim(),
      };

  int get remaining => amount - paidAmount;

  /// Days until the due date (negative = overdue); null without a due date.
  int? daysUntilDue(DateTime today) {
    if (dueDate == null) return null;
    return DateTime(dueDate!.year, dueDate!.month, dueDate!.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
  }

  /// "Hôm nay", "Ngày mai", "Còn 3 ngày", "Quá hạn 2 ngày".
  String? dueLabel(DateTime today) {
    final days = daysUntilDue(today);
    if (days == null) return null;
    if (days < 0) return 'Quá hạn ${-days} ngày';
    if (days == 0) return 'Đến hạn hôm nay';
    if (days == 1) return 'Hạn ngày mai';
    return 'Còn $days ngày';
  }

  /// Active debt whose due date is today or already passed.
  bool isDue(DateTime today) => !isSettled && (daysUntilDue(today) ?? 1) <= 0;
}

/// A row of `public.goals`. Saving into a goal is only a note: it does not
/// move money out of any wallet.
class GoalModel {
  final String? id;
  final String name;
  final String icon;
  final String? color;
  final int targetAmount;
  final int savedAmount;
  final DateTime? deadline;
  final bool isCompleted;

  const GoalModel({
    this.id,
    required this.name,
    required this.targetAmount,
    this.icon = 'savings',
    this.color,
    this.savedAmount = 0,
    this.deadline,
    this.isCompleted = false,
  });

  factory GoalModel.fromJson(Map<String, dynamic> json) => GoalModel(
        id: json['id'] as String,
        name: json['name'] as String,
        icon: (json['icon'] as String?) ?? 'savings',
        color: json['color'] as String?,
        targetAmount: _int(json['target_amount']),
        savedAmount: _int(json['saved_amount']),
        deadline: _date(json['deadline']),
        isCompleted: json['status'] == 'completed',
      );

  Map<String, dynamic> toJson() => {
        'name': name.trim(),
        'icon': icon,
        'color': color,
        'target_amount': targetAmount,
        'deadline': deadline == null ? null : _isoDate(deadline!),
      };

  double get progress => targetAmount == 0 ? 0 : (savedAmount / targetAmount).clamp(0.0, 1.0);

  int get remaining => (targetAmount - savedAmount).clamp(0, targetAmount);
}
