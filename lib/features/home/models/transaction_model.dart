import 'package:flutter/material.dart';

/// TransactionType represents income vs expense transactions.
enum TransactionType { income, expense }

/// TransactionModel encapsulates a financial ledger entry.
class TransactionModel {
  final String id;
  final String title;
  final String category;
  final String categoryId;
  final String description;
  final String note;
  final String ownerId;
  final double amount;
  final TransactionType type;
  final String walletSource; // e.g. "Tiền mặt", "Ví MoMo", "Vietcombank"
  final DateTime timestamp;
  final String? badgeText; // e.g. "AI Note", "Voice", "Định kỳ"
  final IconData icon;

  const TransactionModel({
    required this.id,
    required this.title,
    required this.category,
    this.categoryId = '',
    this.description = '',
    this.note = '',
    this.ownerId = 'local:minh-quan',
    required this.amount,
    required this.type,
    required this.walletSource,
    required this.timestamp,
    required this.icon,
    this.badgeText,
  });

  /// Creates a copy of this TransactionModel with optionally updated fields.
  TransactionModel copyWith({
    String? id,
    String? title,
    String? category,
    String? categoryId,
    String? description,
    String? note,
    String? ownerId,
    double? amount,
    TransactionType? type,
    String? walletSource,
    DateTime? timestamp,
    IconData? icon,
    String? badgeText,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      categoryId: categoryId ?? this.categoryId,
      description: description ?? this.description,
      note: note ?? this.note,
      ownerId: ownerId ?? this.ownerId,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      walletSource: walletSource ?? this.walletSource,
      timestamp: timestamp ?? this.timestamp,
      icon: icon ?? this.icon,
      badgeText: badgeText ?? this.badgeText,
    );
  }
}
