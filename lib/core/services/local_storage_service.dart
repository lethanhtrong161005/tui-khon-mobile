import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/home/models/transaction_model.dart';

/// LocalStorageService provides on-device persistence using SharedPreferences
/// so transactions and dashboard preferences survive app restarts.
class LocalStorageService {
  static const String _txStorageKey = 'tui_khon_transactions_v1';
  static const String _balanceVisibleKey = 'tui_khon_balance_visible_v1';

  /// Loads persisted transactions from SharedPreferences, or returns null if none saved yet.
  Future<List<TransactionModel>?> loadTransactions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawJson = prefs.getString(_txStorageKey);
      if (rawJson == null || rawJson.isEmpty) return null;

      final List<dynamic> decoded = jsonDecode(rawJson) as List<dynamic>;
      return decoded
          .map((item) => TransactionModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  /// Persists the list of transactions as JSON in SharedPreferences.
  Future<void> saveTransactions(List<TransactionModel> transactions) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(transactions.map((tx) => tx.toJson()).toList());
      await prefs.setString(_txStorageKey, encoded);
    } catch (_) {
      // Ignore storage errors in restricted environments
    }
  }

  /// Loads persisted balance visibility toggle state.
  Future<bool> loadBalanceVisibility() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_balanceVisibleKey) ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Saves balance visibility toggle state.
  Future<void> saveBalanceVisibility(bool isVisible) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_balanceVisibleKey, isVisible);
    } catch (_) {
      // Ignore storage errors
    }
  }
}
