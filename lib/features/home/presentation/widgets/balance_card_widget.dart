import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../models/dashboard_summary_model.dart';

/// BalanceCardWidget renders the Stitch-designed Emerald gradient balance card
/// displaying Total Balance (= Total Income - Total Expense), Period selector,
/// and Period Income / Expense summary pills (PRM-3 Sections 1, 2, 3).
class BalanceCardWidget extends StatelessWidget {
  final DashboardSummary summary;
  final bool isBalanceVisible;
  final VoidCallback onToggleVisibility;
  final ValueChanged<DashboardPeriod> onSelectPeriod;

  const BalanceCardWidget({
    super.key,
    required this.summary,
    required this.isBalanceVisible,
    required this.onToggleVisibility,
    required this.onSelectPeriod,
  });

  @override
  Widget build(BuildContext context) {
    final netFlow = summary.periodNetFlow;
    final isNetPositive = netFlow >= 0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Subtle tactile geometric pattern from Stitch HTML
            Positioned(
              right: -40,
              bottom: -40,
              child: IgnorePointer(
                child: Container(
                  width: 176,
                  height: 176,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 48,
              top: 0,
              child: IgnorePointer(
                child: Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Card Top: Security Badge & Sync Status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.primaryFixed,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'ĐÃ ĐỒNG BỘ TRỰC TUYẾN',
                              style: TextStyle(
                                color: AppColors.primaryFixed,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified_user,
                              color: Colors.white70,
                              size: 13,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'RLS SECURED',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Main Balance Display with Mask Toggle (Balance = Total Income - Total Expense)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Text(
                            'Số dư khả dụng',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(width: 6),
                          Text(
                            '(Tổng Thu - Tổng Chi)',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: onToggleVisibility,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Icon(
                            isBalanceVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.white70,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isBalanceVisible
                        ? CurrencyFormatter.formatVND(summary.totalBalance)
                        : '••••••••',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Current Period Filter Selector (PRM-3 Section 3: Current period)
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: DashboardPeriod.values.map((period) {
                        final isSelected = summary.period == period;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => onSelectPeriod(period),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white.withValues(alpha: 0.2)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Text(
                                period.label,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white70,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Period Income / Expense Dual Pills (PRM-3 Section 3)
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryFixed.withValues(
                                    alpha: 0.2,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.arrow_upward,
                                  color: AppColors.primaryFixed,
                                  size: 14,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      summary.period ==
                                              DashboardPeriod.thisMonth
                                          ? 'Thu nhập tháng'
                                          : 'Tổng thu (${summary.period.label})',
                                      style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 10,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      isBalanceVisible
                                          ? CurrencyFormatter.formatVND(
                                              summary.periodIncome,
                                              showSign: true,
                                            )
                                          : '••••••',
                                      style: const TextStyle(
                                        color: AppColors.primaryFixed,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.errorContainer.withValues(
                                    alpha: 0.3,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.arrow_downward,
                                  color: AppColors.errorContainer,
                                  size: 14,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      summary.period ==
                                              DashboardPeriod.thisMonth
                                          ? 'Đã chi tiêu'
                                          : 'Tổng chi (${summary.period.label})',
                                      style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 10,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      isBalanceVisible
                                          ? CurrencyFormatter.formatVND(
                                              -summary.periodExpense,
                                              showSign: true,
                                            )
                                          : '••••••',
                                      style: const TextStyle(
                                        color: AppColors.errorContainer,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Period Summary Footer (Net cashflow of current period)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tóm tắt kỳ (${summary.period.subtitle}):',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        isBalanceVisible
                            ? CurrencyFormatter.formatVND(
                                netFlow,
                                showSign: true,
                              )
                            : '••••••',
                        style: TextStyle(
                          color: isNetPositive
                              ? AppColors.primaryFixed
                              : AppColors.errorContainer,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
