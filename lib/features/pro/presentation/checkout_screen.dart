import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// CheckoutScreen handles payment method selection (VietQR, MoMo, Card, Apple Pay)
/// and voucher application for Túi Khôn PRO subscription.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String _selectedPayment = 'vietqr'; // 'vietqr', 'momo', 'atm', 'card', 'inapp'
  bool _voucherApplied = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface.withOpacity(0.9),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Thanh Toán Gói Pro', style: TextStyle(color: AppColors.onSurface, fontSize: 16, fontWeight: FontWeight.bold)),
            Row(
              children: [
                Icon(Icons.verified_user, color: AppColors.primary, size: 12),
                SizedBox(width: 4),
                Text('BẢO MẬT 256-BIT SSL / PCI-DSS', style: TextStyle(color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Emerald Hero Summary Card
                _buildHeroPlanCard(),
                const SizedBox(height: 16),

                // Voucher / Promo Code Box
                _buildPromoSection(),
                const SizedBox(height: 20),

                // Payment Methods
                const Text('Phương thức thanh toán', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                _buildPaymentOptions(),
                const SizedBox(height: 20),

                // Pricing Summary
                _buildOrderSummaryCard(),
                const SizedBox(height: 16),

                // Trust badges
                _buildSecurityTrustRow(),
                const SizedBox(height: 100),
              ],
            ),
          ),

          // Bottom sticky button
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomConfirmBar(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroPlanCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withOpacity(0.25), blurRadius: 14),
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
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text('TIẾT KIỆM 40% • 7 NGÀY DÙNG THỬ', style: TextStyle(color: AppColors.primaryFixed, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              const Row(
                children: [
                  Text('Đổi gói', style: TextStyle(color: Colors.white, fontSize: 12)),
                  Icon(Icons.tune, color: Colors.white, size: 14),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Gói Năm (12 Tháng) 👑', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const Text('Túi Khôn PRO Member • Cố Vấn Tài Chính AI Riêng 24/7', style: TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('468.000 ₫', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                  SizedBox(width: 8),
                  Text('780.000 ₫', style: TextStyle(color: Colors.white60, fontSize: 13, decoration: TextDecoration.lineThrough)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('~39.000 ₫/tháng', style: TextStyle(color: AppColors.primaryFixed, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPromoSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Mã Ưu Đãi / Khuyến Mãi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_voucherApplied) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.check_circle, color: AppColors.primary, size: 18),
                      SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('FINTECHPRO', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary)),
                          Text('Giảm thêm 50.000 ₫ cho hội viên mới', style: TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant)),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => setState(() => _voucherApplied = false),
                  ),
                ],
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
                    child: const TextField(
                      decoration: InputDecoration(hintText: 'Nhập mã (vd: FINTECHPRO)', border: InputBorder.none, hintStyle: TextStyle(fontSize: 12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => setState(() => _voucherApplied = true),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                  child: const Text('Áp dụng'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentOptions() {
    final options = [
      {'key': 'vietqr', 'title': 'Mã VietQR Siêu Tốc 24/7', 'sub': 'Miễn phí giao dịch • Tự động kích hoạt trong 3s', 'badge': 'Khuyên dùng'},
      {'key': 'momo', 'title': 'Ví MoMo / ZaloPay / ShopeePay', 'sub': 'Liên kết tài khoản ví, thanh toán 1-chạm', 'badge': null},
      {'key': 'atm', 'title': 'Thẻ ATM Nội Địa / Internet Banking', 'sub': 'Hơn 40 ngân hàng liên minh Napas', 'badge': null},
      {'key': 'card', 'title': 'Thẻ Quốc Tế (Visa, Master, JCB)', 'sub': 'Bảo vệ gian lận 3D-Secure 2.0', 'badge': null},
      {'key': 'inapp', 'title': 'Apple Pay / Google Play', 'sub': 'Xác thực sinh trắc học Face ID / Touch ID', 'badge': null},
    ];

    return Column(
      children: options.map((opt) {
        final isSelected = _selectedPayment == opt['key'];
        return GestureDetector(
          onTap: () => setState(() => _selectedPayment = opt['key'] as String),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isSelected ? AppColors.primary : AppColors.outlineVariant.withOpacity(0.3), width: isSelected ? 2 : 1),
            ),
            child: Row(
              children: [
                Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_off, color: isSelected ? AppColors.primary : AppColors.outline, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(opt['title'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          if (opt['badge'] != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: AppColors.primaryFixed, borderRadius: BorderRadius.circular(6)),
                              child: Text(opt['badge'] as String, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.primary)),
                            ),
                          ],
                        ],
                      ),
                      Text(opt['sub'] as String, style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOrderSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Chi tiết thanh toán', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _summaryRow('Giá niêm yết (12 tháng PRO)', '780.000 ₫'),
          _summaryRow('Ưu đãi đăng ký năm (-40%)', '-312.000 ₫', color: AppColors.primary),
          if (_voucherApplied) _summaryRow('Mã voucher (FINTECHPRO)', '-50.000 ₫', color: AppColors.primary),
          _summaryRow('Kỳ dùng thử miễn phí', '7 ngày đầu (0 ₫)', color: AppColors.primary),
          const Divider(height: 20),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tổng thanh toán hôm nay', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  Text('Bắt đầu tính phí sau 7 ngày', style: TextStyle(fontSize: 10, color: AppColors.outline)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('0 ₫', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.primary)),
                  Text('Sau 7 ngày: 418.000 ₫/năm', style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color ?? AppColors.onSurface)),
        ],
      ),
    );
  }

  Widget _buildSecurityTrustRow() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock, size: 14, color: AppColors.outline),
        SizedBox(width: 4),
        Text('PCI-DSS Level 1', style: TextStyle(fontSize: 10, color: AppColors.outline)),
        SizedBox(width: 14),
        Icon(Icons.shield, size: 14, color: AppColors.outline),
        SizedBox(width: 4),
        Text('256-Bit SSL', style: TextStyle(fontSize: 10, color: AppColors.outline)),
        SizedBox(width: 14),
        Icon(Icons.cached, size: 14, color: AppColors.outline),
        SizedBox(width: 4),
        Text('Hoàn tiền 14 ngày', style: TextStyle(fontSize: 10, color: AppColors.outline)),
      ],
    );
  }

  Widget _buildBottomConfirmBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, -4))]),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('🎉 Chúc mừng! Bạn đã kích hoạt thành công 7 ngày dùng thử Túi Khôn PRO.')),
              );
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            icon: const Icon(Icons.lock, size: 18),
            label: const Text('Xác Nhận & Dùng Thử 0 ₫ (7 Ngày)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ),
    );
  }
}
