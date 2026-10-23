import 'dart:async';
import 'dart:convert';
import 'dart:io';

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

class QuickRecordResult {
  /// Transaction to confirm; null when the AI needs more information.
  final TransactionDraft? draft;

  /// Follow-up question from the AI (missing amount, ambiguous amount...).
  final String? question;
  final List<String> warnings;
  final int? quotaUsed;
  final int? quotaLimit;

  /// True when Gemini was unreachable and the on-device parser was used.
  final bool offline;

  const QuickRecordResult({
    this.draft,
    this.question,
    this.warnings = const [],
    this.quotaUsed,
    this.quotaLimit,
    this.offline = false,
  });
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
      return _parseOffline(text, categories: categories, wallets: wallets, voice: voice);
    } on SocketException {
      return _parseOffline(text, categories: categories, wallets: wallets, voice: voice);
    } on TimeoutException {
      return _parseOffline(text, categories: categories, wallets: wallets, voice: voice);
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
    final draft = result.draft ?? const TransactionDraft(type: TransactionType.expense, amount: 0);
    return QuickRecordResult(
      draft: draft.copyWith(receiptPath: path, source: TransactionSource.receipt),
      question: result.question ?? (result.draft == null ? 'Mình chưa đọc được tổng tiền, bạn kiểm tra lại nhé.' : null),
      warnings: result.warnings,
      quotaUsed: result.quotaUsed,
      quotaLimit: result.quotaLimit,
      offline: result.offline,
    );
  }

  Future<QuickRecordResult> _invoke(Map<String, dynamic> body) async {
    final response = await _client.functions.invoke('ai-quick-record', body: body);
    final data = ((response.data as Map)['data'] as Map).cast<String, dynamic>();
    final draftJson = (data['draft'] as Map?)?.cast<String, dynamic>();
    final quota = (data['quota'] as Map?)?.cast<String, dynamic>();
    return QuickRecordResult(
      draft: draftJson == null ? null : TransactionDraft.fromAiJson(draftJson),
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
    final parsed = VietnameseNlpService.parseInput(
      text,
      source: voice ? TransactionSource.voice : TransactionSource.manual,
    );
    if (parsed.amount <= 0) {
      return const QuickRecordResult(
        question: 'Mình chưa thấy số tiền. Bạn nói rõ giúp mình nhé (vd: "ăn phở 65k")?',
        offline: true,
      );
    }
    return QuickRecordResult(draft: resolveDraftNames(parsed, categories, wallets), offline: true);
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
