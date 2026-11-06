import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// A row of `public.notifications` (budget alerts, recurring reminders...).
class NotificationModel {
  final String id;
  final String type; // budget | reminder | debt | goal | system
  final String title;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    this.isRead = false,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) => NotificationModel(
        id: json['id'] as String,
        type: json['type'] as String,
        title: json['title'] as String,
        message: json['message'] as String,
        isRead: (json['is_read'] as bool?) ?? false,
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      );

  IconData get icon => switch (type) {
        'budget' => Icons.donut_large,
        'reminder' => Icons.event_repeat,
        'debt' => Icons.receipt_long,
        'goal' => Icons.savings,
        _ => Icons.notifications,
      };

  Color get color => switch (type) {
        'budget' => AppColors.error,
        'reminder' => AppColors.tertiary,
        'goal' => AppColors.primary,
        _ => AppColors.secondary,
      };
}
