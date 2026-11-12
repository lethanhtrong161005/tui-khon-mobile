import '../../../core/utils/localized_format.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../../l10n/app_l10n.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/offline/offline_wallet_repository.dart';
import '../../../core/offline/duplicate_service.dart';
import '../data/quick_record_learning.dart';
import '../../../core/services/voice_input_service.dart';
import '../../../core/utils/category_icons.dart';
import '../../../core/utils/error_messages.dart';
import '../../auth/providers/auth_providers.dart';
import '../../home/models/category_model.dart';
import '../../home/models/transaction_model.dart';
import '../../home/presentation/widgets/transaction_form_sheet.dart';
import '../../home/providers/home_providers.dart';
import '../../receipt/presentation/receipt_picker.dart';
import '../data/quick_record_repository.dart';
import '../data/quick_record_batch.dart';
import '../../receipt/data/receipt_repository.dart';
import '../../finance_query/presentation/finance_query_conversation.dart';

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
  }) : originalDraft = draft,
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
  PickedReceipt? receipt;
}

/// Recording mode reviews text/voice, local OCR and optional AI suggestions.
/// Query mode reads the account's SQLite notebook without financial mutations.
/// No transaction is stored until the user confirms a reviewed draft.
class QuickRecordScreen extends ConsumerStatefulWidget {
  const QuickRecordScreen({
    super.key,
    this.initialAction = QuickRecordStart.none,
  });

  final QuickRecordStart initialAction;

  @override
  ConsumerState<QuickRecordScreen> createState() => _QuickRecordScreenState();
}

