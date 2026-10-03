import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../pro/presentation/checkout_screen.dart';

/// SplitBillScreen handles group expense sharing, VietQR links, and recurring bills.
/// Conforms to SRS Section 8.2 and 8.3 with local-first state handling.
class SplitBillScreen extends StatefulWidget {
  const SplitBillScreen({super.key});

  @override
  State<SplitBillScreen> createState() => _SplitBillScreenState();
}

class _SplitBillScreenState extends State<SplitBillScreen> {
  int _selectedTab = 0; // 0: Chia tiền, 1: Định kỳ, 2: Mục tiêu
  bool _tuanPaid = false;
  bool _huongPaid = true;
  bool _geminiReminderEnabled = false;

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
          'Kế hoạch & Chia tiền',
          style: TextStyle(color: AppColors.onSurface, fontSize: 17, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tab Switcher
            _buildTabSelector(),
            const SizedBox(height: 16),

            // 2 Quick Actions
            _buildQuickActionCards(context),
            const SizedBox(height: 20),

            // Active Split Session Card (BBQ Lan)
            _buildActiveSessionHeader(),
            const SizedBox(height: 10),
            _buildBbqSplitCard(context),
            const SizedBox(height: 12),
            _buildDalatCompletedCard(),
            const SizedBox(height: 24),

            // Recurring Smart Transactions (SRS 8.3)
            _buildRecurringHeader(),
            const SizedBox(height: 10),
            _buildGeminiProactiveBanner(),
            const SizedBox(height: 12),
            _buildRecurringList(context),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(child: _tabButton('Chia tiền', 0, icon: Icons.group_work)),
          Expanded(child: _tabButton('Định kỳ', 1, icon: Icons.sync, badge: '3')),
          Expanded(child: _tabButton('Mục tiêu', 2, icon: Icons.flag)),
        ],
      ),
    );
  }

  Widget _tabButton(String title, int index, {IconData? icon, String? badge}) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: isSelected ? Colors.white : AppColors.onSurfaceVariant),
              const SizedBox(width: 4),
            ],
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
              ),
            ),
            if (badge != null && !isSelected) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(badge, style: const TextStyle(fontSize: 9, color: AppColors.error, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCards(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_circle, color: AppColors.primary, size: 22),
                ),
                const SizedBox(height: 10),
                const Text('Tạo nhóm mới', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const Text('Chia bill ăn uống, du lịch', style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.secondary, AppColors.secondaryContainer],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: AppColors.secondary.withOpacity(0.25), blurRadius: 8),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.document_scanner, color: Colors.white, size: 22),
                ),
                const SizedBox(height: 10),
                const Row(
                  children: [
                    Text('Quét hóa đơn', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                    SizedBox(width: 4),
                    Text('AI OCR', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.secondaryFixed)),
                  ],
                ),
                const Text('Tự tách món từng người', style: TextStyle(fontSize: 11, color: Colors.white70)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveSessionHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Row(
          children: [
            Icon(Icons.groups, color: AppColors.primary, size: 18),
            SizedBox(width: 6),
            Text('Phiên chia tiền đang mở', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text('2 Phiên', style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
        ),
      ],
    );
  }

  Widget _buildBbqSplitCard(BuildContext context) {
    final recovered = 1800000 + (_huongPaid ? 600000 : 0) + (_tuanPaid ? 600000 : 0);
    final percent = (recovered / 3600000).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text('🎂', style: TextStyle(fontSize: 24)),
                  SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tiệc BBQ Sinh nhật Lan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      Text('Chủ nhật vừa qua • 6 thành viên', style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.tertiaryFixed,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('Đang thu', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.tertiary)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Đã thu hồi', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                    Text(
                      '${(recovered / 1000000).toStringAsFixed(1)} Tr / 3.6 Tr',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: percent,
                  minHeight: 6,
                  backgroundColor: AppColors.surfaceContainerHighest,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('600.000 ₫ / người', style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                    Text('${(percent * 100).toInt()}% Hoàn thành', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Member list
          _memberRow('Minh Quân (Bạn)', 'Chủ chi (Đã thanh toán)', true, isSelf: true),
          _memberRow('Hoàng Nam', 'Đã chuyển VietQR', true),
          _memberRow('Thanh Hương', _huongPaid ? 'Đã nhận tiền mặt' : 'Chưa nhận', _huongPaid, onToggle: (val) {
            setState(() => _huongPaid = val);
          }),
          _memberRow('Anh Tuấn', _tuanPaid ? 'Đã thanh toán' : 'Chưa thanh toán (Đã vào Sổ nợ)', _tuanPaid, isDebt: !_tuanPaid, onToggle: (val) {
            setState(() => _tuanPaid = val);
          }, onRemind: () {
            _showRemindBottomSheet(context);
          }),

          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.receipt_long, size: 16),
                label: const Text('Xem hóa đơn gốc', style: TextStyle(fontSize: 12)),
              ),
              TextButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã sao chép link VietQR động của nhóm BBQ!')),
                  );
                },
                icon: const Icon(Icons.qr_code_2, size: 16),
                label: const Text('Mã VietQR động nhóm', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _memberRow(String name, String sub, bool isPaid, {bool isSelf = false, bool isDebt = false, Function(bool)? onToggle, VoidCallback? onRemind}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.surfaceContainerHigh.withOpacity(0.5))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: isDebt ? AppColors.errorContainer : AppColors.surfaceContainerHigh,
                child: Text(name[0], style: TextStyle(fontSize: 12, color: isDebt ? AppColors.error : AppColors.primary, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  Text(sub, style: TextStyle(fontSize: 11, color: isDebt ? AppColors.error : AppColors.onSurfaceVariant)),
                ],
              ),
            ],
          ),
          Row(
            children: [
              const Text('600.000 ₫', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              if (onRemind != null && isDebt) ...[
                ElevatedButton(
                  onPressed: onRemind,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                  ),
                  child: const Text('Nhắc nợ', style: TextStyle(fontSize: 11)),
                ),
              ] else if (onToggle != null) ...[
                Switch.adaptive(
                  value: isPaid,
                  activeColor: AppColors.primary,
                  onChanged: onToggle,
                ),
              ] else ...[
                const Icon(Icons.check_circle, color: AppColors.primary, size: 18),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDalatCompletedCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Text('🌲', style: TextStyle(fontSize: 22)),
              SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Homestay Nhà Trên Đồi Đà Lạt', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  Text('4/4 thành viên đã trả • 4.800.000 ₫', style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primaryFixed.withOpacity(0.4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('Hoàn tất', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildRecurringHeader() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(Icons.event_repeat, color: AppColors.secondary, size: 18),
            SizedBox(width: 6),
            Text('Giao dịch định kỳ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        Text('Quản lý (8)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondary)),
      ],
    );
  }

  Widget _buildGeminiProactiveBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.surfaceContainerHighest, AppColors.surfaceContainerHigh],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: AppColors.secondary, shape: BoxShape.circle),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Cố vấn Gemini phát hiện', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                const SizedBox(height: 4),
                const Text(
                  'Bạn có khoản chuyển tiền thuê nhà 4.500.000 ₫ đều đặn vào ngày 28 hàng tháng. Bật nhắc tự động trước 3 ngày để chuẩn bị số dư an toàn?',
                  style: TextStyle(fontSize: 12, height: 1.3),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() => _geminiReminderEnabled = true);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đã bật nhắc nhở tiền thuê nhà trước 3 ngày!')),
                        );
                      },
                      icon: Icon(_geminiReminderEnabled ? Icons.check : Icons.alarm_on, size: 14),
                      label: Text(_geminiReminderEnabled ? 'Đã kích hoạt' : 'Bật nhắc nhở', style: const TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _geminiReminderEnabled ? AppColors.primary : AppColors.secondary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(onPressed: () {}, child: const Text('Để sau', style: TextStyle(fontSize: 11, color: AppColors.outline))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecurringList(BuildContext context) {
    return Column(
      children: [
        _recurringTile('Tiền thuê căn hộ', 'Còn 4 ngày • VPBank', '4.500.000 ₫', Icons.apartment, AppColors.tertiary, actionLabel: 'Chi ngay'),
        _recurringTile('Gói gia đình Netflix', 'Còn 8 ngày • Techcombank Visa', '65.000 ₫', Icons.movie, AppColors.error, subBadge: 'Tự động'),
        _recurringTile('Hóa đơn Internet VNPT', 'Kỳ tháng này đã hoàn tất', '275.000 ₫', Icons.wifi, AppColors.primary, isDone: true),
      ],
    );
  }

  Widget _recurringTile(String title, String sub, String amount, IconData icon, Color color, {String? actionLabel, String? subBadge, bool isDone = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                Text(sub, style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  decoration: isDone ? TextDecoration.lineThrough : null,
                  color: isDone ? AppColors.outline : AppColors.onSurface,
                ),
              ),
              if (actionLabel != null) ...[
                InkWell(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutScreen()));
                  },
                  child: Text(actionLabel, style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold)),
                ),
              ] else if (isDone) ...[
                const Text('✓ Xong', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold)),
              ] else if (subBadge != null) ...[
                Text(subBadge, style: const TextStyle(fontSize: 10, color: AppColors.outline)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showRemindBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.surfaceContainerHigh, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              const Text('Nhắc nợ thông minh (SRS 8.2)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.chat, color: Colors.blue),
                title: const Text('Nhắc qua Zalo (1-chạm)'),
                subtitle: const Text('Mở tin nhắn điền sẵn kèm link VietQR động'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã gửi tin nhắn nhắc nợ và link VietQR tới Zalo của Anh Tuấn!')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.sms, color: AppColors.primary),
                title: const Text('Nhắc qua tin nhắn SMS'),
                subtitle: const Text('Soạn sẵn cú pháp kèm số tài khoản'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã mở SMS gửi tới Anh Tuấn!')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
