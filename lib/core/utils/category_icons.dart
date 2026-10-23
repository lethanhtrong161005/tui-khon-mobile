import 'package:flutter/material.dart';

/// Maps Material icon names stored in the database (categories.icon, wallets.icon)
/// to [IconData]. Keep in sync with the defaults seeded by `handle_new_user()`.
class CategoryIcons {
  CategoryIcons._();

  static const Map<String, IconData> _icons = {
    'restaurant': Icons.restaurant,
    'local_cafe': Icons.local_cafe,
    'local_grocery_store': Icons.local_grocery_store,
    'local_gas_station': Icons.local_gas_station,
    'directions_car': Icons.directions_car,
    'home_work': Icons.home_work,
    'shopping_bag': Icons.shopping_bag,
    'receipt_long': Icons.receipt_long,
    'sports_esports': Icons.sports_esports,
    'local_hospital': Icons.local_hospital,
    'school': Icons.school,
    'flight': Icons.flight,
    'card_giftcard': Icons.card_giftcard,
    'shield': Icons.shield,
    'trending_up': Icons.trending_up,
    'handshake': Icons.handshake,
    'payments': Icons.payments,
    'stars': Icons.stars,
    'storefront': Icons.storefront,
    'work': Icons.work,
    'savings': Icons.savings,
    'request_quote': Icons.request_quote,
    'celebration': Icons.celebration,
    'account_balance': Icons.account_balance,
    'account_balance_wallet': Icons.account_balance_wallet,
    'laptop_mac': Icons.laptop_mac,
    'category': Icons.category,
  };

  static IconData resolve(String? name) => _icons[name] ?? Icons.category;

  /// Icon names offered by the icon pickers.
  static List<String> get names => _icons.keys.toList();
}

/// Parses `#RRGGBB` hex strings from the database into [Color].
Color? colorFromHex(String? hex) {
  if (hex == null || !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(hex)) return null;
  return Color(int.parse('FF${hex.substring(1)}', radix: 16));
}
