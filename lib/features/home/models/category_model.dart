import 'package:flutter/material.dart';

import '../../../core/utils/category_icons.dart';
import 'transaction_model.dart';

/// A row of `public.categories`.
class CategoryModel {
  final String id;
  final String name;
  final TransactionType type;
  final String icon;
  final String color;
  final bool isDefault;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.type,
    this.icon = 'category',
    this.color = '#9E9E9E',
    this.isDefault = false,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) => CategoryModel(
        id: json['id'] as String,
        name: json['name'] as String,
        type: TransactionType.fromValue(json['type'] as String?),
        icon: (json['icon'] as String?) ?? 'category',
        color: (json['color'] as String?) ?? '#9E9E9E',
        isDefault: (json['is_default'] as bool?) ?? false,
      );

  IconData get iconData => CategoryIcons.resolve(icon);

  Color get colorValue => colorFromHex(color) ?? Colors.grey;

  Map<String, dynamic> toJson() => {'name': name.trim(), 'type': type.name, 'icon': icon, 'color': color};
}
