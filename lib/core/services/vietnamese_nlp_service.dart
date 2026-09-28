import 'package:flutter/material.dart';
import '../../features/home/models/transaction_model.dart';
import '../utils/currency_formatter.dart';

/// VietnameseNlpService processes natural Vietnamese conversational sentences
/// and extracts monetary amounts, transaction categories, and sources on-device.
class VietnameseNlpService {
  VietnameseNlpService._();

  /// Parses user text/voice input into a structured [TransactionModel].
  static TransactionModel parseInput(String input) {
    final lower = input.toLowerCase().trim();
    final amount = CurrencyFormatter.parseSlangAmount(lower).toDouble();

    // Determine whether this is income or expense
    final isIncome = lower.contains('trúng') ||
        lower.contains('lương') ||
        lower.contains('thưởng') ||
        lower.contains('nhận') ||
        lower.contains('thu');

    // Categorization logic based on Vietnamese keywords
    String category = 'Chi tiêu khác';
    IconData icon = Icons.payments;

    if (lower.contains('phở') || lower.contains('ăn') || lower.contains('cafe') || lower.contains('cà phê') || lower.contains('cơm')) {
      category = 'Ăn uống';
      icon = Icons.restaurant;
    } else if (lower.contains('xăng') || lower.contains('xe') || lower.contains('grab') || lower.contains('buýt')) {
      category = 'Di chuyển';
      icon = Icons.local_gas_station;
    } else if (lower.contains('nhà') || lower.contains('phòng') || lower.contains('điện') || lower.contains('nước')) {
      category = 'Nhà ở & Tiện ích';
      icon = Icons.home_work;
    } else if (lower.contains('mua') || lower.contains('áo') || lower.contains('quần') || lower.contains('shopee')) {
      category = 'Mua sắm & Tiêu dùng';
      icon = Icons.shopping_bag;
    } else if (isIncome) {
      category = 'Thu nhập khác';
      icon = Icons.celebration;
    }

    // Determine payment wallet/account
    String walletSource = 'Tiền mặt';
    if (lower.contains('momo')) {
      walletSource = 'Ví MoMo';
    } else if (lower.contains('vcb') || lower.contains('vietcombank')) {
      walletSource = 'Vietcombank';
    } else if (lower.contains('techcombank')) {
      walletSource = 'Techcombank';
    } else if (lower.contains('chuyển khoản')) {
      walletSource = 'Chuyển khoản';
    }

    // Generate a clean title
    String title = input;
    if (title.length > 30) {
      title = '${title.substring(0, 27)}...';
    }

    return TransactionModel(
      id: 'tx-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      category: category,
      amount: amount > 0 ? amount : 50000,
      type: isIncome ? TransactionType.income : TransactionType.expense,
      walletSource: walletSource,
      timestamp: DateTime.now(),
      badgeText: 'Gemini AI',
      icon: icon,
    );
  }
}
