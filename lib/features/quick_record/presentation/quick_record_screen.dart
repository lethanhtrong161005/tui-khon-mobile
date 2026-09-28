import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/vietnamese_nlp_service.dart';
import '../../home/models/transaction_model.dart';

/// QuickRecordScreen provides the Gemini Flash multimodal chat UI for natural Vietnamese inputs.
/// Features voice STT simulation, slang parsing, and transaction confirmation cards.
class QuickRecordScreen extends StatefulWidget {
  const QuickRecordScreen({super.key});

  @override
  State<QuickRecordScreen> createState() => _QuickRecordScreenState();
}

class _QuickRecordScreenState extends State<QuickRecordScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isRecording = false;
  int _aiDailyCount = 12;

  // Initial conversation items
  final List<Map<String, dynamic>> _messages = [
    {
      'isUser': false,
      'text': 'Chào Minh Quân! Bạn vừa chi tiêu gì hay có khoản thu nào mới? Hãy gõ hoặc bấm mic nói tự nhiên bằng tiếng Việt nhé.',
      'time': '12:44',
    },
    {
      'isUser': true,
      'isVoice': true,
      'text': 'Tôi vừa ăn phở bò tái gầu 65k thanh toán bằng MoMo',
      'time': '12:45',
    },
    {
      'isUser': false,
      'text': 'Gemini đã nhận diện giao dịch ăn uống của bạn! Vui lòng kiểm tra và bấm Lưu nhé:',
      'time': '12:45',
      'card': {
        'title': 'Phở bò tái gầu',
        'sub': 'Ăn uống • Chi tiêu cá nhân',
        'amount': '-65.000 ₫',
        'wallet': 'Ví MoMo',
        'badge': 'Trừ tiền',
        'isIncome': false,
        'icon': Icons.ramen_dining,
      },
    },
    {
      'isUser': true,
      'isVoice': false,
      'text': 'Tiền trúng thưởng 50 củ',
      'time': '12:47',
    },
    {
      'isUser': false,
      'text': '🎉 Chúc mừng bạn! Gemini tự động chuẩn hóa "50 củ" = 50.000.000 ₫:',
      'time': '12:47',
      'card': {
        'title': 'Tiền trúng thưởng',
        'sub': 'Thu nhập khác',
        'amount': '+50.000.000 ₫',
        'wallet': 'Tiền mặt / TK Chính',
        'badge': '+ Thu nhập',
        'isIncome': true,
        'icon': Icons.celebration,
      },
    },
  ];

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    final userText = text.trim();
    _controller.clear();

    setState(() {
      _aiDailyCount = (_aiDailyCount + 1).clamp(0, 50);
      _messages.add({
        'isUser': true,
        'isVoice': false,
        'text': userText,
        'time': 'Vừa xong',
      });
    });

    // Simulate on-device NLP processing
    Future.delayed(const Duration(milliseconds: 600), () {
      final parsed = VietnameseNlpService.parseInput(userText);
      final isInc = parsed.type == TransactionType.income;

      setState(() {
        _messages.add({
          'isUser': false,
          'text': isInc
              ? '🎉 Gemini đã ghi nhận khoản thu của bạn!'
              : 'Gemini đã nhận diện chi tiêu mới. Bấm Lưu để cộng vào sổ nhé:',
          'time': 'Vừa xong',
          'card': {
            'title': parsed.title,
            'sub': '${parsed.category} • Cá nhân',
            'amount': '${isInc ? "+" : "-"}${parsed.amount.toInt()} ₫',
            'wallet': parsed.walletSource,
            'badge': isInc ? '+ Thu nhập' : 'Trừ tiền',
            'isIncome': isInc,
            'icon': parsed.icon,
          },
        });
      });

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 200,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

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
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.account_balance_wallet, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 8),
            const Text(
              'Ghi Nhanh Ai',
              style: TextStyle(color: AppColors.onSurface, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              radius: 16,
              backgroundImage: NetworkImage('https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=150'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Sub-header Banner & Quick chips
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: AppColors.secondaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                        ),
                        const SizedBox(width: 8),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Trợ lý Túi Khôn', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            Text('Gemini Flash AI Engine', style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryFixed,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.bolt, size: 14, color: AppColors.primary),
                          SizedBox(width: 2),
                          Text('Tiếng Việt tự nhiên', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text('Gợi ý nói hoặc gõ mẫu:', style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _quickChip('Ăn phở 65k'),
                      _quickChip('Cho Lan mượn 2 tr'),
                      _quickChip('Tôi trúng số 50 củ'),
                      _quickChip('Đổ xăng 80 nghìn'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Message stream
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['isUser'] as bool;

                if (isUser) {
                  return _buildUserBubble(msg['text'] as String, msg['time'] as String, msg['isVoice'] == true);
                } else {
                  return _buildAiBubble(msg['text'] as String, msg['time'] as String, msg['card'] as Map<String, dynamic>?);
                }
              },
            ),
          ),

          // Sticky bottom input bar
          _buildInputBar(context),
        ],
      ),
    );
  }

  Widget _quickChip(String text) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      child: ActionChip(
        label: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.onSurface)),
        backgroundColor: AppColors.surfaceContainerHighest,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onPressed: () {
          _controller.text = text;
        },
      ),
    );
  }

  Widget _buildUserBubble(String text, String time, bool isVoice) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
            topRight: Radius.circular(4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isVoice) ...[
              const Row(
                children: [
                  Icon(Icons.mic, color: Colors.white70, size: 14),
                  SizedBox(width: 4),
                  Text('GIỌNG NÓI ĐÃ DỊCH', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),
            ],
            Text(
              '"$text"',
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(time, style: const TextStyle(color: AppColors.primaryFixed, fontSize: 10)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiBubble(String text, String time, Map<String, dynamic>? card) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: AppColors.secondary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                    topLeft: Radius.circular(4),
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
                  ],
                ),
                child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.onSurface)),
              ),
            ),
          ],
        ),
        if (card != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 36, bottom: 12),
            child: _buildTransactionCard(card),
          ),
        ],
      ],
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> card) {
    final isIncome = card['isIncome'] == true;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isIncome ? AppColors.primaryFixed : AppColors.tertiaryFixed,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(card['icon'] as IconData, size: 20, color: isIncome ? AppColors.primary : AppColors.tertiary),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(card['title'] as String, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      Text(card['sub'] as String, style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isIncome ? AppColors.primaryFixed : AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  card['badge'] as String,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isIncome ? AppColors.primary : AppColors.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('SỐ TIỀN QUY ĐỔI', style: TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant, fontWeight: FontWeight.bold)),
                    Text(
                      card['amount'] as String,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: isIncome ? AppColors.primary : AppColors.error,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4),
                    ],
                  ),
                  child: Text(
                    card['wallet'] as String,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Mở chỉnh sửa giao dịch...')),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text('Sửa', style: TextStyle(color: AppColors.onSurface)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã lưu giao dịch vào cơ sở dữ liệu Túi Khôn!')),
                    );
                  },
                  icon: const Icon(Icons.check_circle, size: 16),
                  label: Text(isIncome ? 'Lưu khoản thu' : 'Lưu giao dịch'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.95),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('Hôm nay: $_aiDailyCount/50 lượt AI', style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                  ],
                ),
                const Text('Gemini 1.5 Flash • 0.3s', style: TextStyle(fontSize: 10, color: AppColors.outline)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.document_scanner, color: AppColors.onSurface),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Kích hoạt camera quét hóa đơn (Receipt OCR)...')),
                    );
                  },
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Nhập chi tiêu tự nhiên (vd: cafe 35k)...',
                        border: InputBorder.none,
                        hintStyle: TextStyle(fontSize: 13, color: AppColors.outline),
                      ),
                      onSubmitted: _sendMessage,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    setState(() => _isRecording = !_isRecording);
                    if (_isRecording) {
                      _controller.text = 'Đổ xăng xe máy 90k cây xăng Petrolimex';
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đang lắng nghe tiếng Việt tự nhiên...')),
                      );
                    } else if (_controller.text.isNotEmpty) {
                      _sendMessage(_controller.text);
                    }
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.secondary],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8),
                      ],
                    ),
                    child: Icon(_isRecording ? Icons.graphic_eq : Icons.mic, color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
