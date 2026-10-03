import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../models/dashboard_summary_model.dart';
import '../../models/transaction_model.dart';

/// CategorySummaryCard displays the PRM-3 "Category Summary" section on Dashboard.
/// Allows toggling between Chi tiêu (Expense) and Thu nhập (Income) categories,
/// showing a stacked proportion bar and per-category breakdown rows.
class CategorySummaryCard extends StatelessWidget {
  final List<CategorySummaryItem> items;
  final TransactionType selectedType;
  final DashboardPeriod period;
  final ValueChanged<TransactionType> onSelectType;
  final VoidCallback? onTapViewAnalytics;

  const CategorySummaryCard({
    super.key,
    required this.items,
    required this.selectedType,
    required this.period,
    required this.onSelectType,
    this.onTapViewAnalytics,
  });

  @override
  Widget build(BuildContext context) {
    final totalAmount = items.fold(0.0, (sum, item) => sum + item.amount);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Expense / Income toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.pie_chart_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tóm tắt danh mục',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSurface,
                        ),
                      ),
                      Text(
                        '${period.subtitle} • ${CurrencyFormatter.formatVND(totalAmount)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _typeChip(
                      label: 'Chi tiêu',
                      isSelected: selectedType == TransactionType.expense,
                      onTap: () => onSelectType(TransactionType.expense),
                    ),
                    _typeChip(
                      label: 'Thu nhập',
                      isSelected: selectedType == TransactionType.income,
                      onTap: () => onSelectType(TransactionType.income),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'Chưa có dữ liệu ${selectedType == TransactionType.expense ? "chi tiêu" : "thu nhập"} trong kỳ này',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else ...[
            // Multi-segment stacked bar showing category distribution
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: items.map((item) {
                    final flex = (item.percentage * 1000).round().clamp(1, 1000);
                    return Expanded(
                      flex: flex,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        color: item.color,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Category rows
            ...items.map((item) => _buildCategoryRow(item)),

            if (onTapViewAnalytics != null) ...[
              const SizedBox(height: 4),
              InkWell(
                onTap: onTapViewAnalytics,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Xem phân tích biểu đồ chi tiết',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 11,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _typeChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.surfaceContainerLowest
              : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryRow(CategorySummaryItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: item.containerColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, color: item.color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      item.category,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '(${item.transactionCount} GD)',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: item.percentage,
                    minHeight: 4,
                    backgroundColor: AppColors.surfaceContainerHigh,
                    valueColor: AlwaysStoppedAnimation<Color>(item.color),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyFormatter.formatVND(item.amount),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                ),
              ),
              Text(
                '${item.percentInt}% tổng ${item.type == TransactionType.expense ? "chi" : "thu"}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: item.color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
