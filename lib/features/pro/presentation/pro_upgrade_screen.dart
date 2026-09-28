import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import 'checkout_screen.dart';

/// ProUpgradeScreen renders the Túi Khôn PRO subscription paywall.
/// Presents 1-Year (40% OFF), 3-Month, and 1-Month tiers with side-by-side perk comparison.
class ProUpgradeScreen extends StatefulWidget {
  const ProUpgradeScreen({super.key});

  @override
  State<ProUpgradeScreen> createState() => _ProUpgradeScreenState();
}

class _ProUpgradeScreenState extends State<ProUpgradeScreen> {
  String _selectedPlan = 'annual'; // 'annual', 'quarterly', 'monthly'

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.onSurface, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          children: [
            Icon(Icons.account_balance_wallet, color: AppColors.primary, size: 20),
            SizedBox(width: 6),
            Text('Túi Khôn PRO', style: TextStyle(color: AppColors.onSurface, fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đang kiểm tra gói mua của bạn...')),
              );
            },
            child: const Text('Khôi phục', style: TextStyle(color: AppColors.secondary, fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                // Emerald Hero Showcase
                _buildHeroCard(),
                const SizedBox(height: 18),

                // Pricing Plan Cards
                _buildPlanSelectionHeader(),
                const SizedBox(height: 10),
                _buildAnnualPlanCard(),
                const SizedBox(height: 10),
                _buildQuarterlyPlanCard(),
                const SizedBox(height: 10),
                _buildMonthlyPlanCard(),
                const SizedBox(height: 20),

                // Perks side-by-side comparison
                _buildPerksComparisonCard(),
                const SizedBox(height: 14),

                // Social proof testimonial
                _buildSocialProofCard(),
                const SizedBox(height: 14),

                // Guarantee trust pills
                _buildTrustBadges(),
                const SizedBox(height: 120), // Bottom space for fixed CTA bar
              ],
            ),
          ),

