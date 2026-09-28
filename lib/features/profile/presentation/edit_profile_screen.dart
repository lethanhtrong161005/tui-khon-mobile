import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Screen for updating core profile & financial management preferences in Túi Khôn.
/// Focused only on high-value, app-relevant fields (No clutter):
/// 1. Tên hiển thị (Minh Quân)
/// 2. Số điện thoại & Email nhận báo cáo
/// 3. Mục tiêu tài chính trọng tâm (Tiết kiệm mua nhà, Trả nợ, Quỹ khẩn cấp, Du lịch)
/// 4. Chu kỳ tài chính hàng tháng (Ngày chốt sổ lương & chu kỳ chi tiêu)
/// 5. Tài khoản nhận tiền mặc định (VietQR/Ngân hàng)
class EditProfileScreen extends StatefulWidget {
  final String initialName;
  final String initialPhone;
  final String initialEmail;
  final String initialGoal;
  final int initialCycleDay;
  final String initialBankName;
  final String initialAccountNumber;

  const EditProfileScreen({
    super.key,
    this.initialName = 'Minh Quân',
    this.initialPhone = '0988 123 456',
    this.initialEmail = 'minhquan.fin@gmail.com',
    this.initialGoal = 'Tiết kiệm mua căn hộ 2027',
    this.initialCycleDay = 5,
    this.initialBankName = 'Techcombank',
    this.initialAccountNumber = '1903 •••• •••• 888',
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _bankAccountController;

  late String _selectedGoal;
  late int _selectedCycleDay;
  late String _selectedBank;
  bool _isLoading = false;

  final List<String> _financialGoals = [
    'Tiết kiệm mua căn hộ 2027',
    'Tích lũy quỹ khẩn cấp (6 tháng)',
    'Tự do tài chính & Đầu tư',
    'Chuẩn bị mua xe ô tô',
    'Kinh doanh khởi nghiệp',
  ];

  final List<String> _vietnameseBanks = [
    'Techcombank',
    'Vietcombank',
    'MB Bank',
    'VPBank',
    'ACB',
    'Ví MoMo',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _phoneController = TextEditingController(text: widget.initialPhone);
    _emailController = TextEditingController(text: widget.initialEmail);
    _bankAccountController = TextEditingController(text: widget.initialAccountNumber);
    _selectedGoal = widget.initialGoal;
    _selectedCycleDay = widget.initialCycleDay;
    _selectedBank = widget.initialBankName;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _bankAccountController.dispose();
    super.dispose();
  }

  void _handleSaveProfile() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập họ và tên hiển thị')),
      );
      return;
    }

    setState(() => _isLoading = true);

    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: AppColors.primary,
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text(
                'Đã cập nhật hồ sơ cá nhân thành công!',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
        ),
      );

      Navigator.pop(context, {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'goal': _selectedGoal,
        'cycleDay': _selectedCycleDay,
        'bankName': _selectedBank,
        'accountNumber': _bankAccountController.text.trim(),
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Cập nhật hồ sơ',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppColors.onSurface,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _handleSaveProfile,
            child: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  )
                : const Text(
                    'Lưu',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar picker card
            Center(
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 2.5),
                    ),
                    child: const CircleAvatar(
                      radius: 46,
                      backgroundImage: NetworkImage(
                        'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=150',
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Chọn ảnh từ thư viện hoặc chụp ảnh mới'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Chạm để đổi ảnh đại diện',
                style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 24),

            // Section 1: Thông tin cơ bản
            _buildSectionHeader('THÔNG TIN CƠ BẢN'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8),
                ],
              ),
              child: Column(
                children: [
                  _buildTextField(
                    controller: _nameController,
                    label: 'Tên hiển thị',
                    hintText: 'Nhập tên của bạn',
                    icon: Icons.person_outline_rounded,
                  ),
                  const Divider(height: 24, thickness: 0.6),
                  _buildTextField(
                    controller: _phoneController,
                    label: 'Số điện thoại',
                    hintText: '09xx xxx xxx',
                    icon: Icons.phone_android_rounded,
                    keyboardType: TextInputType.phone,
                  ),
                  const Divider(height: 24, thickness: 0.6),
                  _buildTextField(
                    controller: _emailController,
                    label: 'Email nhận báo cáo tài chính',
                    hintText: 'example@gmail.com',
                    icon: Icons.alternate_email_rounded,
                    keyboardType: TextInputType.emailAddress,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Section 2: Thiết lập tài chính cá nhân
            _buildSectionHeader('THIẾT LẬP TÀI CHÍNH TÚI KHÔN'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Mục tiêu tài chính
                  const Text(
                    'Mục tiêu tài chính trọng tâm',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.outlineVariant.withOpacity(0.4)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedGoal,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.outline),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.onSurface),
                        items: _financialGoals.map((goal) {
                          return DropdownMenuItem<String>(
                            value: goal,
                            child: Row(
                              children: [
                                const Icon(Icons.flag_circle_outlined, size: 18, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Expanded(child: Text(goal, overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedGoal = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Ngày chốt sổ / nhận lương
                  const Text(
                    'Ngày chốt sổ lương hàng tháng',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'AI Gemini sẽ tự động tính toán chu kỳ ngân sách và gửi gợi ý phân bổ tiền theo ngày này.',
                    style: TextStyle(fontSize: 11, color: AppColors.outline, height: 1.3),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.outlineVariant.withOpacity(0.4)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        isExpanded: true,
                        value: _selectedCycleDay,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.outline),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.onSurface),
                        items: [1, 5, 10, 15, 20, 25, 28, 30].map((day) {
                          return DropdownMenuItem<int>(
                            value: day,
                            child: Text('Ngày $day hàng tháng (Bắt đầu chu kỳ mới)'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedCycleDay = val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Section 3: Tài khoản nhận tiền VietQR mặc định
            _buildSectionHeader('TÀI KHOẢN VIETQR MẶC ĐỊNH (CHIA TIỀN & NHẬN LẠI TIỀN)'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ngân hàng thụ hưởng',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.outlineVariant.withOpacity(0.4)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedBank,
                        icon: const Icon(Icons.account_balance_rounded, size: 18, color: AppColors.primary),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.onSurface),
                        items: _vietnameseBanks.map((bank) {
                          return DropdownMenuItem<String>(
                            value: bank,
                            child: Text(bank),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedBank = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: _bankAccountController,
                    label: 'Số tài khoản / Số ví',
                    hintText: 'Nhập số tài khoản ngân hàng',
                    icon: Icons.qr_code_2_rounded,
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Primary save button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleSaveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Lưu thay đổi',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: AppColors.outline,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.onSurface),
          decoration: InputDecoration(
            isDense: true,
            hintText: hintText,
            hintStyle: const TextStyle(fontSize: 13, color: AppColors.outline),
            prefixIcon: Icon(icon, size: 20, color: AppColors.primary),
            prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            filled: true,
            fillColor: AppColors.surfaceVariant.withOpacity(0.3),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.outlineVariant.withOpacity(0.4)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.outlineVariant.withOpacity(0.4)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