class _QuickRecordScreenState extends ConsumerState<QuickRecordScreen> {
  static const int _defaultDailyLimit = 50;

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final List<_ChatMessage> _messages = [
    _ChatMessage(
      isUser: false,
      text: appL10n(context).msgHelloHaveYouSpentOrReceived353,
    ),
  ];
  List<ChatTurn> _followUpHistory = [];
  _ChatMessage? _activeFollowUp;
  late final VoiceInput _voice;
  bool _isRecording = false;
  bool _voiceSent = false;
  bool _isThinking = false;
  bool _queryMode = false;
  bool _isPickingReceipt = false;
  final _queryKey = GlobalKey<FinanceQueryConversationState>();
  int _accountGeneration = 0;
  int? _aiDailyCount;
  int _aiDailyLimit = _defaultDailyLimit;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messages.first.text = appL10n(context).msgHelloHaveYouSpentOrReceived353;
  }

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
    final generation = _accountGeneration;
    try {
      final used = await ref
          .read(quickRecordRepositoryProvider)
          .fetchTodayChatUsage();
      if (mounted && generation == _accountGeneration)
        setState(() => _aiDailyCount = used ?? 0);
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
    if (_queryMode) {
      _controller.clear();
      await _queryKey.currentState?.send(text.trim());
      if (mounted) await _loadUsage();
      return;
    }
    final generation = _accountGeneration;
    final userText = text.trim();
    _controller.clear();

    final target = _activeFollowUp;
    final history = target == null
        ? _pendingHistory()
        : <ChatTurn>[
            ChatTurn(
              fromUser: true,
              text: target.item?.sourceText ?? target.draft?.note ?? '',
            ),
            ChatTurn(
              fromUser: false,
              text:
                  target.item?.question ??
                  appL10n(context).msgHowMuchWasThisTransaction354,
            ),
          ];
    setState(() {
      _messages.add(
        _ChatMessage(isUser: true, text: userText, isVoice: isVoice),
      );
      _isThinking = true;
    });
    _scrollToBottom();

    try {
      final categories = await ref.read(categoriesProvider.future);
      final wallets = await ref.read(walletsProvider.future);
      var result = await ref
          .read(quickRecordRepositoryProvider)
          .parse(
            userText,
            categories: categories,
            wallets: wallets,
            voice: isVoice,
            history: history,
          );
      if (!mounted || generation != _accountGeneration) return;
      try {
        await ref.read(recentTransactionsProvider.future);
      } catch (_) {
        // A history outage must not hide successfully parsed drafts.
      }
      if (!mounted || generation != _accountGeneration) return;
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
            items.add(
              item.withDraft(await learning.apply(draft, categories, wallets)),
            );
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
          quotaLimit: result.quotaLimit,
        );
      }
      if (!mounted || generation != _accountGeneration) return;
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
      if (!mounted || generation != _accountGeneration) return;
      setState(() {
        if (e is FunctionException && e.status == 429)
          _aiDailyCount = _aiDailyLimit;
        _messages.add(
          _ChatMessage(isUser: false, text: friendlyError(e, context: context)),
        );
      });
    } finally {
      if (mounted && generation == _accountGeneration)
        setState(() => _isThinking = false);
      _scrollToBottom();
    }
  }

  Future<void> _showResult(
    QuickRecordResult result, {
    bool fromReceipt = false,
    _ChatMessage? replacing,
  }) async {
    final generation = _accountGeneration;
    final service = ref.read(duplicateServiceProvider);
    final matches = <TransactionDraft>{};
    if (service != null) {
      for (final draft in result.allDrafts) {
        if ((await service.find(draft)).isNotEmpty) matches.add(draft);
      }
    }
    if (!mounted || generation != _accountGeneration) return;
    setState(() {
      if (result.quotaUsed != null && !fromReceipt)
        _aiDailyCount = result.quotaUsed;
      if (result.quotaLimit != null && !fromReceipt)
        _aiDailyLimit = result.quotaLimit!;
      final items = result.allItems
          .where((item) => item.draft != null)
          .toList();
      if (items.isEmpty) {
        if (replacing != null) {
          replacing.item = QuickRecordItem(
            draft: replacing.draft,
            sourceText:
                replacing.item?.sourceText ?? replacing.draft?.note ?? '',
            question:
                result.question ?? appL10n(context).msgPleaseAddTheAmount355,
            missingFields: ['amount'],
          );
          replacing.text = replacing.item!.question!;
        } else {
          _messages.add(
            _ChatMessage(
              isUser: false,
              text:
                  result.question ??
                  appL10n(context).msgPleaseProvideMoreDetails356,
            ),
          );
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
            source: replacing.draft!.source,
          );
        }
        final duplicate =
            draft.amount > 0 &&
            (matches.contains(item.draft) ||
                recent.any((tx) => isPossibleDuplicate(draft, tx.toDraft())) ||
                _messages.any(
                  (m) =>
                      !identical(m, replacing) &&
                      m.draft != null &&
                      isPossibleDuplicate(draft, m.draft!),
                ));
        final text = [
          item.needsClarification
              ? appL10n(context).msgAddDetailsToThisTransaction357
              : appL10n(context).msgReviewAndTapSave358,
          if (result.recognition == 'ocr') appL10n(context).receiptLocalResult,
          if (result.recognition == 'gemini') appL10n(context).receiptAiResult,
          if (item.missingFields.contains('amount'))
            appL10n(context).receiptMissingAmount,
          if (item.missingFields.contains('date'))
            appL10n(context).receiptMissingDate,
          if (item.missingFields.contains('wallet'))
            appL10n(context).receiptMissingWallet,
          if (item.missingFields.contains('type'))
            appL10n(context).receiptMissingType,
          if (result.offline)
            appL10n(context).msgUsingTheOfflineParserPleaseReview359,
          if (item.question != null) item.question!,
          if (result.warnings.isNotEmpty)
            appL10n(context).msgReviewRequired360(
              result.warnings
                  .map(
                    (w) => w == 'AMOUNT_MISMATCH'
                        ? appL10n(context).receiptAmountMismatch
                        : appL10n(context).receiptAiResult,
                  )
                  .join(', '),
            ),
        ].join('\n');
        final message =
            _ChatMessage(
                isUser: false,
                text: text,
                draft: draft,
                item: item.withDraft(draft),
              )
              ..receipt = replacing?.receipt
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

    final generation = _accountGeneration;
    _controller.clear();
    _voiceSent = false;
    final started = await _voice.start(
      onResult: (text, isFinal) {
        if (!mounted || generation != _accountGeneration) return;
        setState(() => _controller.text = text);
        if (isFinal) _finishVoice();
      },
      // The final transcript can arrive just after the recognizer stops.
      onDone: () => Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && generation == _accountGeneration) _finishVoice();
      }),
      onError: (_) {
        if (mounted &&
            generation == _accountGeneration &&
            _controller.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(appL10n(context).msgICouldnTHearThatClearly361),
            ),
          );
        }
      },
    );
    if (!mounted || generation != _accountGeneration) return;
    if (!started) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            appL10n(context).msgSpeechRecognitionIsUnavailableOrMicrophone362,
          ),
        ),
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

  /// Camera/gallery → private attachment + on-device OCR → review card.
  Future<void> _scanReceipt() async {
    if (_isThinking || _isRecording || _isPickingReceipt) return;
    final generation = _accountGeneration;
    setState(() => _isPickingReceipt = true);
    try {
      FocusManager.instance.primaryFocus?.unfocus();
      final receipt = await pickReceiptImage(context);
      if (receipt == null || !mounted || generation != _accountGeneration)
        return;
      setState(
        () => _messages.add(
          _ChatMessage(
            isUser: true,
            text: appL10n(context).msgReceiptImage363,
            isReceipt: true,
          ),
        ),
      );
      setState(() {
        _isPickingReceipt = false;
        _isThinking = true;
      });
      final result = await ref
          .read(quickRecordRepositoryProvider)
          .scanReceipt(receipt);
      if (!mounted || generation != _accountGeneration) return;
      await _showResult(result, fromReceipt: true);
      if (!mounted || generation != _accountGeneration) return;
      setState(() {
        for (final msg in _messages.where(
          (m) => !m.isUser && m.draft?.receiptPath == result.draft?.receiptPath,
        )) {
          msg.receipt = receipt;
        }
      });
    } catch (error) {
      if (mounted && generation == _accountGeneration) {
        setState(
          () => _messages.add(
            _ChatMessage(
              isUser: false,
              text: appL10n(context).receiptPickerError,
            ),
          ),
        );
      }
    } finally {
      if (mounted && generation == _accountGeneration)
        setState(() {
          _isThinking = false;
          _isPickingReceipt = false;
        });
      _scrollToBottom();
    }
  }

  Future<void> _enhanceReceipt(_ChatMessage message) async {
    if (_isThinking || message.receipt == null || message.saved) return;
    final generation = _accountGeneration;
    setState(() => _isThinking = true);
    try {
      final result = await ref
          .read(quickRecordRepositoryProvider)
          .enhanceReceipt(message.receipt!, ocrText: message.item?.sourceText);
      if (!mounted || generation != _accountGeneration) return;
      await _showResult(result, fromReceipt: true, replacing: message);
    } catch (error) {
      if (mounted && generation == _accountGeneration) {
        setState(
          () => _messages.add(
            _ChatMessage(
              isUser: false,
              text: friendlyError(error, context: context),
            ),
          ),
        );
      }
    } finally {
      if (mounted && generation == _accountGeneration)
        setState(() => _isThinking = false);
    }
  }

  Future<void> _saveDraft(_ChatMessage message) async {
    final generation = _accountGeneration;
    if (message.draft == null || message.saving || message.saved) return;
    if (message.needsClarification) {
      _beginFollowUp(message);
      return;
    }
    if (!message.draft!.isValid || message.draft!.categoryId == null) {
      // Missing wallet / category: let the user complete it first.
      final edited = await showTransactionFormSheet(
        context,
        initial: message.draft,
      );
      if (edited == null || !mounted || generation != _accountGeneration)
        return;
      message.draft = edited;
    }

    setState(() => message.saving = true);
    try {
      await ref.saveTransaction(message.draft!);
      if (!mounted || generation != _accountGeneration) return;
      setState(() => message.saved = true);
      await _learnSavedCorrection(message);
      if (!mounted || generation != _accountGeneration) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appL10n(context).msgSavedToYourTIKh364)),
      );
    } catch (e) {
      if (mounted && generation == _accountGeneration)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e, context: context))),
        );
    } finally {
      if (mounted && generation == _accountGeneration)
        setState(() => message.saving = false);
    }
  }

  Future<void> _saveSelected(int batch) async {
    final generation = _accountGeneration;
    final messages = _messages
        .where(
          (m) =>
              m.batch == batch &&
              m.selected &&
              !m.saved &&
              !m.needsClarification,
        )
        .toList();
    if (messages.isEmpty || messages.any((m) => m.saving)) return;
    for (final message in messages) {
      if (!message.draft!.isValid || message.draft!.categoryId == null) {
        final edited = await showTransactionFormSheet(
          context,
          initial: message.draft,
        );
        if (!mounted || generation != _accountGeneration || edited == null)
          return;
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
      if (!mounted || generation != _accountGeneration) return;
      if (!await confirmPossibleDuplicate(context, matches) ||
          !mounted ||
          generation != _accountGeneration)
        return;
      final repository = ref.read(walletRepositoryProvider);
      final batchWriter = repository is QuickRecordBatchWriter
          ? repository as QuickRecordBatchWriter
          : repository is OfflineWalletRepository
          ? _OfflineBatchWriter(repository)
          : null;
      if (batchWriter != null) {
        await batchWriter.addTransactions(
          messages.map((m) => m.draft!).toList(),
        );
        if (!mounted || generation != _accountGeneration) return;
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
      if (mounted && generation == _accountGeneration)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e, context: context))),
        );
    } finally {
      if (mounted && generation == _accountGeneration) ref.refreshWalletData();
      if (mounted && generation == _accountGeneration)
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
    final generation = _accountGeneration;
    final original = message.draft!;
    final edited = await showTransactionFormSheet(context, initial: original);
    if (edited == null || !mounted || generation != _accountGeneration) return;
    final service = ref.read(duplicateServiceProvider);
    final duplicate =
        (service != null && (await service.find(edited)).isNotEmpty) ||
        _messages.any(
          (m) =>
              !identical(m, message) &&
              m.draft != null &&
              isPossibleDuplicate(edited, m.draft!),
        );
    if (!mounted || generation != _accountGeneration) return;
    setState(() {
      message.draft = edited;
      message.item = QuickRecordItem(
        draft: edited,
        sourceText: message.item?.sourceText ?? original.note ?? '',
      );
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
    final generation = _accountGeneration;
    final draft = await showTransactionFormSheet(context);
    if (draft == null || !mounted || generation != _accountGeneration) return;
    try {
      await ref.saveTransaction(draft);
      if (!mounted || generation != _accountGeneration) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appL10n(context).msgTransactionSaved365)),
      );
    } catch (e) {
      if (mounted && generation == _accountGeneration)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e, context: context))),
        );
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
    ref.listen(currentUserIdProvider, (previous, next) {
      if (previous == next) return;
      _accountGeneration++;
      _voice.stop();
      _controller.clear();
      _queryKey.currentState?.clear();
      setState(() {
        _messages.removeRange(1, _messages.length);
        _activeFollowUp = null;
        _followUpHistory = [];
        _isThinking = false;
        _isPickingReceipt = false;
        _isRecording = false;
        _aiDailyCount = null;
      });
    });
    final profile = ref.watch(profileProvider).valueOrNull;
    // Loaded up front so the confirmation card can show category icons instantly.
    final categories =
        ref.watch(categoriesProvider).valueOrNull ?? <CategoryModel>[];
    ref.watch(walletsProvider);

    return Scaffold(
      backgroundColor: appPalette(context).surface,
      appBar: AppBar(
        backgroundColor: adaptiveSurface(context, const Color(0xFFF7F7FC)),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: appPalette(context).onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: appPalette(context).primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.account_balance_wallet,
                size: 18,
                color: appPalette(context).primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                appL10n(context).quickAi,
                style: TextStyle(
                  color: appPalette(context).onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: appL10n(context).msgEnterManually366,
            icon: Icon(Icons.edit_note, color: appPalette(context).onSurface),
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
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: appPalette(context).primary,
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
      body: NotebookBackground(
        ai: true,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: Text(appL10n(context).financeRecordMode),
                      selected: !_queryMode,
                      onSelected: _isThinking || _isRecording
                          ? null
                          : (_) => setState(() => _queryMode = false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: Text(appL10n(context).financeQueryMode),
                      selected: _queryMode,
                      onSelected: _isThinking || _isRecording
                          ? null
                          : (_) => setState(() => _queryMode = true),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _queryMode ? 1 : 0,
                children: [
                  Column(
                    children: [
                      Flexible(
                        flex: 2,
                        fit: FlexFit.loose,
                        child: SingleChildScrollView(child: _introCard()),
                      ),

                      // Message stream
                      Expanded(
                        flex: 3,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          itemCount: _messages.length + (_isThinking ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _messages.length)
                              return _buildThinkingBubble();
                            final msg = _messages[index];
                            return msg.isUser
                                ? _buildUserBubble(msg)
                                : _buildAiBubble(msg, categories);
                          },
                        ),
                      ),
                    ],
                  ),
                  FinanceQueryConversation(
                    key: _queryKey,
                    onBusy: (busy) {
                      if (mounted) setState(() => _isThinking = busy);
                    },
                  ),
                ],
              ),
            ),
            // Sticky bottom input bar
            if (!_queryMode && _activeFollowUp != null)
              ListTile(
                title: Text(
                  appL10n(context).msgFollowUp367(
                    (_activeFollowUp!.item?.sourceText ??
                            _activeFollowUp!.draft?.note ??
                            '')
                        .toString(),
                  ),
                ),
                subtitle: Text(
                  _activeFollowUp!.item?.question ??
                      appL10n(context).msgHowMuchWasThisTransaction354,
                ),
                trailing: IconButton(
                  tooltip: appL10n(context).msgCancelFollowUp368,
                  onPressed: _isThinking
                      ? null
                      : () => setState(() => _activeFollowUp = null),
                  icon: const Icon(Icons.close),
                ),
              ),
            _buildInputBar(context),
          ],
        ),
      ),
    );
  }

  Widget _introCard() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
    child: GlassCard(
      radius: 22,
      tint: adaptiveSurface(context, const Color(0xFFF0EEFF)),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TintedIcon(
                Icons.auto_awesome_rounded,
                color: appPalette(context).secondary,
                size: 36,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appL10n(context).msgTIKhNAssistant369,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      appL10n(context).msgRecordMultipleItemsAndReviewBefore370,
                      style: TextStyle(
                        fontSize: 10,
                        color: appPalette(context).onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            appL10n(context).msgTypeOrSpeakNaturallyInVietnamese371,
            style: TextStyle(
              fontSize: 11,
              color: appPalette(context).onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _quickChip(appL10n(context).msgNPhK372),
                _quickChip(appL10n(context).msgCPhKXNgK373),
                _quickChip(appL10n(context).msgNhNLNgTriU374),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _quickChip(String text) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      child: ActionChip(
        label: Text(
          text,
          style: TextStyle(fontSize: 12, color: appPalette(context).onSurface),
        ),
        backgroundColor: appPalette(context).surfaceContainerHighest,
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
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: appPalette(context).primary,
          borderRadius: const BorderRadius.only(
            topLeft: const Radius.circular(16),
            bottomLeft: const Radius.circular(16),
            bottomRight: const Radius.circular(16),
            topRight: const Radius.circular(4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (msg.isVoice || msg.isReceipt) ...[
              Row(
                children: [
                  Icon(
                    msg.isReceipt ? Icons.receipt_long : Icons.mic,
                    color: Colors.white70,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    msg.isReceipt
                        ? appL10n(context).msgScanReceipt375
                        : appL10n(context).msgTranscribedVoice376,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
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
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                _clock(msg.time),
                style: const TextStyle(
                  color: AppColors.primaryFixed,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThinkingBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const SizedBox(width: 4),
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: appPalette(context).secondary,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            appL10n(context).msgGeminiIsAnalyzing377,
            style: TextStyle(
              fontSize: 12,
              color: appPalette(context).onSurfaceVariant,
            ),
          ),
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
              decoration: BoxDecoration(
                color: appPalette(context).secondary,
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
                  color: appPalette(context).surfaceContainerLowest,
                  borderRadius: const BorderRadius.only(
                    topRight: const Radius.circular(16),
                    bottomLeft: const Radius.circular(16),
                    bottomRight: const Radius.circular(16),
                    topLeft: const Radius.circular(4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  msg.text,
                  style: TextStyle(
                    fontSize: 13,
                    color: appPalette(context).onSurface,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (msg.draft != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 36, bottom: 12),
            child: Column(
              children: [
                if (!msg.saved)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(appL10n(context).msgSelectTransaction378),
                    subtitle: msg.duplicate
                        ? Text(
                            appL10n(context)
                                .msgPossibleDuplicateReviewBeforeSaving379,
                          )
                        : null,
                    value: msg.selected,
                    onChanged: msg.saving || msg.needsClarification
                        ? null
                        : (value) =>
                              setState(() => msg.selected = value ?? false),
                  ),
                _buildTransactionCard(msg, categories),
                if (!msg.saved && msg.receipt != null)
                  TextButton.icon(
                    onPressed: _isThinking ? null : () => _enhanceReceipt(msg),
                    icon: const Icon(Icons.auto_awesome),
                    label: Text(appL10n(context).receiptAskAi),
                  ),
                if (!msg.saved && msg.needsClarification && msg.receipt == null)
                  TextButton(
                    onPressed: _isThinking ? null : () => _beginFollowUp(msg),
                    child: Text(appL10n(context).msgAddDetails380),
                  ),
                if (msg.batch != null &&
                    identical(
                      msg,
                      _messages.lastWhere((m) => m.batch == msg.batch),
                    ))
                  FilledButton(
                    onPressed:
                        _messages.any(
                              (m) =>
                                  m.batch == msg.batch &&
                                  m.selected &&
                                  !m.saved &&
                                  !m.saving,
                            ) &&
                            !_messages.any(
                              (m) => m.batch == msg.batch && m.saving,
                            )
                        ? () => _saveSelected(msg.batch!)
                        : null,
                    child: Text(
                      appL10n(context).msgSaveSelected381(
                        (_messages
                                .where(
                                  (m) =>
                                      m.batch == msg.batch &&
                                      m.selected &&
                                      !m.saved,
                                )
                                .length)
                            .toString(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTransactionCard(
    _ChatMessage msg,
    List<CategoryModel> categories,
  ) {
    final draft = msg.draft!;
    final isIncome = draft.isIncome;
    final categoryIcon = categories
        .where((c) => c.id == draft.categoryId)
        .firstOrNull
        ?.icon;
    final title = (draft.note != null && draft.note!.isNotEmpty)
        ? draft.note!
        : (draft.categoryName ?? appL10n(context).msgTransactions5);
    final subtitle = [
      draft.categoryName ?? appL10n(context).msgNoCategorySelected382,
      if (draft.merchant != null) draft.merchant!,
    ].join(' • ');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: appPalette(context).surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
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
                        color: isIncome
                            ? appPalette(context).primary
                            : appPalette(context).tertiary,
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
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 11,
                              color: appPalette(context).onSurfaceVariant,
                            ),
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
                      : appPalette(context).surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isIncome
                      ? appL10n(context).msgIncome383
                      : appL10n(context).msgExpense384,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isIncome
                        ? appPalette(context).primary
                        : appPalette(context).onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: appPalette(context).surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appL10n(context).msgAmountInVnd385,
                      style: TextStyle(
                        fontSize: 10,
                        color: appPalette(context).onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      formatMoney(
                        context,
                        isIncome ? draft.amount : -draft.amount,
                        showSign: true,
                      ),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: isIncome
                            ? appPalette(context).primary
                            : appPalette(context).error,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: appPalette(context).surfaceContainer,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Text(
                    draft.walletName ??
                        appL10n(context).msgSelectAMoneySource301,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (msg.saved)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle,
                  color: appPalette(context).primary,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  appL10n(context).msgSavedToNotebook386,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: appPalette(context).primary,
                  ),
                ),
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
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(
                      appL10n(context).msgEdit244,
                      style: TextStyle(color: appPalette(context).onSurface),
                    ),
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
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle, size: 16),
                    label: Text(
                      isIncome
                          ? appL10n(context).msgSaveIncome213
                          : appL10n(context).msgSaveTransaction214,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: appPalette(context).primary,
                      foregroundColor: appPalette(context).onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildInputBar(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      child: GlassCard(
        blur: true,
        radius: 26,
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: appPalette(context).primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    appL10n(context).msgTodayAiRequests387(
                      (_aiDailyCount ?? '–').toString(),
                      (_aiDailyLimit).toString(),
                    ),
                    style: TextStyle(
                      fontSize: 10,
                      color: appPalette(context).onSurfaceVariant,
                    ),
                  ),
                ),
                Text(
                  'Gemini',
                  style: TextStyle(
                    fontSize: 10,
                    color: appPalette(context).outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                if (!_queryMode)
                  IconButton(
                    tooltip: appL10n(context).msgScanReceipt192,
                    icon: const Icon(Icons.document_scanner_outlined, size: 22),
                    onPressed: _isThinking || _isRecording
                        ? null
                        : _scanReceipt,
                  ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: !_isThinking,
                    textInputAction: TextInputAction.send,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      hintText: _isRecording
                          ? appL10n(context).msgListening388
                          : _queryMode
                          ? appL10n(context).financeAskHint
                          : appL10n(context).msgVietnameseExampleCPhK389,
                      hintStyle: const TextStyle(fontSize: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (text) => _sendMessage(text),
                  ),
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _controller,
                  builder: (context, value, _) {
                    final send = value.text.trim().isNotEmpty && !_isRecording;
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            appPalette(context).primary,
                            appPalette(context).secondary,
                          ],
                        ),
                      ),
                      child: IconButton(
                        tooltip: _isRecording
                            ? appL10n(context).msgStopRecording390
                            : send
                            ? appL10n(context).msgSendRecord391
                            : appL10n(context).msgRecordByVoice191,
                        onPressed: _isThinking
                            ? null
                            : send
                            ? () => _sendMessage(value.text)
                            : _toggleVoice,
                        icon: Icon(
                          _isRecording
                              ? Icons.stop_rounded
                              : send
                              ? Icons.arrow_upward_rounded
                              : Icons.mic_none_rounded,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _OfflineBatchWriter implements QuickRecordBatchWriter {
  _OfflineBatchWriter(this.repository);
  final OfflineWalletRepository repository;
  @override
  Future<void> addTransactions(List<TransactionDraft> drafts) =>
      repository.addTransactions(drafts);
}