          // Fixed bottom CTA bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomCtaBar(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF004E35), Color(0xFF006948), Color(0xFF044C35)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: const Color(0xFF004E35).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFFBE5B), Color(0xFFFFFFFF)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.workspace_premium, color: Color(0xFF004A32), size: 32),
          ),
          const SizedBox(height: 12),
          const Text(
            'Mở Khóa Toàn Năng Tài Chính',
            style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text(
            'Cố vấn tài chính AI 24/7, bóc tách hóa đơn siêu tốc & dự báo dòng tiền cá nhân hóa.',
            style: TextStyle(color: Color(0xFFD1FAE5), fontSize: 13, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              _heroPill('✨ AI Gemini Không Giới Hạn'),
              _heroPill('⚡ Scan OCR Không Giới Hạn'),
              _heroPill('🛡️ Bảo Mật E2E Ngân Hàng'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildPlanSelectionHeader() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Chọn gói thành viên', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        Text('7 ngày dùng thử miễn phí', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
      ],
    );
  }

  Widget _buildAnnualPlanCard() {
    final isSelected = _selectedPlan == 'annual';
    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = 'annual'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.outlineVariant.withOpacity(0.4), width: isSelected ? 2 : 1),
          boxShadow: isSelected ? [BoxShadow(color: AppColors.primary.withOpacity(0.15), blurRadius: 12)] : null,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFFD97706), Color(0xFFF59E0B)]),
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('TIẾT KIỆM 40% • ĐƯỢC CHỌN NHIỀU NHẤT', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  Text('TIẾT KIỆM NHẤT', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(isSelected ? Icons.check_circle : Icons.radio_button_unchecked, color: isSelected ? AppColors.primary : AppColors.outline),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Gói 1 Năm', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        Text('🎁 Dùng thử 7 ngày miễn phí, thanh toán sau', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text('39.000 ₫', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary)),
                          Text('/tháng', style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                        ],
                      ),
                      Text('468.000 ₫/năm', style: TextStyle(fontSize: 11, color: AppColors.outline)),
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

  Widget _buildQuarterlyPlanCard() {
    final isSelected = _selectedPlan == 'quarterly';
    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = 'quarterly'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.outlineVariant.withOpacity(0.4), width: isSelected ? 2 : 1),
        ),
        child: Row(
          children: [
            Icon(isSelected ? Icons.check_circle : Icons.radio_button_unchecked, color: isSelected ? AppColors.primary : AppColors.outline),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Gói 3 Tháng', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  Text('149.000 ₫ / 3 tháng', style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                ],
              ),
            ),
            const Text('49.000 ₫/tháng', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyPlanCard() {
    final isSelected = _selectedPlan == 'monthly';
    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = 'monthly'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.outlineVariant.withOpacity(0.4), width: isSelected ? 2 : 1),
        ),
        child: Row(
          children: [
            Icon(isSelected ? Icons.check_circle : Icons.radio_button_unchecked, color: isSelected ? AppColors.primary : AppColors.outline),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Gói 1 Tháng', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  Text('Linh hoạt gia hạn hàng tháng', style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                ],
              ),
            ),
            const Text('65.000 ₫/tháng', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildPerksComparisonCard() {
    final perks = [
      {'title': 'Trợ lý AI Gemini Flash', 'std': 'Standard: 50 lượt/ngày', 'pro': 'Không giới hạn 24/7', 'icon': Icons.psychology},
      {'title': 'Scan Hóa đơn AI OCR', 'std': 'Standard: 20 bill/ngày', 'pro': 'Bóc tách siêu tốc', 'icon': Icons.document_scanner},
      {'title': 'Dự báo dòng tiền AI', 'std': 'Standard: Báo cáo cơ bản', 'pro': 'Trước 30–90 ngày', 'icon': Icons.query_stats},
      {'title': 'Chia tiền nhóm (Split Bill)', 'std': 'Standard: Tối đa 3 phiên', 'pro': 'Không giới hạn', 'icon': Icons.groups},
      {'title': 'Đồng bộ & Xuất báo cáo', 'std': 'Standard: 1 thiết bị', 'pro': 'Web + Mobile + Tablet', 'icon': Icons.cloud_sync},
      {'title': 'Chăm sóc khách hàng VIP', 'std': 'Standard: Qua email', 'pro': '1-on-1 trong 15p', 'icon': Icons.support_agent},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Đặc quyền PRO Member', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Text('Bản thường', style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                  SizedBox(width: 8),
                  Text('PRO', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const Divider(height: 24),
          Column(
            children: perks.map((p) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  children: [
                    Icon(p['icon'] as IconData, size: 20, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p['title'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          Text(p['std'] as String, style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: AppColors.primaryFixed.withOpacity(0.4), borderRadius: BorderRadius.circular(10)),
                      child: Text(p['pro'] as String, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
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

  Widget _buildSocialProofCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: NetworkImage('https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150'),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.star, color: Colors.amber, size: 14),
                    Icon(Icons.star, color: Colors.amber, size: 14),
                    Icon(Icons.star, color: Colors.amber, size: 14),
                    Icon(Icons.star, color: Colors.amber, size: 14),
                    Icon(Icons.star, color: Colors.amber, size: 14),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  '"Túi Khôn PRO giúp mình kiểm soát dòng tiền kinh doanh và tiết kiệm 4.5 triệu mỗi tháng!"',
                  style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                ),
                Text('Phương Anh • Nhà sáng lập F&B Hà Nội', style: TextStyle(fontSize: 10, color: AppColors.outline)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustBadges() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Text('0 ₫ Hôm Nay\nDùng thử 7 ngày', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        Text('Hủy bất kỳ lúc nào\nKhông ràng buộc', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        Text('Chuẩn PCI-DSS\nLevel 1 Bank Grade', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildBottomCtaBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        border: Border(top: BorderSide(color: AppColors.surfaceContainerHigh)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutScreen()));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.stars, size: 18),
                    SizedBox(width: 6),
                    Text('Bắt Đầu Dùng Thử 7 Ngày Miễn Phí', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
                Text('Sau đó 468.000 ₫/năm • Hủy bất cứ lúc nào', style: TextStyle(fontSize: 10, color: Color(0xFFD1FAE5))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
