import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../quick_record/presentation/quick_record_screen.dart';
import '../../split_bill/presentation/split_bill_screen.dart';
import '../../advisor/presentation/advisor_screen.dart';
import '../../pro/presentation/pro_upgrade_screen.dart';
import '../../profile/presentation/prm4_profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Local state toggles
  bool _isBalanceVisible = true;
  int _currentNavIndex = 0;

  // Wallet figures
  final double _balance = 42850000;
  final double _monthlyIncome = 28500000;
  final double _monthlyExpense = 14320000;
  final double _monthlyLimit = 22000000;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: false, // Allows the header blur to flow behind status bar
        child: Stack(
          children: [
            // Scrollable Content
            CustomScrollView(
              slivers: [
                _buildSliverAppBar(context),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        _buildProBanner(context),
                        const SizedBox(height: 12),
                        _buildBalanceCard(),
                        const SizedBox(height: 16),
                        _buildGeminiInsightCard(context),
                        const SizedBox(height: 16),
                        _buildQuickActionGrid(context),
                        const SizedBox(height: 16),
                        _buildBudgetProgressBar(),
                        const SizedBox(height: 20),
                        _buildRecentTransactionsHeader(),
                        const SizedBox(height: 8),
                        _buildRecentTransactionsList(),
                        const SizedBox(height: 100), // Space for floating bottom nav
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Floating Bottom Navigation Bar
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _buildFloatingBottomNav(context),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the top app bar with avatar, PRO upgrade pill, and notification icon.
  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppColors.surface.withOpacity(0.85),
      elevation: 0,
      expandedHeight: 64,
      automaticallyImplyLeading: false,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const Prm4ProfileScreen()));
            },
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                children: [
                  Stack(
                    children: [
                      const CircleAvatar(
                        radius: 20,
                        backgroundImage: NetworkImage(
                          'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=150',
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Minh Quân',
                        style: TextStyle(
                          color: AppColors.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Tài khoản & Cài đặt ›',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProUpgradeScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.outlineVariant.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.workspace_premium, size: 16, color: AppColors.tertiary),
                      SizedBox(width: 4),
                      Text(
                        'Nâng cấp ',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.onSurface),
                      ),
                      Text(
                        'PRO',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      Icon(Icons.chevron_right, size: 14, color: AppColors.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none, color: AppColors.onSurface),
                    onPressed: () => _showNotificationBottomSheet(context),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      child: const Text(
                        '3',
                        style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Small promotional strip leading to PRO features
  Widget _buildProBanner(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProUpgradeScreen())),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.outlineVariant.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryFixed.withOpacity(0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.stars, color: AppColors.primary, size: 16),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Trải nghiệm toàn diện với Túi Khôn PRO',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.onSurface),
                ),
              ],
            ),
            const Row(
              children: [
                Text(
                  'Nâng cấp',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                Icon(Icons.chevron_right, size: 14, color: AppColors.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Main emerald card holding balance, sync state, and monthly summary
  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Security and Sync Indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified_user, color: Colors.white70, size: 13),
                    SizedBox(width: 4),
                    Text(
                      'RLS SECURED',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Balance Display with Mask Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Số dư khả dụng',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  _isBalanceVisible ? Icons.visibility : Icons.visibility_off,
                  color: Colors.white70,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _isBalanceVisible = !_isBalanceVisible;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _isBalanceVisible ? CurrencyFormatter.formatVND(_balance) : '••••••••',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),

          // Monthly Dual Pills
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryFixed.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_upward, color: AppColors.primaryFixed, size: 14),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Thu nhập tháng', style: TextStyle(color: Colors.white60, fontSize: 10)),
                          Text(
                            CurrencyFormatter.formatVND(_monthlyIncome, showSign: true),
                            style: const TextStyle(
                              color: AppColors.primaryFixed,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
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
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.errorContainer.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_downward, color: AppColors.errorContainer, size: 14),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Đã chi tiêu', style: TextStyle(color: Colors.white60, fontSize: 10)),
                          Text(
                            CurrencyFormatter.formatVND(_monthlyExpense, showSign: true),
                            style: const TextStyle(
                              color: AppColors.errorContainer,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// AI Proactive Advisory Card
  Widget _buildGeminiInsightCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Gemini khuyên bạn',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.secondary),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryFixed,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Thời gian thực',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.secondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 13, color: AppColors.onSurface, height: 1.4),
                    children: [
                      TextSpan(text: 'Hôm nay bạn đã chi tiêu '),
                      TextSpan(text: '120.000 ₫', style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: ' cho Cà phê & Ăn uống, vẫn nằm trong hạn mức tuần! Bạn có '),
                      TextSpan(
                        text: '1 hóa đơn định kỳ (Tiền điện)',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error),
                      ),
                      TextSpan(text: ' đến hạn sau 2 ngày.'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AdvisorScreen()));
                  },
                  child: const Row(
                    children: [
                      Text(
                        'Hỏi Gemini ngay',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.secondary),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward, size: 16, color: AppColors.secondary),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 4 Quick Action Shortcuts Grid
  Widget _buildQuickActionGrid(BuildContext context) {
    final actions = [
      {'title': 'Quét OCR', 'icon': Icons.document_scanner, 'color': AppColors.primary, 'bg': AppColors.surfaceContainerHigh},
      {'title': 'Voice AI', 'icon': Icons.mic, 'color': AppColors.secondary, 'bg': AppColors.secondaryFixed},
      {'title': 'Chia tiền', 'icon': Icons.group_add, 'color': AppColors.tertiary, 'bg': AppColors.surfaceContainerHigh},
      {'title': 'Ngân sách', 'icon': Icons.pie_chart, 'color': AppColors.primaryContainer, 'bg': AppColors.surfaceContainerHigh},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: actions.map((item) {
        return Expanded(
          child: GestureDetector(
            onTap: () {
              if (item['title'] == 'Voice AI' || item['title'] == 'Quét OCR') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const QuickRecordScreen()));
              } else if (item['title'] == 'Chia tiền') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SplitBillScreen()));
              } else {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AdvisorScreen()));
              }
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: item['bg'] as Color,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(item['icon'] as IconData, color: item['color'] as Color, size: 22),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item['title'] as String,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.onSurface),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 65% Monthly budget progress bar
  Widget _buildBudgetProgressBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.donut_large, color: AppColors.primary, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Ngân sách tháng 06/2026',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('65%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.onSurfaceVariant)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: 0.65,
              minHeight: 10,
              backgroundColor: AppColors.surfaceContainerHigh,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Đã dùng', style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                  Text(
                    CurrencyFormatter.formatVND(_monthlyExpense),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Hạn mức tháng', style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                  Text(
                    CurrencyFormatter.formatVND(_monthlyLimit),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Recent transactions header
  Widget _buildRecentTransactionsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Giao dịch gần đây',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.onSurface),
        ),
        TextButton(
          onPressed: () {},
          child: const Text(
            'Xem tất cả',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
        ),
      ],
    );
  }

  /// Recent transaction list
  Widget _buildRecentTransactionsList() {
    final list = [
      {'title': 'Ăn phở Thìn Lò Đúc', 'sub': 'Ăn uống • 12:30', 'amount': '-65.000 ₫', 'badge': 'AI Note', 'source': 'Tiền mặt', 'icon': Icons.restaurant, 'color': AppColors.error},
      {'title': 'Highlands Coffee', 'sub': 'Ăn uống • 09:15', 'amount': '-55.000 ₫', 'badge': 'Hóa đơn', 'source': 'Ví MoMo', 'icon': Icons.local_cafe, 'color': AppColors.tertiary},
      {'title': 'Đổ xăng Petrolimex', 'sub': 'Di chuyển • Hôm qua', 'amount': '-80.000 ₫', 'badge': 'Voice', 'source': 'Vietcombank', 'icon': Icons.local_gas_station, 'color': AppColors.primary},
      {'title': 'Tạm ứng lương tháng 6', 'sub': 'Lương • 30/05', 'amount': '+15.000.000 ₫', 'badge': null, 'source': 'Techcombank', 'icon': Icons.payments, 'color': AppColors.primary},
      {'title': 'Tiền thuê căn hộ', 'sub': 'Nhà ở • 28/05', 'amount': '-4.500.000 ₫', 'badge': 'Định kỳ', 'source': 'Chuyển khoản', 'icon': Icons.home_work, 'color': AppColors.tertiary},
    ];

    return Column(
      children: list.map((item) {
        final isIncome = (item['amount'] as String).startsWith('+');
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 1)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (item['color'] as Color).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(item['icon'] as IconData, color: item['color'] as Color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title'] as String,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          item['sub'] as String,
                          style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                        ),
                        if (item['badge'] != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.secondaryFixed,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item['badge'] as String,
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.secondary),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    item['amount'] as String,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isIncome ? AppColors.primary : AppColors.onSurface,
                    ),
                  ),
                  Text(
                    item['source'] as String,
                    style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Floating pill bottom navigation bar matching the design
  Widget _buildFloatingBottomNav(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest.withOpacity(0.92),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF131B2E).withOpacity(0.12),
            blurRadius: 36,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.home, 'Trang chủ', 0, () {}),
          _navItem(Icons.track_changes, 'Kế hoạch', 1, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SplitBillScreen()));
          }),

          // Center Floating AI Button
          GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const QuickRecordScreen()));
            },
            child: Container(
              width: 52,
              height: 52,
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryContainer],
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 26),
            ),
          ),

          _navItem(Icons.insights, 'Cố vấn AI', 2, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const AdvisorScreen()));
          }),
          _navItem(Icons.account_circle, 'Cá nhân', 3, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const Prm4ProfileScreen()));
          }),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index, VoidCallback onTap) {
    final isSelected = _currentNavIndex == index;
    return InkWell(
      onTap: () {
        setState(() => _currentNavIndex = index);
        onTap();
      },
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNotificationBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.notifications_active, color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Trung tâm thông báo',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                            ),
                            Text(
                              '3 thông báo mới chưa đọc',
                              style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  children: [
                    _buildNotifItem(
                      icon: Icons.receipt_long,
                      iconColor: AppColors.error,
                      title: 'Nhắc nợ • Tiệc BBQ Sinh nhật Lan',
                      subtitle: 'Anh Tuấn còn khoản nợ 600.000 ₫ chưa thanh toán. Chạm để gửi link VietQR.',
                      time: '5 phút trước',
                      isUnread: true,
                      tag: '600.000 ₫',
                      onAction: () {
                        Navigator.pop(ctx);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const SplitBillScreen()));
                      },
                      actionText: 'Nhắc Zalo ngay',
                    ),
                    _buildNotifItem(
                      icon: Icons.account_balance_wallet,
                      iconColor: AppColors.primary,
                      title: 'Ghi nhận chi tiêu MoMo',
                      subtitle: 'Phở bò tái gầu (-65.000 ₫) đã lưu vào danh mục Ăn uống • Tiêu dùng.',
                      time: '42 phút trước',
                      isUnread: true,
                      tag: '-65.000 ₫',
                    ),
                    _buildNotifItem(
                      icon: Icons.auto_awesome,
                      iconColor: AppColors.tertiary,
                      title: 'Cố vấn Túi Khôn AI',
                      subtitle: 'Tiết kiệm được 24% ngân sách tuần này. Dự kiến đạt mục tiêu mua căn hộ trước hạn!',
                      time: '2 giờ trước',
                      isUnread: true,
                      onAction: () {
                        Navigator.pop(ctx);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const AdvisorScreen()));
                      },
                      actionText: 'Xem phân tích',
                    ),
                    _buildNotifItem(
                      icon: Icons.security,
                      iconColor: Colors.blue,
                      title: 'Bảo mật dữ liệu Local SQLite',
                      subtitle: 'Đã hoàn tất mã hóa chuẩn ngân hàng AES-256 trên thiết bị cục bộ.',
                      time: 'Hôm qua',
                      isUnread: false,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotifItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String time,
    required bool isUnread,
    String? tag,
    VoidCallback? onAction,
    String? actionText,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUnread ? AppColors.primary.withOpacity(0.04) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnread ? AppColors.primary.withOpacity(0.2) : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.onSurface),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(time, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (tag != null || onAction != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (tag != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(tag, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  )
                else
                  const SizedBox(),
                if (onAction != null && actionText != null)
                  ElevatedButton(
                    onPressed: onAction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(actionText, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
