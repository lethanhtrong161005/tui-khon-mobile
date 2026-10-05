import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/transaction_model.dart';

class TransactionCategory {
  const TransactionCategory(
      {required this.id, required this.name, required this.type});

  final String id;
  final String name;
  final TransactionType type;

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'type': type.name};

  factory TransactionCategory.fromJson(Map<String, dynamic> json) =>
      TransactionCategory(
        id: json['id'] as String,
        name: json['name'] as String,
        type: TransactionType.values.byName(json['type'] as String),
      );
}

/// Local, owner-scoped transaction store. All writes are validated here before persistence.
class LocalWalletRepository extends ChangeNotifier {
  LocalWalletRepository._();

  static final LocalWalletRepository instance = LocalWalletRepository._();
  static const String defaultUserId = 'local:phone:0988123456';
  static const String _legacyUserId = 'local:minh-quan';
  static const double _openingBalance = 32550000;
  static const double _openingMonthlyIncome = 13500000;
  static const double _openingMonthlyExpense = 9620000;
  static const String _transactionsKey = 'wallet.transactions.v1';
  static const String _categoriesKey = 'wallet.categories.v1';

  SharedPreferences? _preferences;
  String _currentUserId = defaultUserId;
  final List<TransactionModel> _transactions = [];
  final List<TransactionCategory> _categories = [];

  String get currentUserId => _currentUserId;

