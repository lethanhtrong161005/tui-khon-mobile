import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/vietnamese_nlp_service.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../home/models/category_model.dart';
import '../../home/models/transaction_model.dart';
import '../../home/models/wallet_model.dart';
import '../../receipt/data/receipt_repository.dart';

/// One turn of the quick record conversation, sent back to Gemini as context
/// when the AI asked a follow-up question.
class ChatTurn {
  final bool fromUser;
  final String text;

  const ChatTurn({required this.fromUser, required this.text});

  Map<String, dynamic> toJson() => {'role': fromUser ? 'user' : 'model', 'text': text};
}

/// One independently editable transaction and its clarification context.
class QuickRecordItem {
  const QuickRecordItem({this.draft, this.sourceText = '', this.question, this.missingFields = const []});
  final TransactionDraft? draft;
  final String sourceText;
  final String? question;
  final List<String> missingFields;
  bool get needsClarification => missingFields.isNotEmpty || question != null || draft?.amount == 0;
  QuickRecordItem withDraft(TransactionDraft value) =>
      QuickRecordItem(draft: value, sourceText: sourceText, question: question, missingFields: missingFields);
  factory QuickRecordItem.fromJson(Map<String, dynamic> json) => QuickRecordItem(
      draft: json['draft'] == null ? null : TransactionDraft.fromAiJson((json['draft'] as Map).cast<String, dynamic>()),
      sourceText: json['source_text'] as String? ?? '',
      question: json['question'] as String?,
      missingFields: ((json['missing_fields'] as List?) ?? const []).cast<String>());
}

class QuickRecordResult {
  /// Transaction to confirm; null when the AI needs more information.
  final TransactionDraft? _draft;
  TransactionDraft? get draft =>
      items.map((i) => i.draft).whereType<TransactionDraft>().firstOrNull ?? drafts.firstOrNull ?? _draft;
  final List<TransactionDraft> drafts;
  final List<QuickRecordItem> items;
  List<QuickRecordItem> get allItems => items.isNotEmpty
      ? items.take(10).toList()
      : (drafts.isNotEmpty ? drafts : [if (_draft != null) _draft])
          .take(10)
          .map((d) => QuickRecordItem(
              draft: d,
              sourceText: d.note ?? '',
              question: question,
              missingFields: d.amount <= 0 ? ['amount'] : const []))
          .toList();

  List<TransactionDraft> get allDrafts => allItems.map((i) => i.draft).whereType<TransactionDraft>().toList();

  /// Follow-up question from the AI (missing amount, ambiguous amount...).
  final String? question;
  final List<String> warnings;
  final int? quotaUsed;
  final int? quotaLimit;

  /// True when Gemini was unreachable and the on-device parser was used.
  final bool offline;

  const QuickRecordResult({
    TransactionDraft? draft,
    this.drafts = const [],
    this.items = const [],
    this.question,
    this.warnings = const [],
    this.quotaUsed,
    this.quotaLimit,
    this.offline = false,
  }) : _draft = draft;
}

class QuickRecordRepository {
  QuickRecordRepository(this._client, this._receipts);

  final SupabaseClient _client;
  final ReceiptRepository _receipts;

  /// Sends [text] to the `ai-quick-record` Edge Function.
  /// Falls back to [VietnameseNlpService] when the function is unreachable;
  /// quota (429) and validation (400) errors are rethrown for the UI.
  Future<QuickRecordResult> parse(
    String text, {
    required List<CategoryModel> categories,
    required List<WalletModel> wallets,
    bool voice = false,
    List<ChatTurn> history = const [],
  }) async {
    try {
      return await _invoke({
        'text': text,
        'source': voice ? 'voice' : 'text',
        'history': history.map((t) => t.toJson()).toList(),
      });
    } on FunctionException catch (e) {
      if (e.status == 429 || e.status == 400 || e.status == 401 || e.status == 413) rethrow;
      return _parseOffline(history.isEmpty ? text : '${history.where((t) => t.fromUser).firstOrNull?.text ?? ''} $text',
          categories: categories, wallets: wallets, voice: voice);
    } on SocketException {
      return _parseOffline(history.isEmpty ? text : '${history.where((t) => t.fromUser).firstOrNull?.text ?? ''} $text',
          categories: categories, wallets: wallets, voice: voice);
    } on TimeoutException {
      return _parseOffline(history.isEmpty ? text : '${history.where((t) => t.fromUser).firstOrNull?.text ?? ''} $text',
          categories: categories, wallets: wallets, voice: voice);
    }
  }

