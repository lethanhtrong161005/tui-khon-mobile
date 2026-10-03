import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../models/transaction_model.dart';

/// RecentTransactionsSection renders the PRM-3 "Recent Transactions" block
/// faithfully matching the Stitch HTML design (rounded-2xl icon containers,
/// semantic badges including "Hóa đơn" with receipt icon, date, and +/- amount).
class RecentTransactionsSection extends StatelessWidget {
  final List<TransactionModel> transactions;
  final int totalCount;
  final VoidCallback onTapSeeAll;
  final ValueChanged<TransactionModel> onTapTransaction;

  const RecentTransactionsSection({
    super.key,
    required this.transactions,
    required this.totalCount,
    required this.onTapSeeAll,
    required this.onTapTransaction,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text(
                  'Giao dịch gần đây',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$totalCount',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: onTapSeeAll,
              child: const Text(
                'Xem tất cả',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (transactions.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 36,
                  color: AppColors.outline,
                ),
                SizedBox(height: 8),
                Text(
                  'Chưa có giao dịch nào trong kỳ này',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            children: transactions.map((tx) {
              return TransactionListTile(
                transaction: tx,
                onTap: () => onTapTransaction(tx),
              );
            }).toList(),
          ),
      ],
    );
  }
}

/// Reusable Stitch-styled transaction item tile used in both Recent Transactions
/// and the full TransactionsScreen.
class TransactionListTile extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback? onTap;

  const TransactionListTile({
    super.key,
    required this.transaction,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.isIncome;
    final formattedAmount = CurrencyFormatter.formatVND(
      transaction.signedAmount,
      showSign: true,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Category Icon Container (w-11 h-11 rounded-2xl in Stitch)
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: transaction.categoryContainerColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    transaction.icon,
                    color: transaction.categoryAccentColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),

                // Title, Category, Time & Badge
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        children: [
                          Text(
                            '${transaction.category} • ${transaction.formattedTimeLabel()}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                          if (transaction.badgeText != null)
                            _buildBadge(transaction.badgeText!),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Amount & Wallet Source + Income/Expense Indicator
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isIncome ? Icons.north_east : Icons.south_west,
                          size: 12,
                          color: isIncome
                              ? AppColors.primary
                              : AppColors.error,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          formattedAmount,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isIncome
                                ? AppColors.primary
                                : AppColors.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      transaction.walletSource,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String badge) {
    if (badge == 'Hóa đơn') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.receipt_long,
            size: 12,
            color: AppColors.primary,
          ),
          const SizedBox(width: 2),
          Text(
            badge,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      );
    }

    final isRecurring = badge == 'Định kỳ';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: isRecurring
            ? AppColors.surfaceContainerHigh
            : AppColors.secondaryFixed,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        badge,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: isRecurring
              ? AppColors.onSurfaceVariant
              : AppColors.secondary,
        ),
      ),
    );
  }
}
