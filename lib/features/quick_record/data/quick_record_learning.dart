import '../../../core/offline/local_store.dart';
import '../../../core/services/vietnamese_nlp_service.dart';
import '../../../core/utils/id_generator.dart';
import '../../home/models/category_model.dart';
import '../../home/models/transaction_model.dart';
import '../../home/models/wallet_model.dart';

/// Exact description corrections; amounts, dates and receipts are never learned.
class QuickRecordLearning {
  QuickRecordLearning(this.store);
  final LocalStore store;
  String _keyword(TransactionDraft draft) =>
      VietnameseNlpService.normalizeText(draft.note ?? '');
  String _normalize(Object? value) =>
      VietnameseNlpService.normalizeText(value as String? ?? '');
  Future<void> remember(
      TransactionDraft original, TransactionDraft edited) async {
    final keyword = _keyword(original);
    if (keyword.isEmpty || original.type != edited.type) return;
    if (original.categoryId != edited.categoryId && edited.categoryId != null) {
      final existing = (await store.rows('category_rules'))
          .where((r) =>
              _normalize(r['keyword']) == keyword &&
              _normalize(r['merchant']) == _normalize(original.merchant))
          .firstOrNull;
      await store.put('category_rules', {
        'id': existing?['id'] ?? newUuidV4(),
        'keyword': keyword,
        'merchant': _normalize(original.merchant).isEmpty
            ? null
            : _normalize(original.merchant),
        'category_id': edited.categoryId,
        'enabled': true,
      });
    }
  }

  Future<TransactionDraft> apply(TransactionDraft draft,
      List<CategoryModel> categories, List<WalletModel> wallets) async {
    final candidates = (await store.rows('category_rules'))
        .where((r) =>
            r['enabled'] != false &&
            _normalize(r['keyword']) == _keyword(draft) &&
            (_normalize(r['merchant']).isEmpty ||
                _normalize(r['merchant']) == _normalize(draft.merchant)) &&
            categories
                .any((c) => c.id == r['category_id'] && c.type == draft.type))
        .toList()
      ..sort((a, b) {
        final specificity = (_normalize(b['merchant']).isEmpty ? 0 : 1)
            .compareTo(_normalize(a['merchant']).isEmpty ? 0 : 1);
        return specificity != 0
            ? specificity
            : (a['id'] as String).compareTo(b['id'] as String);
      });
    final rule = candidates.firstOrNull;
    final category = categories
        .where((c) => c.id == rule?['category_id'] && c.type == draft.type)
        .firstOrNull;
    return draft.copyWith(
        categoryId: category?.id, categoryName: category?.name);
  }
}