  /// Uploads the receipt to Storage and lets Gemini Vision read it, in parallel.
  /// The draft carries `receiptPath`; if the AI cannot read the photo the user
  /// still gets an empty draft (with the stored photo) to fill in by hand.
  Future<QuickRecordResult> scanReceipt(PickedReceipt receipt) async {
    final upload = _receipts.upload(receipt);
    QuickRecordResult result;
    try {
      result = await _invoke({'imageBase64': base64Encode(receipt.bytes), 'mimeType': receipt.mimeType});
    } catch (e) {
      if (e is FunctionException && (e.status == 429 || e.status == 413 || e.status == 401)) {
        unawaited(upload.then((_) {}, onError: (_) {}));
        rethrow;
      }
      // AI unavailable / unreadable photo: keep the uploaded receipt for manual entry.
      result = const QuickRecordResult(
        question: 'AI chưa đọc được hóa đơn này, bạn nhập số tiền giúp mình nhé.',
        offline: true,
      );
    }

    final path = await upload;
    final draft = result.allDrafts.firstOrNull ?? const TransactionDraft(type: TransactionType.expense, amount: 0);
    return QuickRecordResult(
      draft: draft.copyWith(receiptPath: path, source: TransactionSource.receipt),
      items: result.allItems
          .where((i) => i.draft != null)
          .map((i) => i.withDraft(i.draft!.copyWith(receiptPath: path, source: TransactionSource.receipt)))
          .toList(),
      drafts: result.allDrafts.map((d) => d.copyWith(receiptPath: path, source: TransactionSource.receipt)).toList(),
      question:
          result.question ?? (result.allDrafts.isEmpty ? 'Mình chưa đọc được tổng tiền, bạn kiểm tra lại nhé.' : null),
      warnings: result.warnings,
      quotaUsed: result.quotaUsed,
      quotaLimit: result.quotaLimit,
      offline: result.offline,
    );
  }

  Future<QuickRecordResult> _invoke(Map<String, dynamic> body) async {
    try {
      if ((await Connectivity().checkConnectivity()).contains(ConnectivityResult.none)) {
        throw const SocketException('Offline');
      }
    } on SocketException {
      rethrow;
    } catch (_) {/* Request timeout is the fallback on platforms without this plugin. */}
    final response = await _client.functions.invoke('ai-quick-record', body: body).timeout(const Duration(seconds: 35));
    final data = ((response.data as Map)['data'] as Map).cast<String, dynamic>();
    final draftJson = (data['draft'] as Map?)?.cast<String, dynamic>();
    final drafts = ((data['drafts'] as List?) ?? const [])
        .take(10)
        .map((row) => TransactionDraft.fromAiJson((row as Map).cast<String, dynamic>()))
        .toList();
    final quota = (data['quota'] as Map?)?.cast<String, dynamic>();
    return QuickRecordResult(
      draft: draftJson == null ? null : TransactionDraft.fromAiJson(draftJson),
      drafts: drafts,
      items: ((data['items'] as List?) ?? const [])
          .take(10)
          .map((i) => QuickRecordItem.fromJson((i as Map).cast<String, dynamic>()))
          .toList(),
      question: data['question'] as String?,
      warnings: ((data['warnings'] as List?) ?? const []).cast<String>(),
      quotaUsed: (quota?['used'] as num?)?.toInt(),
      quotaLimit: (quota?['limit'] as num?)?.toInt(),
    );
  }

  /// AI chat calls used today (Vietnam time), or null before the first call.
  Future<int?> fetchTodayChatUsage() async {
    final today = DateTime.now().toUtc().add(const Duration(hours: 7)).toIso8601String().substring(0, 10);
    final row = await _client.from('ai_usage').select('count').eq('day', today).eq('kind', 'chat').maybeSingle();
    return (row?['count'] as num?)?.toInt();
  }

  QuickRecordResult _parseOffline(
    String text, {
    required List<CategoryModel> categories,
    required List<WalletModel> wallets,
    required bool voice,
  }) {
    final parsedDrafts = VietnameseNlpService.parseMultiple(text,
        includeIncomplete: true, source: voice ? TransactionSource.voice : TransactionSource.manual);
    if (parsedDrafts.isEmpty) {
      return const QuickRecordResult(
        question: 'Mình chưa thấy số tiền. Bạn nói rõ giúp mình nhé (vd: "ăn phở 65k")?',
        offline: true,
      );
    }
    return QuickRecordResult(
      items: parsedDrafts
          .map((d) => QuickRecordItem(
                draft: resolveDraftNames(d, categories, wallets),
                sourceText: d.note ?? text,
                question: d.amount <= 0 ? 'Khoản "${d.note}" bao nhiêu tiền? Bạn ghi rõ đơn vị nhé.' : null,
                missingFields: d.amount <= 0 ? const ['amount'] : const [],
              ))
          .toList(),
      offline: true,
    );
  }
}

/// Fills category / wallet ids of [draft] from their names, falling back to
/// the first active wallet.
TransactionDraft resolveDraftNames(
  TransactionDraft draft,
  List<CategoryModel> categories,
  List<WalletModel> wallets,
) {
  bool same(String a, String? b) => b != null && a.trim().toLowerCase() == b.trim().toLowerCase();

  final category = categories.where((c) => c.type == draft.type && same(c.name, draft.categoryName)).firstOrNull;
  final active = wallets.where((w) => !w.isArchived).toList();
  final wallet = active.where((w) => same(w.name, draft.walletName)).firstOrNull ?? active.firstOrNull;
  return draft.copyWith(
    categoryId: category?.id,
    categoryName: category?.name ?? draft.categoryName,
    walletId: wallet?.id,
    walletName: wallet?.name,
  );
}

final quickRecordRepositoryProvider = Provider<QuickRecordRepository>(
  (ref) => QuickRecordRepository(ref.watch(supabaseClientProvider), ref.watch(receiptRepositoryProvider)),
);