  /// Selects the active local profile after the login screen identifies it.
  /// This provides on-device data separation, not server-backed authentication.
  void setCurrentUser(String userId) {
    final normalized = userId.trim();
    if (normalized.isEmpty) throw ArgumentError('Tài khoản không hợp lệ.');
    if (_currentUserId == normalized) return;
    _currentUserId = normalized;
    notifyListeners();
  }

  Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();
    final rawTransactions = _preferences!.getStringList(_transactionsKey) ?? [];
    var migratedLegacyOwner = false;
    for (final raw in rawTransactions) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        var transaction = _transactionFromJson(json);
        if (transaction.ownerId == _legacyUserId) {
          transaction = transaction.copyWith(ownerId: defaultUserId);
          migratedLegacyOwner = true;
        }
        _transactions.add(transaction);
      } on FormatException {
        // Ignore corrupted rows while allowing valid local data to remain available.
      } on TypeError {
        // Ignore rows from an incompatible older schema.
      }
    }
    if (migratedLegacyOwner) await _persistTransactions();

    final rawCategories = _preferences!.getStringList(_categoriesKey) ?? [];
    for (final raw in rawCategories) {
      try {
        _categories.add(TransactionCategory.fromJson(
            jsonDecode(raw) as Map<String, dynamic>));
      } on FormatException {
        // An invalid category row should not prevent the app from opening.
      } on TypeError {
        // An invalid category row should not prevent the app from opening.
      }
    }
    if (_categories.isEmpty) {
      _categories.addAll(_defaultCategories);
      await _persistCategories();
    }
    if (!_preferences!.containsKey(_transactionsKey)) {
      _transactions.addAll(_sampleTransactions);
      await _persistTransactions();
    }
  }

  static const List<TransactionCategory> _defaultCategories = [
    TransactionCategory(
        id: 'income_salary', name: 'Lương', type: TransactionType.income),
    TransactionCategory(
        id: 'income_bonus', name: 'Thưởng', type: TransactionType.income),
    TransactionCategory(
        id: 'income_other',
        name: 'Thu nhập khác',
        type: TransactionType.income),
    TransactionCategory(
        id: 'expense_food', name: 'Ăn uống', type: TransactionType.expense),
    TransactionCategory(
        id: 'expense_transport',
        name: 'Di chuyển',
        type: TransactionType.expense),
    TransactionCategory(
        id: 'expense_home',
        name: 'Nhà ở & Tiện ích',
        type: TransactionType.expense),
    TransactionCategory(
        id: 'expense_shopping', name: 'Mua sắm', type: TransactionType.expense),
    TransactionCategory(
        id: 'expense_other',
        name: 'Chi tiêu khác',
        type: TransactionType.expense),
  ];

  static List<TransactionModel> get _sampleTransactions {
    final now = DateTime.now();
    return [
      TransactionModel(
        id: 'tx_seed_pho',
        title: 'Ăn phở Thìn Lò Đúc',
        description: 'Ăn phở Thìn Lò Đúc',
        category: 'Ăn uống',
        categoryId: 'expense_food',
        amount: 65000,
        type: TransactionType.expense,
        walletSource: 'Tiền mặt',
        timestamp: now.subtract(const Duration(minutes: 30)),
        icon: Icons.restaurant,
      ),
      TransactionModel(
        id: 'tx_seed_cafe',
        title: 'Highlands Coffee',
        description: 'Highlands Coffee',
        category: 'Ăn uống',
        categoryId: 'expense_food',
        amount: 55000,
        type: TransactionType.expense,
        walletSource: 'Ví MoMo',
        timestamp: now.subtract(const Duration(hours: 3)),
        icon: Icons.local_cafe,
      ),
      TransactionModel(
        id: 'tx_seed_fuel',
        title: 'Đổ xăng Petrolimex',
        description: 'Đổ xăng Petrolimex',
        category: 'Di chuyển',
        categoryId: 'expense_transport',
        amount: 80000,
        type: TransactionType.expense,
        walletSource: 'Vietcombank',
        timestamp: now.subtract(const Duration(days: 1)),
        icon: Icons.local_gas_station,
      ),
      TransactionModel(
        id: 'tx_seed_salary',
        title: 'Tạm ứng lương tháng',
        description: 'Tạm ứng lương tháng',
        category: 'Lương',
        categoryId: 'income_salary',
        amount: 15000000,
        type: TransactionType.income,
        walletSource: 'Techcombank',
        timestamp: now.subtract(const Duration(days: 2)),
        icon: Icons.payments,
      ),
      TransactionModel(
        id: 'tx_seed_rent',
        title: 'Tiền thuê căn hộ',
        description: 'Tiền thuê căn hộ',
        category: 'Nhà ở & Tiện ích',
        categoryId: 'expense_home',
        amount: 4500000,
        type: TransactionType.expense,
        walletSource: 'Chuyển khoản',
        timestamp: now.subtract(const Duration(days: 4)),
        icon: Icons.home_work,
      ),
    ];
  }

  List<TransactionModel> get transactions =>
      List.unmodifiable(_currentTransactions);
  List<TransactionCategory> get categories => List.unmodifiable(_categories);

  List<TransactionModel> get _currentTransactions => _transactions
      .where((tx) => tx.ownerId == _currentUserId)
      .toList(growable: false);

  double get _profileOpeningBalance =>
      _currentUserId == defaultUserId ? _openingBalance : 0;
  double get _profileOpeningMonthlyIncome =>
      _currentUserId == defaultUserId ? _openingMonthlyIncome : 0;
  double get _profileOpeningMonthlyExpense =>
      _currentUserId == defaultUserId ? _openingMonthlyExpense : 0;

  double get currentBalance =>
      _profileOpeningBalance +
      _currentTransactions.fold<double>(
        0,
        (balance, tx) =>
            balance +
            (tx.type == TransactionType.income ? tx.amount : -tx.amount),
      );

  double get monthlyIncome =>
      _profileOpeningMonthlyIncome +
      _currentTransactions
          .where((tx) =>
              tx.type == TransactionType.income &&
              _isCurrentMonth(tx.timestamp))
          .fold<double>(0, (sum, tx) => sum + tx.amount);

  double get monthlyExpense =>
      _profileOpeningMonthlyExpense +
      _currentTransactions
          .where((tx) =>
              tx.type == TransactionType.expense &&
              _isCurrentMonth(tx.timestamp))
          .fold<double>(0, (sum, tx) => sum + tx.amount);

  double get monthlyBudgetLimit => 22000000;
  double get budgetProgressPercentage =>
      (monthlyExpense / monthlyBudgetLimit).clamp(0.0, 1.0);

  List<TransactionModel> listTransactions({
    TransactionType? type,
    String? categoryId,
    DateTime? from,
    DateTime? to,
    int offset = 0,
    int? limit,
  }) {
    final filtered = _transactions.where((tx) {
      if (tx.ownerId != _currentUserId) return false;
      if (type != null && tx.type != type) return false;
      if (categoryId != null &&
          categoryId.isNotEmpty &&
          tx.categoryId != categoryId) return false;
      if (from != null &&
          tx.timestamp.isBefore(DateTime(from.year, from.month, from.day)))
        return false;
      if (to != null &&
          tx.timestamp
              .isAfter(DateTime(to.year, to.month, to.day, 23, 59, 59, 999)))
        return false;
      return true;
    }).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final safeOffset = offset.clamp(0, filtered.length);
    final end = limit == null
        ? filtered.length
        : (safeOffset + limit).clamp(safeOffset, filtered.length);
    return List.unmodifiable(filtered.sublist(safeOffset, end));
  }

  TransactionModel? getTransaction(String id) {
    for (final tx in _transactions) {
      if (tx.id == id && tx.ownerId == _currentUserId) return tx;
    }
    return null;
  }

  Future<void> addTransaction(TransactionModel transaction) async {
    _validate(transaction);
    if (transaction.ownerId != _currentUserId)
      throw ArgumentError('Không thể tạo giao dịch cho tài khoản khác.');
    if (_transactions.any((tx) => tx.id == transaction.id))
      throw ArgumentError('Mã giao dịch đã tồn tại.');
    _transactions.add(transaction);
    try {
      await _persistTransactions();
    } catch (_) {
      _transactions.removeWhere((tx) => tx.id == transaction.id);
      rethrow;
    }
    notifyListeners();
  }

  Future<void> updateTransaction(String id, TransactionModel updated) async {
    final index = _transactions
        .indexWhere((tx) => tx.id == id && tx.ownerId == _currentUserId);
    if (index < 0) throw StateError('Không tìm thấy giao dịch.');
    final original = _transactions[index];
    final candidate = updated.copyWith(id: id, ownerId: _currentUserId);
    _validate(candidate);
    _transactions[index] = candidate;
    try {
      await _persistTransactions();
    } catch (_) {
      _transactions[index] = original;
      rethrow;
    }
    notifyListeners();
  }

  Future<void> deleteTransaction(String id) async {
    final index = _transactions
        .indexWhere((tx) => tx.id == id && tx.ownerId == _currentUserId);
    if (index < 0) throw StateError('Không tìm thấy giao dịch.');
    final removed = _transactions.removeAt(index);
    try {
      await _persistTransactions();
    } catch (_) {
      _transactions.insert(index, removed);
      rethrow;
    }
    notifyListeners();
  }

  Future<void> addCategory(String name, TransactionType type) async {
    final normalized = name.trim();
    if (normalized.isEmpty)
      throw ArgumentError('Tên danh mục không được để trống.');
    if (_categories.any((c) =>
        c.type == type && c.name.toLowerCase() == normalized.toLowerCase())) {
      throw ArgumentError('Danh mục này đã tồn tại.');
    }
    _categories.add(TransactionCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}',
      name: normalized,
      type: type,
    ));
    await _persistCategories();
    notifyListeners();
  }

  Future<void> updateCategory(String id, String name) async {
    final index = _categories.indexWhere((c) => c.id == id);
    if (index < 0) throw StateError('Không tìm thấy danh mục.');
    final normalized = name.trim();
    if (normalized.isEmpty)
      throw ArgumentError('Tên danh mục không được để trống.');
    final category = _categories[index];
    if (_categories.any((c) =>
        c.id != id &&
        c.type == category.type &&
        c.name.toLowerCase() == normalized.toLowerCase())) {
      throw ArgumentError('Danh mục này đã tồn tại.');
    }
    _categories[index] =
        TransactionCategory(id: id, name: normalized, type: category.type);
    for (var i = 0; i < _transactions.length; i++) {
      if (_transactions[i].categoryId == id) {
        _transactions[i] = _transactions[i].copyWith(category: normalized);
      }
    }
    await _persistCategories();
    await _persistTransactions();
    notifyListeners();
  }

  Future<void> deleteCategory(String id) async {
    if (_transactions.any((tx) => tx.categoryId == id)) {
      throw StateError('Danh mục đang được giao dịch sử dụng, không thể xóa.');
    }
    final index = _categories.indexWhere((c) => c.id == id);
    if (index < 0) throw StateError('Không tìm thấy danh mục.');
    final removed = _categories.removeAt(index);
    try {
      await _persistCategories();
    } catch (_) {
      _categories.insert(index, removed);
      rethrow;
    }
    notifyListeners();
  }

  void _validate(TransactionModel tx) {
    if (!tx.amount.isFinite || tx.amount <= 0)
      throw ArgumentError('Số tiền phải lớn hơn 0.');
    TransactionCategory? category;
    for (final candidate in _categories) {
      if (candidate.id == tx.categoryId) category = candidate;
    }
    if (category == null || category.type != tx.type)
      throw ArgumentError('Danh mục không hợp lệ cho loại giao dịch này.');
    if (tx.description.trim().isEmpty)
      throw ArgumentError('Vui lòng nhập mô tả giao dịch.');
    if (tx.timestamp.year < 1970 ||
        tx.timestamp.isAfter(DateTime.now().add(const Duration(days: 365)))) {
      throw ArgumentError('Ngày giao dịch không hợp lệ.');
    }
  }

  Future<void> _persistTransactions() async {
    await _preferences?.setStringList(
      _transactionsKey,
      _transactions.map((tx) => jsonEncode(_transactionToJson(tx))).toList(),
    );
  }

  Future<void> _persistCategories() async {
    await _preferences?.setStringList(_categoriesKey,
        _categories.map((c) => jsonEncode(c.toJson())).toList());
  }

  static bool _isCurrentMonth(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month;
  }

  static Map<String, Object?> _transactionToJson(TransactionModel tx) => {
        'id': tx.id,
        'title': tx.title,
        'category': tx.category,
        'categoryId': tx.categoryId,
        'description': tx.description,
        'note': tx.note,
        'ownerId': tx.ownerId,
        'amount': tx.amount,
        'type': tx.type.name,
        'walletSource': tx.walletSource,
        'timestamp': tx.timestamp.toIso8601String(),
        'badgeText': tx.badgeText,
      };

  static TransactionModel _transactionFromJson(Map<String, dynamic> json) =>
      TransactionModel(
        id: json['id'] as String,
        title: json['title'] as String,
        category: json['category'] as String,
        categoryId: json['categoryId'] as String? ?? '',
        description: json['description'] as String? ?? json['title'] as String,
        note: json['note'] as String? ?? '',
        ownerId: json['ownerId'] as String? ?? _legacyUserId,
        amount: (json['amount'] as num).toDouble(),
        type: TransactionType.values.byName(json['type'] as String),
        walletSource: json['walletSource'] as String? ?? 'Tiền mặt',
        timestamp: DateTime.parse(json['timestamp'] as String),
        badgeText: json['badgeText'] as String?,
        icon: json['type'] == TransactionType.income.name
            ? Icons.savings
            : Icons.payments,
      );
}
