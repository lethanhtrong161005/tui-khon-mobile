import 'package:flutter/material.dart';

import '../../../core/utils/category_icons.dart';

/// A wallet with its live balance, read from the `public.wallet_balances` view.
class WalletModel {
  final String id;
  final String name;
  final String type; // cash | bank | ewallet | other
  final String icon;
  final String? color;
  final bool isArchived;
  final int initialBalance;
  final int balance;

  const WalletModel({
    required this.id,
    required this.name,
    this.type = 'cash',
    this.icon = 'account_balance_wallet',
    this.color,
    this.isArchived = false,
    this.initialBalance = 0,
    this.balance = 0,
  });

  factory WalletModel.fromJson(Map<String, dynamic> json) => WalletModel(
        id: (json['wallet_id'] ?? json['id']) as String,
        name: json['name'] as String,
        type: (json['type'] as String?) ?? 'cash',
        icon: (json['icon'] as String?) ?? 'account_balance_wallet',
        color: json['color'] as String?,
        isArchived: (json['is_archived'] as bool?) ?? false,
        initialBalance: (json['initial_balance'] as num? ?? 0).toInt(),
        balance: (json['balance'] as num? ?? 0).toInt(),
      );

  IconData get iconData => CategoryIcons.resolve(icon);

  String get typeLabel => switch (type) {
        'bank' => 'Tài khoản ngân hàng',
        'ewallet' => 'Ví điện tử',
        'cash' => 'Tiền mặt',
        _ => 'Khác',
      };

  /// Columns for insert / update.
  Map<String, dynamic> toJson() => {
        'name': name.trim(),
        'type': type,
        'icon': icon,
        'color': color,
        'initial_balance': initialBalance,
      };
}
