import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/offline/offline_wallet_repository.dart';
import '../../../core/offline/duplicate_service.dart';
import '../data/quick_record_learning.dart';
import '../../../core/services/voice_input_service.dart';
import '../../../core/utils/category_icons.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/error_messages.dart';
import '../../auth/providers/auth_providers.dart';
import '../../home/models/category_model.dart';
import '../../home/models/transaction_model.dart';
import '../../home/presentation/widgets/transaction_form_sheet.dart';
import '../../home/providers/home_providers.dart';
import '../../receipt/presentation/receipt_picker.dart';
import '../data/quick_record_repository.dart';
import '../data/quick_record_batch.dart';

/// What to do right after the screen opens (Home quick actions).
enum QuickRecordStart { none, voice, scan }

/// A bubble in the quick record conversation.
class _ChatMessage {
  _ChatMessage({
    required this.isUser,
    required this.text,
    this.isVoice = false,
    this.isReceipt = false,
    this.draft,
    this.item,
  })  : originalDraft = draft,
        time = DateTime.now();

  final bool isUser;
  String text;
  final bool isVoice;
  final bool isReceipt;
  final DateTime time;

  /// Transaction proposed by the AI; replaced when the user taps "Sửa".
  final TransactionDraft? originalDraft;
  TransactionDraft? draft;
  QuickRecordItem? item;
  bool get needsClarification =>
      draft?.amount == 0 || (item?.needsClarification ?? false);
  int? batch;
  bool selected = true;
  bool duplicate = false;
  bool saving = false;
  bool saved = false;
}

/// QuickRecordScreen provides the Gemini Flash multimodal chat UI for natural Vietnamese inputs.
/// Text goes to the `ai-quick-record` Edge Function, which returns a draft;
/// nothing is stored until the user taps "Lưu" on the confirmation card.
class QuickRecordScreen extends ConsumerStatefulWidget {
  const QuickRecordScreen(
      {super.key, this.initialAction = QuickRecordStart.none});

  final QuickRecordStart initialAction;

  @override
  ConsumerState<QuickRecordScreen> createState() => _QuickRecordScreenState();
}

class _QuickRecordScreenState extends ConsumerState<QuickRecordScreen> {
  static const int _defaultDailyLimit = 50;

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [
    _ChatMessage(
      isUser: false,
      text: 'Chào bạn! Bạn vừa chi tiêu gì hay có khoản thu nào mới? '
          'Hãy gõ hoặc bấm mic nói tự nhiên bằng tiếng Việt nhé.',
    ),
  ];
  List<ChatTurn> _followUpHistory = [];
  _ChatMessage? _activeFollowUp;
  late final VoiceInput _voice;
  bool _isRecording = false;
  bool _voiceSent = false;
  bool _isThinking = false;
  int? _aiDailyCount;
  int _aiDailyLimit = _defaultDailyLimit;

