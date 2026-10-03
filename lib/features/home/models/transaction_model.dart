import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// TransactionType represents income vs expense transactions.
enum TransactionType { income, expense }

/// TransactionModel encapsulates a financial ledger entry.
class TransactionModel {
  final String id;
  final String title;
  final String category;
  final double amount;
  final TransactionType type;
  final String walletSource; // e.g. "Tiền mặt", "Ví MoMo", "Vietcombank"
  final DateTime timestamp;
  final String? badgeText; // e.g. "AI Note", "Voice", "Định kỳ", "Hóa đơn"
  final IconData icon;
  final String? note;
  final bool hasReceipt;

  const TransactionModel({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.type,
    required this.walletSource,
    required this.timestamp,
    required this.icon,
    this.badgeText,
    this.note,
    this.hasReceipt = false,
  });

  /// Whether this transaction is an income entry.
  bool get isIncome => type == TransactionType.income;

  /// Signed amount (+amount for income, -amount for expense).
  double get signedAmount => isIncome ? amount : -amount;

  /// Semantic icon color matching the Stitch UI design system.
  Color get categoryAccentColor {
    if (isIncome) return AppColors.primary;
    switch (category) {
      case 'Ăn uống':
        if (icon == Icons.local_cafe) return AppColors.tertiary;
        return AppColors.error;
      case 'Nhà ở':
      case 'Nhà ở & Tiện ích':
        return AppColors.tertiary;
      case 'Di chuyển':
        return AppColors.onSurfaceVariant;
      case 'Mua sắm':
      case 'Mua sắm & Tiêu dùng':
        return AppColors.secondary;
      default:
        return AppColors.outline;
    }
  }

  /// Semantic icon container background color matching the Stitch UI design system.
  Color get categoryContainerColor {
    if (isIncome) return AppColors.primaryFixed.withOpacity(0.4);
    switch (category) {
      case 'Ăn uống':
        if (icon == Icons.local_cafe) {
          return AppColors.tertiaryFixed.withOpacity(0.6);
        }
        return AppColors.errorContainer.withOpacity(0.45);
      case 'Nhà ở':
      case 'Nhà ở & Tiện ích':
        return AppColors.surfaceContainer;
      case 'Di chuyển':
        return AppColors.surfaceContainerHigh;
      case 'Mua sắm':
      case 'Mua sắm & Tiêu dùng':
        return AppColors.secondaryFixed.withOpacity(0.65);
      default:
        return AppColors.surfaceContainerHigh;
    }
  }

  /// Formats the transaction timestamp into a compact Vietnamese display string
  /// matching the Stitch recent transaction items (e.g., "12:30", "Hôm qua", "30/05").
  String formattedTimeLabel([DateTime? nowOverride]) {
    final now = nowOverride ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final txDay = DateTime(timestamp.year, timestamp.month, timestamp.day);
    final diffDays = today.difference(txDay).inDays;

    if (diffDays == 0) {
      final hh = timestamp.hour.toString().padLeft(2, '0');
      final mm = timestamp.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    } else if (diffDays == 1) {
      return 'Hôm qua';
    } else {
      final dd = timestamp.day.toString().padLeft(2, '0');
      final mo = timestamp.month.toString().padLeft(2, '0');
      return '$dd/$mo';
    }
  }

  /// Formats full date and time for the transaction detail view.
  String get formattedFullDate {
    final dd = timestamp.day.toString().padLeft(2, '0');
    final mo = timestamp.month.toString().padLeft(2, '0');
    final yyyy = timestamp.year;
    final hh = timestamp.hour.toString().padLeft(2, '0');
    final mm = timestamp.minute.toString().padLeft(2, '0');
    return '$dd/$mo/$yyyy • $hh:$mm';
  }

  /// Creates a copy of this TransactionModel with optionally updated fields.
  TransactionModel copyWith({
    String? id,
    String? title,
    String? category,
    double? amount,
    TransactionType? type,
    String? walletSource,
    DateTime? timestamp,
    IconData? icon,
    String? badgeText,
    String? note,
    bool? hasReceipt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      walletSource: walletSource ?? this.walletSource,
      timestamp: timestamp ?? this.timestamp,
      icon: icon ?? this.icon,
      badgeText: badgeText ?? this.badgeText,
      note: note ?? this.note,
      hasReceipt: hasReceipt ?? this.hasReceipt,
    );
  }

  /// Converts this TransactionModel into a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'amount': amount,
      'type': type.name,
      'walletSource': walletSource,
      'timestamp': timestamp.toIso8601String(),
      'badgeText': badgeText,
      'iconKey': _iconToKey(icon),
      'note': note,
      'hasReceipt': hasReceipt,
    };
  }

  /// Reconstructs a TransactionModel from a JSON map.
  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'expense';
    final category = json['category'] as String? ?? 'Khác';
    final iconKey = json['iconKey'] as String?;

    return TransactionModel(
      id: json['id'] as String,
      title: json['title'] as String,
      category: category,
      amount: (json['amount'] as num).toDouble(),
      type: typeStr == 'income' ? TransactionType.income : TransactionType.expense,
      walletSource: json['walletSource'] as String? ?? 'Tiền mặt',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      badgeText: json['badgeText'] as String?,
      icon: _keyToIcon(iconKey, category, typeStr == 'income'),
      note: json['note'] as String?,
      hasReceipt: json['hasReceipt'] as bool? ?? false,
    );
  }

  /// Resolves default IconData for a category name.
  static IconData iconForCategory(String category, {bool isIncome = false}) {
    if (isIncome) {
      if (category.contains('Lương')) return Icons.payments;
      return Icons.celebration;
    }
    switch (category) {
      case 'Ăn uống':
        return Icons.restaurant;
      case 'Di chuyển':
        return Icons.local_gas_station;
      case 'Nhà ở':
      case 'Nhà ở & Tiện ích':
        return Icons.home_work;
      case 'Mua sắm':
      case 'Mua sắm & Tiêu dùng':
        return Icons.shopping_bag;
      default:
        return Icons.category;
    }
  }

  static String _iconToKey(IconData icon) {
    if (icon == Icons.restaurant) return 'restaurant';
    if (icon == Icons.local_cafe) return 'local_cafe';
    if (icon == Icons.ramen_dining) return 'ramen_dining';
    if (icon == Icons.local_gas_station) return 'local_gas_station';
    if (icon == Icons.directions_bus) return 'directions_bus';
    if (icon == Icons.home_work) return 'home_work';
    if (icon == Icons.apartment) return 'apartment';
    if (icon == Icons.shopping_bag) return 'shopping_bag';
    if (icon == Icons.payments) return 'payments';
    if (icon == Icons.celebration) return 'celebration';
    if (icon == Icons.account_balance_wallet) return 'wallet';
    return 'category';
  }

  static IconData _keyToIcon(String? key, String category, bool isIncome) {
    switch (key) {
      case 'restaurant':
        return Icons.restaurant;
      case 'local_cafe':
        return Icons.local_cafe;
      case 'ramen_dining':
        return Icons.ramen_dining;
      case 'local_gas_station':
        return Icons.local_gas_station;
      case 'directions_bus':
        return Icons.directions_bus;
      case 'home_work':
        return Icons.home_work;
      case 'apartment':
        return Icons.apartment;
      case 'shopping_bag':
        return Icons.shopping_bag;
      case 'payments':
        return Icons.payments;
      case 'celebration':
        return Icons.celebration;
      case 'wallet':
        return Icons.account_balance_wallet;
      default:
        return iconForCategory(category, isIncome: isIncome);
    }
  }
}
