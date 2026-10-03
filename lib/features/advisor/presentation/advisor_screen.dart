import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../quick_record/presentation/quick_record_screen.dart';

/// AdvisorScreen renders financial insights, spending structure (Donut chart),
/// and predictive 4-week cash flow forecasts generated on-device.
class AdvisorScreen extends StatefulWidget {
  const AdvisorScreen({super.key});

  @override
  State<AdvisorScreen> createState() => _AdvisorScreenState();
}

class _AdvisorScreenState extends State<AdvisorScreen> {
  int _selectedPeriod = 1; // 0: Tuần này, 1: Tháng 06/2026, 2: 3 Tháng, 3: Năm 2026

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface.withOpacity(0.9),
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text(
          'Báo cáo & Cố vấn AI',
          style: TextStyle(color: AppColors.onSurface, fontSize: 17, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Period Selector
            _buildPeriodSelector(),
            const SizedBox(height: 16),

            // AI Advisor Hero Banner
            _buildAdvisorHeroBanner(),
            const SizedBox(height: 16),

            // Category Breakdown (Donut Chart representation)
            _buildCategoryBreakdownCard(),
            const SizedBox(height: 16),

            // Cashflow & AI Forecast Bar Chart
            _buildForecastChartCard(),
            const SizedBox(height: 16),

            // Chat with AI CTA
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const QuickRecordScreen()));
                },
                icon: const Icon(Icons.forum, size: 20),
                label: const Text('Trò chuyện chi tiết với Cố vấn AI', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                ),
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    final periods = ['Tuần này', 'Tháng 06/2026', '3 Tháng', 'Năm 2026'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: periods.asMap().entries.map((entry) {
          final isSelected = _selectedPeriod == entry.key;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedPeriod = entry.key),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.surfaceContainerLowest : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)] : null,
                ),
                child: Text(
                  entry.value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAdvisorHeroBanner() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.secondary, AppColors.secondaryContainer, AppColors.primaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: AppColors.secondary.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.smart_toy, size: 14, color: AppColors.tertiaryFixed),
                    SizedBox(width: 4),
                    Text('Phân tích chuyên sâu bởi Gemini AI', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const Icon(Icons.auto_awesome, color: Colors.white70, size: 18),
            ],
          ),
          const SizedBox(height: 12),
          const Text('XU HƯỚNG TỔNG THỂ', style: TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          const Text(
            'Tổng chi tiêu tháng này tăng 18% so với tháng trước.',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, height: 1.3),
          ),
          const SizedBox(height: 14),

          // 3 Actionable Cards
          _adviceCard('⚠️ Ăn uống (+40%)', 'Cảnh báo', 'Chi tiêu 4.800.000 ₫, vượt 15% hạn mức dự kiến. Khuyên bạn giảm bớt ăn ngoài ~500k tuần này.', AppColors.error),
          const SizedBox(height: 8),
          _adviceCard('✅ Di chuyển (-10%)', 'Tích cực', 'Tiết kiệm được 320.000 ₫ nhờ đi xe buýt điện. Rất tốt, hãy duy trì!', AppColors.primaryFixed),
          const SizedBox(height: 8),
          _adviceCard('🔮 Dự báo tháng tới (Forecast)', 'Ước tính AI', 'Dự kiến chi tiêu khoảng 8.200.000 ₫, danh mục có rủi ro cao là Mua sắm.', AppColors.tertiaryFixed),
        ],
      ),
    );
  }

  Widget _adviceCard(String title, String badge, String body, Color badgeColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: badgeColor == AppColors.error ? Colors.white : AppColors.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(body, style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.3)),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdownCard() {
    final categories = [
      {'title': 'Ăn uống', 'percent': '35%', 'amount': '5.012.000 ₫', 'badge': '+40% vs dự toán', 'color': AppColors.tertiary, 'icon': Icons.restaurant},
      {'title': 'Nhà ở & Tiện ích', 'percent': '31%', 'amount': '4.500.000 ₫', 'badge': 'Ổn định', 'color': AppColors.secondary, 'icon': Icons.apartment},
      {'title': 'Mua sắm & Tiêu dùng', 'percent': '18%', 'amount': '2.577.000 ₫', 'badge': 'Cần chú ý', 'color': AppColors.error, 'icon': Icons.shopping_bag},
      {'title': 'Di chuyển', 'percent': '10%', 'amount': '1.432.000 ₫', 'badge': '-10% tiết kiệm', 'color': AppColors.primary, 'icon': Icons.directions_bus},
      {'title': 'Khác', 'percent': '6%', 'amount': '799.000 ₫', 'badge': 'Bình thường', 'color': AppColors.outline, 'icon': Icons.category},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cơ cấu chi tiêu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('Tổng chi: 14.320.000 ₫', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                ],
              ),
              Icon(Icons.filter_list, color: AppColors.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 16),

          // Center Donut badge representation
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: CircularProgressIndicator(
                    value: 0.35,
                    strokeWidth: 16,
                    backgroundColor: AppColors.surfaceContainerHigh,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.tertiary),
                  ),
                ),
                const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('THÁNG 06', style: TextStyle(fontSize: 10, color: AppColors.outline, fontWeight: FontWeight.bold)),
                    Text('14,32M', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.onSurface)),
                    Text('12 danh mục', style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Detail rows
          Column(
            children: categories.map((cat) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (cat['color'] as Color).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(cat['icon'] as IconData, color: cat['color'] as Color, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cat['title'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          Text('${cat['percent']} ngân sách', style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(cat['amount'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        Text(cat['badge'] as String, style: TextStyle(fontSize: 10, color: cat['color'] as Color, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildForecastChartCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dòng tiền & Dự báo AI', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  Text('Chi tiêu thực tế đối chiếu dự báo', style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                ],
              ),
              Row(
                children: [
                  _legendDot(AppColors.primary, 'Thực tế'),
                  const SizedBox(width: 8),
                  _legendDot(AppColors.secondaryContainer, 'Dự báo'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 4-Week Comparison Bars
          SizedBox(
            height: 120,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _barPair('Tuần 1', 55, 50),
                _barPair('Tuần 2', 82, 65),
                _barPair('Tuần 3', 68, 70),
                _barPair('Tuần 4', 40, 60, isCurrent: true),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.trending_up, color: AppColors.secondary, size: 16),
                    SizedBox(width: 6),
                    Text('Dự báo tháng:', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                  ],
                ),
                Text('~ 14.850.000 ₫', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String text) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant)),
      ],
    );
  }

  Widget _barPair(String label, double actualH, double forecastH, {bool isCurrent = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              width: 14,
              height: actualH,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 14,
              height: forecastH,
              decoration: BoxDecoration(
                color: AppColors.secondaryContainer.withOpacity(0.8),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
            color: isCurrent ? AppColors.primary : AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
