import 'package:flutter/material.dart';

import '../../../core/utils/category_icons.dart';
import 'category_model.dart';
import 'wallet_model.dart';

/// TransactionType represents income vs expense transactions (DB enum `tx_type`).
enum TransactionType {
  income,
  expense;

  static TransactionType fromValue(String? value) => value == 'income' ? income : expense;
}

/// Where a transaction came from (DB enum `tx_source`).
enum TransactionSource {
  manual,
  ai,
  voice,
  receipt,
  debt;

  static TransactionSource fromValue(String? value) =>
      TransactionSource.values.firstWhere((s) => s.name == value, orElse: () => manual);

  /// Small badge shown next to the transaction in lists.
  String? get badgeText => switch (this) {
        TransactionSource.ai => 'AI Note',
        TransactionSource.voice => 'Voice',
        TransactionSource.receipt => 'Hóa đơn',
        TransactionSource.debt => 'Trả / Thu nợ',
        TransactionSource.manual => null,
      };
}

/// TransactionModel is a saved row of `public.transactions`.
/// Amounts are whole VND (`int`); category / wallet names are resolved client-side.
class TransactionModel {
  final String id;
  final TransactionType type;
  final int amount;
  final String walletId;
  final String? walletName;
  final String? categoryId;
  final String? categoryName;
  final String? categoryIcon;
  final String? categoryColor;
  final String? note;
  final DateTime occurredAt;
  final TransactionSource source;
  final String? receiptPath;

  const TransactionModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.walletId,
    required this.occurredAt,
    this.walletName,
    this.categoryId,
    this.categoryName,
    this.categoryIcon,
    this.categoryColor,
    this.note,
    this.source = TransactionSource.manual,
    this.receiptPath,
  });

  /// Builds a model from a `transactions` row, looking up display names
  /// in the user's categories and wallets.
  factory TransactionModel.fromJson(
    Map<String, dynamic> json, {
    Map<String, CategoryModel> categories = const {},
    Map<String, WalletModel> wallets = const {},
  }) {
    final categoryId = json['category_id'] as String?;
    final walletId = json['wallet_id'] as String;
    final category = categories[categoryId];
    return TransactionModel(
      id: json['id'] as String,
      type: TransactionType.fromValue(json['type'] as String?),
      amount: (json['amount'] as num).toInt(),
      walletId: walletId,
      walletName: wallets[walletId]?.name,
      categoryId: categoryId,
      categoryName: category?.name,
      categoryIcon: category?.icon,
      categoryColor: category?.color,
      note: json['note'] as String?,
      occurredAt: DateTime.parse(json['occurred_at'] as String).toLocal(),
      source: TransactionSource.fromValue(json['source'] as String?),
      receiptPath: json['receipt_path'] as String?,
    );
  }

  bool get isIncome => type == TransactionType.income;

  /// Signed amount: positive for income, negative for expense.
  int get signedAmount => isIncome ? amount : -amount;

  String get title => (note != null && note!.trim().isNotEmpty) ? note!.trim() : (categoryName ?? 'Giao dịch');

  IconData get icon => CategoryIcons.resolve(categoryIcon);

  String? get badgeText => source.badgeText;

  /// Editable copy for the transaction form.
  TransactionDraft toDraft() => TransactionDraft(
        type: type,
        amount: amount,
        walletId: walletId,
        walletName: walletName,
        categoryId: categoryId,
        categoryName: categoryName,
        note: note,
        occurredAt: occurredAt,
        source: source,
        receiptPath: receiptPath,
      );
}

/// Filters of the transaction history screen.
class TransactionFilter {
  final DateTime month;
  final TransactionType? type;
  final String? categoryId;
  final String? walletId;
  final String search;

  const TransactionFilter({required this.month, this.type, this.categoryId, this.walletId, this.search = ''});

  TransactionFilter copyWith({
    DateTime? month,
    TransactionType? Function()? type,
    String? Function()? categoryId,
    String? Function()? walletId,
    String? search,
  }) =>
      TransactionFilter(
        month: month ?? this.month,
        type: type != null ? type() : this.type,
        categoryId: categoryId != null ? categoryId() : this.categoryId,
        walletId: walletId != null ? walletId() : this.walletId,
        search: search ?? this.search,
      );

  DateTime get start => DateTime(month.year, month.month);
  DateTime get end => DateTime(month.year, month.month + 1);

  @override
  bool operator ==(Object other) =>
      other is TransactionFilter &&
      other.start == start &&
      other.type == type &&
      other.categoryId == categoryId &&
      other.walletId == walletId &&
      other.search == search;

  @override
  int get hashCode => Object.hash(start, type, categoryId, walletId, search);
}

/// TransactionDraft is a transaction that has not been saved yet:
/// produced by the AI quick record, the local NLP fallback or the manual form.
class TransactionDraft {
  final TransactionType type;
  final int amount;
  final String? walletId;
  final String? walletName;
  final String? categoryId;
  final String? categoryName;
  final String? note;
  final DateTime? occurredAt;
  final TransactionSource source;
  final String? receiptPath;
  final String? merchant;

  const TransactionDraft({
    required this.type,
    required this.amount,
    this.walletId,
    this.walletName,
    this.categoryId,
    this.categoryName,
    this.note,
    this.occurredAt,
    this.source = TransactionSource.manual,
    this.receiptPath,
    this.merchant,
  });

  /// Parses the `draft` object returned by the `ai-quick-record` Edge Function.
  factory TransactionDraft.fromAiJson(Map<String, dynamic> json) {
    final occurredAt = json['occurred_at'] as String?;
    return TransactionDraft(
      type: TransactionType.fromValue(json['type'] as String?),
      amount: (json['amount'] as num).toInt(),
      walletId: json['wallet_id'] as String?,
      walletName: json['wallet_name'] as String?,
      categoryId: json['category_id'] as String?,
      categoryName: json['category_name'] as String?,
      note: json['note'] as String?,
      occurredAt: occurredAt == null ? null : DateTime.parse(occurredAt).toLocal(),
      source: TransactionSource.fromValue(json['source'] as String?),
      merchant: json['merchant'] as String?,
    );
  }

  bool get isIncome => type == TransactionType.income;

  bool get isValid => amount > 0 && walletId != null;

  /// Row for `insert` into `public.transactions` (user_id is filled by the database).
  Map<String, dynamic> toInsertJson({String? clientId}) {
    if (walletId == null) throw StateError('Chưa chọn nguồn tiền cho giao dịch');
    return {
      'type': type.name,
      'amount': amount,
      'wallet_id': walletId,
      'category_id': categoryId,
      'note': (note == null || note!.trim().isEmpty) ? null : note!.trim(),
      'occurred_at': (occurredAt ?? DateTime.now()).toUtc().toIso8601String(),
      'source': source.name,
      'receipt_path': receiptPath,
      if (clientId != null) 'client_id': clientId,
    };
  }

  TransactionDraft copyWith({
    TransactionType? type,
    int? amount,
    String? walletId,
    String? walletName,
    String? categoryId,
    String? categoryName,
    String? note,
    DateTime? occurredAt,
    TransactionSource? source,
    String? receiptPath,
  }) {
    return TransactionDraft(
      type: type ?? this.type,
      amount: amount ?? this.amount,
      walletId: walletId ?? this.walletId,
      walletName: walletName ?? this.walletName,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      note: note ?? this.note,
      occurredAt: occurredAt ?? this.occurredAt,
      source: source ?? this.source,
      receiptPath: receiptPath ?? this.receiptPath,
      merchant: merchant,
    );
  }
}