  @override
  void initState() {
    super.initState();
    _voice = ref.read(voiceInputProvider);
    _loadUsage();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      switch (widget.initialAction) {
        case QuickRecordStart.voice:
          _toggleVoice();
        case QuickRecordStart.scan:
          _scanReceipt();
        case QuickRecordStart.none:
          break;
      }
    });
  }

  Future<void> _loadUsage() async {
    try {
      final used =
          await ref.read(quickRecordRepositoryProvider).fetchTodayChatUsage();
      if (mounted) setState(() => _aiDailyCount = used ?? 0);
    } catch (_) {
      // Only cosmetic: the counter appears after the first AI call.
    }
  }

  /// Messages after the last proposed transaction (minus the greeting), so
  /// Gemini can combine its follow-up question with the user's answer.
  List<ChatTurn> _pendingHistory() {
    if (_followUpHistory.isNotEmpty) return List.of(_followUpHistory);
    final turns = <ChatTurn>[];
    for (final m in _messages.reversed) {
      if (m.draft != null || identical(m, _messages.first)) break;
      turns.insert(0, ChatTurn(fromUser: m.isUser, text: m.text));
    }
    return turns;
  }

  Future<void> _sendMessage(String text, {bool isVoice = false}) async {
    if (text.trim().isEmpty || _isThinking) return;
    final userText = text.trim();
    _controller.clear();

    final target = _activeFollowUp;
    final history = target == null
        ? _pendingHistory()
        : <ChatTurn>[
            ChatTurn(
                fromUser: true,
                text: target.item?.sourceText ?? target.draft?.note ?? ''),
            ChatTurn(
                fromUser: false,
                text: target.item?.question ?? 'Khoản này bao nhiêu tiền?'),
          ];
    setState(() {
      _messages
          .add(_ChatMessage(isUser: true, text: userText, isVoice: isVoice));
      _isThinking = true;
    });
    _scrollToBottom();

    try {
      final categories = await ref.read(categoriesProvider.future);
      final wallets = await ref.read(walletsProvider.future);
      var result = await ref.read(quickRecordRepositoryProvider).parse(
            userText,
            categories: categories,
            wallets: wallets,
            voice: isVoice,
            history: history,
          );
      if (!mounted) return;
      try {
        await ref.read(recentTransactionsProvider.future);
      } catch (_) {
        // A history outage must not hide successfully parsed drafts.
      }
      if (!mounted) return;
      final repository = ref.read(walletRepositoryProvider);
      if (repository is OfflineWalletRepository) {
        final learning = QuickRecordLearning(repository.store);
        final items = <QuickRecordItem>[];
        for (final item in result.allItems) {
          final draft = item.draft;
          if (draft == null) {
            items.add(item);
            continue;
          }
          try {
            items.add(item
                .withDraft(await learning.apply(draft, categories, wallets)));
          } catch (_) {
            items.add(item);
          }
        }
        result = QuickRecordResult(
            items: items,
            question: result.question,
            warnings: result.warnings,
            offline: result.offline,
            quotaUsed: result.quotaUsed,
            quotaLimit: result.quotaLimit);
      }
      if (!mounted) return;
      _followUpHistory = result.question == null
          ? []
          : [
              ...history,
              ChatTurn(fromUser: true, text: userText),
              ChatTurn(fromUser: false, text: result.question!),
            ];
      await _showResult(result, replacing: target);
      if (mounted) setState(() => _activeFollowUp = null);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (e is FunctionException && e.status == 429)
          _aiDailyCount = _aiDailyLimit;
        _messages.add(_ChatMessage(isUser: false, text: friendlyError(e)));
      });
    } finally {
      if (mounted) setState(() => _isThinking = false);
      _scrollToBottom();
    }
  }

  Future<void> _showResult(QuickRecordResult result,
      {bool fromReceipt = false, _ChatMessage? replacing}) async {
    final service = ref.read(duplicateServiceProvider);
    final matches = <TransactionDraft>{};
    if (service != null) {
      for (final draft in result.allDrafts) {
        if ((await service.find(draft)).isNotEmpty) matches.add(draft);
      }
    }
    if (!mounted) return;
    setState(() {
      if (result.quotaUsed != null && !fromReceipt)
        _aiDailyCount = result.quotaUsed;
      if (result.quotaLimit != null && !fromReceipt)
        _aiDailyLimit = result.quotaLimit!;
      final items =
          result.allItems.where((item) => item.draft != null).toList();
      if (items.isEmpty) {
        if (replacing != null) {
          replacing.item = QuickRecordItem(
              draft: replacing.draft,
              sourceText:
                  replacing.item?.sourceText ?? replacing.draft?.note ?? '',
              question: result.question ?? 'Bạn bổ sung số tiền giúp mình nhé?',
              missingFields: const ['amount']);
          replacing.text = replacing.item!.question!;
        } else {
          _messages.add(_ChatMessage(
              isUser: false,
              text: result.question ?? 'Bạn nói rõ hơn giúp mình nhé?'));
        }
        return;
      }
      final batch = replacing?.batch ?? _messages.length;
      final recent = ref.read(recentTransactionsProvider).valueOrNull ?? [];
      for (final item in replacing == null ? items : items.take(1)) {
        var draft = item.draft!;
        if (replacing?.draft?.receiptPath != null) {
          draft = draft.copyWith(
              receiptPath: replacing!.draft!.receiptPath,
              source: replacing.draft!.source);
        }
        final duplicate = draft.amount > 0 &&
            (matches.contains(item.draft) ||
                recent.any((tx) => isPossibleDuplicate(draft, tx.toDraft())) ||
                _messages.any((m) =>
                    !identical(m, replacing) &&
                    m.draft != null &&
                    isPossibleDuplicate(draft, m.draft!)));
        final text = [
          item.needsClarification
              ? 'Cần bổ sung giao dịch này:'
              : 'Kiểm tra rồi bấm Lưu nhé:',
          if (result.offline)
            '(Đang dùng bộ phân tích offline, hãy kiểm tra lại.)',
          if (item.question != null) item.question!,
          if (result.warnings.isNotEmpty)
            'Cần kiểm tra: ${result.warnings.join(', ')}',
        ].join('\n');
        final message = _ChatMessage(
            isUser: false,
            text: text,
            draft: draft,
            item: item.withDraft(draft))
          ..batch = batch
          ..duplicate = duplicate
          ..selected = !duplicate && !item.needsClarification;
        if (replacing != null) {
          final index = _messages.indexOf(replacing);
          if (index >= 0) _messages[index] = message;
        } else {
          _messages.add(message);
        }
      }
    });
  }

  /// Mic: tap to start, tap again (or pause speaking) to send the transcript.
  Future<void> _toggleVoice() async {
    if (_isRecording) {
      await _voice.stop();
      _finishVoice();
      return;
    }
    if (_isThinking) return;

    _controller.clear();
    _voiceSent = false;
    final started = await _voice.start(
      onResult: (text, isFinal) {
        if (!mounted) return;
        setState(() => _controller.text = text);
        if (isFinal) _finishVoice();
      },
      // The final transcript can arrive just after the recognizer stops.
      onDone: () => Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _finishVoice();
      }),
      onError: (_) {
        if (mounted && _controller.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Mình chưa nghe rõ, bạn thử nói lại nhé')),
          );
        }
      },
    );
    if (!mounted) return;
    if (!started) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Thiết bị chưa hỗ trợ nhận giọng nói hoặc bạn chưa cấp quyền micro')),
      );
      return;
    }
    setState(() => _isRecording = true);
  }

  void _finishVoice() {
    if (_isRecording) setState(() => _isRecording = false);
    final text = _controller.text.trim();
    if (_voiceSent || text.isEmpty) return;
    _voiceSent = true;
    _sendMessage(text, isVoice: true);
  }

  /// Camera / gallery → Storage + Gemini Vision → confirmation card.
  Future<void> _scanReceipt() async {
    if (_isThinking) return;
    final receipt = await pickReceiptImage(context);
    if (receipt == null || !mounted) return;

    setState(() {
      _messages.add(
          _ChatMessage(isUser: true, text: 'Ảnh hóa đơn', isReceipt: true));
      _isThinking = true;
    });
    _scrollToBottom();

    try {
      final result =
          await ref.read(quickRecordRepositoryProvider).scanReceipt(receipt);
      if (!mounted) return;
      final draft = result.allDrafts.firstOrNull;
      if (draft != null && draft.walletId == null) {
        // Unreadable receipt: still attach a wallet so the form opens prefilled.
        final categories = await ref.read(categoriesProvider.future);
        final wallets = await ref.read(walletsProvider.future);
        if (!mounted) return;
        await _showResult(
          QuickRecordResult(
              items: result.allItems
                  .where((i) => i.draft != null)
                  .map((i) => i.withDraft(
                      resolveDraftNames(i.draft!, categories, wallets)))
                  .toList(),
              drafts: result.allDrafts
                  .map((d) => resolveDraftNames(d, categories, wallets))
                  .toList(),
              draft: resolveDraftNames(draft, categories, wallets),
              question: result.question),
          fromReceipt: true,
        );
      } else {
        await _showResult(result, fromReceipt: true);
      }
    } catch (e) {
      if (mounted)
        setState(() =>
            _messages.add(_ChatMessage(isUser: false, text: friendlyError(e))));
    } finally {
      if (mounted) setState(() => _isThinking = false);
      _scrollToBottom();
    }
  }

  Future<void> _saveDraft(_ChatMessage message) async {
    if (message.draft == null || message.saving || message.saved) return;
    if (message.needsClarification) {
      _beginFollowUp(message);
      return;
    }
    if (!message.draft!.isValid || message.draft!.categoryId == null) {
      // Missing wallet / category: let the user complete it first.
      final edited =
          await showTransactionFormSheet(context, initial: message.draft);
      if (edited == null || !mounted) return;
      message.draft = edited;
    }

    setState(() => message.saving = true);
    try {
      await ref.saveTransaction(message.draft!);
      if (!mounted) return;
      setState(() => message.saved = true);
      await _learnSavedCorrection(message);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu giao dịch vào sổ Túi Khôn!')),
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => message.saving = false);
    }
  }

  Future<void> _saveSelected(int batch) async {
    final messages = _messages
        .where((m) =>
            m.batch == batch && m.selected && !m.saved && !m.needsClarification)
        .toList();
    if (messages.isEmpty || messages.any((m) => m.saving)) return;
    for (final message in messages) {
      if (!message.draft!.isValid || message.draft!.categoryId == null) {
        final edited =
            await showTransactionFormSheet(context, initial: message.draft);
        if (!mounted || edited == null) return;
        setState(() => message.draft = edited);
      }
    }
    setState(() {
      for (final m in messages) {
        m.saving = true;
      }
    });
    try {
      final service = ref.read(duplicateServiceProvider);
      final matches = <Map<String, dynamic>>[];
      final checked = <TransactionDraft>[];
      for (final message in messages) {
        final draft = message.draft!;
        if (service != null) matches.addAll(await service.find(draft));
        if (checked.any((other) => isPossibleDuplicate(draft, other))) {
          matches.add(draft.toInsertJson());
        }
        checked.add(draft);
      }
      if (!mounted) return;
      if (!await confirmPossibleDuplicate(context, matches) || !mounted) return;
      final repository = ref.read(walletRepositoryProvider);
      final batchWriter = repository is QuickRecordBatchWriter
          ? repository as QuickRecordBatchWriter
          : repository is OfflineWalletRepository
              ? _OfflineBatchWriter(repository)
              : null;
      if (batchWriter != null) {
        await batchWriter
            .addTransactions(messages.map((m) => m.draft!).toList());
        if (!mounted) return;
        setState(() {
          for (final m in messages) {
            m.saved = true;
          }
        });
        for (final m in messages) {
          await _learnSavedCorrection(m);
        }
      } else {
        // Mark each successful write immediately so retry never repeats it.
        for (final m in messages) {
          await repository.addTransaction(m.draft!);
          m.saved = true;
          await _learnSavedCorrection(m);
        }
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) ref.refreshWalletData();
      if (mounted)
        setState(() {
          for (final m in messages) {
            m.saving = false;
          }
        });
    }
  }

  void _beginFollowUp(_ChatMessage message) {
    setState(() {
      _activeFollowUp = message;
      _controller.clear();
    });
    _scrollToBottom();
  }

  Future<void> _editDraft(_ChatMessage message) async {
    final original = message.draft!;
    final edited = await showTransactionFormSheet(context, initial: original);
    if (edited == null || !mounted) return;
    final service = ref.read(duplicateServiceProvider);
    final duplicate =
        (service != null && (await service.find(edited)).isNotEmpty) ||
            _messages.any((m) =>
                !identical(m, message) &&
                m.draft != null &&
                isPossibleDuplicate(edited, m.draft!));
    if (!mounted) return;
    setState(() {
      message.draft = edited;
      message.item = QuickRecordItem(
          draft: edited,
          sourceText: message.item?.sourceText ?? original.note ?? '');
      message.duplicate = duplicate;
      if (duplicate) message.selected = false;
    });
  }

  Future<void> _learnSavedCorrection(_ChatMessage message) async {
    if (!message.saved || message.originalDraft == null || !mounted) return;
    if (message.originalDraft!.categoryId == message.draft!.categoryId) return;
    final repository = ref.read(walletRepositoryProvider);
    if (repository is! OfflineWalletRepository) return;
    try {
      await QuickRecordLearning(repository.store)
          .remember(message.originalDraft!, message.draft!);
    } catch (_) {
      // Saving succeeded even if learning storage is temporarily unavailable.
    }
  }

  /// Manual entry without AI.
  Future<void> _addManually() async {
    final draft = await showTransactionFormSheet(context);
    if (draft == null || !mounted) return;
    try {
      await ref.saveTransaction(draft);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã lưu giao dịch!')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 200,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    if (_voice.isListening) _voice.stop();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).valueOrNull;
    // Loaded up front so the confirmation card can show category icons instantly.
    final categories =
        ref.watch(categoriesProvider).valueOrNull ?? const <CategoryModel>[];
    ref.watch(walletsProvider);

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
              child: const Icon(Icons.account_balance_wallet,
                  size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 8),
            const Text(
              'Ghi Nhanh AI',
              style: TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Nhập thủ công',
            icon: const Icon(Icons.edit_note, color: AppColors.onSurface),
            onPressed: _addManually,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primaryFixed,
              backgroundImage: profile?.avatarUrl == null
                  ? null
                  : NetworkImage(profile!.avatarUrl!),
              child: profile?.avatarUrl == null
                  ? Text(
                      profile?.initials ?? '',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary),
                    )
                  : null,
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
                          child: const Icon(Icons.auto_awesome,
                              color: Colors.white, size: 16),
                        ),
                        const SizedBox(width: 8),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Trợ lý Túi Khôn',
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.bold)),
                            Text('Gemini Flash AI Engine',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.onSurfaceVariant)),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryFixed,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.bolt, size: 14, color: AppColors.primary),
                          SizedBox(width: 2),
                          Text('Tiếng Việt tự nhiên',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text('Gợi ý nói hoặc gõ mẫu:',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.onSurfaceVariant)),
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
              itemCount: _messages.length + (_isThinking ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) return _buildThinkingBubble();
                final msg = _messages[index];
                return msg.isUser
                    ? _buildUserBubble(msg)
                    : _buildAiBubble(msg, categories);
              },
            ),
          ),

          // Sticky bottom input bar
          if (_activeFollowUp != null)
            ListTile(
              title: Text(
                  'Bổ sung: ${_activeFollowUp!.item?.sourceText ?? _activeFollowUp!.draft?.note ?? ''}'),
              subtitle: Text(_activeFollowUp!.item?.question ??
                  'Khoản này bao nhiêu tiền?'),
              trailing: IconButton(
                  tooltip: 'Hủy bổ sung',
                  onPressed: _isThinking
                      ? null
                      : () => setState(() => _activeFollowUp = null),
                  icon: const Icon(Icons.close)),
            ),
          _buildInputBar(context),
        ],
      ),
    );
  }

  Widget _quickChip(String text) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      child: ActionChip(
        label: Text(text,
            style: const TextStyle(fontSize: 12, color: AppColors.onSurface)),
        backgroundColor: AppColors.surfaceContainerHighest,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onPressed: () {
          _controller.text = text;
        },
      ),
    );
  }

  static String _clock(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Widget _buildUserBubble(_ChatMessage msg) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
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
            if (msg.isVoice || msg.isReceipt) ...[
              Row(
                children: [
                  Icon(msg.isReceipt ? Icons.receipt_long : Icons.mic,
                      color: Colors.white70, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    msg.isReceipt ? 'QUÉT HÓA ĐƠN' : 'GIỌNG NÓI ĐÃ DỊCH',
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
            Text(
              msg.isReceipt ? '📷 ${msg.text}' : '"${msg.text}"',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(_clock(msg.time),
                  style: const TextStyle(
                      color: AppColors.primaryFixed, fontSize: 10)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThinkingBubble() {
    return const Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(width: 4),
          SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.secondary)),
          SizedBox(width: 10),
          Text('Gemini đang phân tích...',
              style:
                  TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildAiBubble(_ChatMessage msg, List<CategoryModel> categories) {
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
                    BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2)),
                  ],
                ),
                child: Text(msg.text,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.onSurface)),
              ),
            ),
          ],
        ),
        if (msg.draft != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 36, bottom: 12),
            child: Column(children: [
              if (!msg.saved)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Chọn giao dịch'),
                  subtitle: msg.duplicate
                      ? const Text(
                          'Có thể trùng giao dịch. Kiểm tra trước khi lưu.')
                      : null,
                  value: msg.selected,
                  onChanged: msg.saving || msg.needsClarification
                      ? null
                      : (value) =>
                          setState(() => msg.selected = value ?? false),
                ),
              _buildTransactionCard(msg, categories),
              if (!msg.saved && msg.needsClarification)
                TextButton(
                    onPressed: _isThinking ? null : () => _beginFollowUp(msg),
                    child: const Text('Bổ sung')),
              if (msg.batch != null &&
                  identical(
                      msg, _messages.lastWhere((m) => m.batch == msg.batch)))
                FilledButton(
                  onPressed: _messages.any((m) =>
                              m.batch == msg.batch &&
                              m.selected &&
                              !m.saved &&
                              !m.saving) &&
                          !_messages
                              .any((m) => m.batch == msg.batch && m.saving)
                      ? () => _saveSelected(msg.batch!)
                      : null,
                  child: Text(
                      'Lưu đã chọn (${_messages.where((m) => m.batch == msg.batch && m.selected && !m.saved).length})'),
                ),
            ]),
          ),
        ],
      ],
    );
  }

  Widget _buildTransactionCard(
      _ChatMessage msg, List<CategoryModel> categories) {
    final draft = msg.draft!;
    final isIncome = draft.isIncome;
    final categoryIcon =
        categories.where((c) => c.id == draft.categoryId).firstOrNull?.icon;
    final title = (draft.note != null && draft.note!.isNotEmpty)
        ? draft.note!
        : (draft.categoryName ?? 'Giao dịch');
    final subtitle = [
      draft.categoryName ?? 'Chưa chọn danh mục',
      if (draft.merchant != null) draft.merchant!
    ].join(' • ');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isIncome
                            ? AppColors.primaryFixed
                            : AppColors.tertiaryFixed,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        CategoryIcons.resolve(categoryIcon),
                        size: 20,
                        color:
                            isIncome ? AppColors.primary : AppColors.tertiary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            subtitle,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.onSurfaceVariant),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isIncome
                      ? AppColors.primaryFixed
                      : AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isIncome ? '+ Thu nhập' : 'Trừ tiền',
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
                    const Text('SỐ TIỀN QUY ĐỔI',
                        style: TextStyle(
                            fontSize: 10,
                            color: AppColors.onSurfaceVariant,
                            fontWeight: FontWeight.bold)),
                    Text(
                      CurrencyFormatter.formatVND(
                          isIncome ? draft.amount : -draft.amount,
                          showSign: true),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: isIncome ? AppColors.primary : AppColors.error,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.04), blurRadius: 4),
                    ],
                  ),
                  child: Text(
                    draft.walletName ?? 'Chọn nguồn tiền',
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (msg.saved)
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: AppColors.primary, size: 18),
                SizedBox(width: 6),
                Text('Đã lưu vào sổ',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: OutlinedButton(
                    onPressed: msg.saving ? null : () => _editDraft(msg),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text('Sửa',
                        style: TextStyle(color: AppColors.onSurface)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    onPressed: msg.saving || msg.needsClarification
                        ? null
                        : () => _saveDraft(msg),
                    icon: msg.saving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle, size: 16),
                    label: Text(isIncome ? 'Lưu khoản thu' : 'Lưu giao dịch'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
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
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -4)),
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
                    Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                            color: AppColors.primary, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(
                      'Hôm nay: ${_aiDailyCount ?? '–'}/$_aiDailyLimit lượt AI',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
                const Text('Gemini Flash',
                    style: TextStyle(fontSize: 10, color: AppColors.outline)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                IconButton(
                  tooltip: 'Quét hóa đơn',
                  icon: const Icon(Icons.document_scanner,
                      color: AppColors.onSurface),
                  onPressed: _isThinking || _isRecording ? null : _scanReceipt,
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
                      enabled: !_isThinking,
                      textInputAction: TextInputAction.send,
                      decoration: InputDecoration(
                        hintText: _isRecording
                            ? 'Đang nghe... hãy nói tự nhiên'
                            : 'Nhập chi tiêu tự nhiên (vd: cafe 35k)...',
                        border: InputBorder.none,
                        hintStyle: const TextStyle(
                            fontSize: 13, color: AppColors.outline),
                      ),
                      onSubmitted: (text) => _sendMessage(text),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _toggleVoice,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.secondary],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 8),
                      ],
                    ),
                    child: Icon(_isRecording ? Icons.stop_rounded : Icons.mic,
                        color: Colors.white, size: 22),
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

class _OfflineBatchWriter implements QuickRecordBatchWriter {
  _OfflineBatchWriter(this.repository);
  final OfflineWalletRepository repository;
  @override
  Future<void> addTransactions(List<TransactionDraft> drafts) =>
      repository.addTransactions(drafts);
}
