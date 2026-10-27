import '../../core/offline/duplicate_service.dart';
import '../../core/offline/local_store.dart';
import '../home/models/transaction_model.dart';
import 'csv_exchange.dart';

String csvMappingKey(String entity, JsonRow row) =>
    '$entity|${entity == 'categories' ? row['type'] : ''}|${row[entity == 'wallets' ? 'wallet' : 'category']}';

class CsvImportPlan {
  final List<LocalMutation> mutations = [];
  final Set<int> duplicates = {}, existingIds = {};
  final Map<int, String> errors = {};
  int get transactionCount =>
      mutations.where((m) => m.entity == 'transactions').length;
}

/// Mapping precedes duplicate detection. IDs only insert; debt CSV records have
/// no debt_payment_id or debt_id and remain standalone transactions.
class CsvImportPlanner {
  CsvImportPlanner(this.store);
  final LocalStore store;

  Future<CsvImportPlan> build(List<CsvPreviewRow> preview, Set<int> selected,
      {required String? Function(String, JsonRow) resolve,
      required bool allowCreation,
      required bool skipDuplicates}) async {
    final plan = CsvImportPlan();
    final ids = (await store.rows('transactions'))
        .map((r) => '${r['id']}'.toLowerCase())
        .toSet();
    final created = <String, String>{};
    final batch = <JsonRow>[];
    final duplicateService = DuplicateService(store);
    for (final item in preview) {
      if (!selected.contains(item.line) ||
          item.error != null ||
          item.conflict) {
        continue;
      }
      final row = Map<String, dynamic>.from(item.values);
      final originalId = '${row['id'] ?? ''}'.toLowerCase();
      if (originalId.isNotEmpty && ids.contains(originalId)) {
        plan.existingIds.add(item.line);
        continue;
      }
      final additions = <LocalMutation>[];
      final newIds = <String, String>{};
      for (final entity in ['wallets', 'categories']) {
        final label =
            '${row[entity == 'wallets' ? 'wallet' : 'category']}'.trim();
        if (entity == 'categories' && label.isEmpty) {
          row['category_id'] = null;
          continue;
        }
        final key = csvMappingKey(entity, row);
        var id = resolve(entity, row) ?? created[key];
        if (id == null) {
          if (!allowCreation) {
            plan.errors[item.line] = 'Ánh xạ hoặc xác nhận tạo: $label';
            break;
          }
          id = exchangeId();
          newIds[key] = id;
          additions.add(LocalMutation(entity, {
            'id': id,
            'name': label,
            'type': entity == 'wallets' ? 'cash' : row['type'],
            'icon': entity == 'wallets' ? 'account_balance_wallet' : 'category',
            if (entity == 'wallets') 'initial_balance': 0,
          }));
        }
        row[entity == 'wallets' ? 'wallet_id' : 'category_id'] = id;
      }
      if (plan.errors.containsKey(item.line)) continue;
      row.remove('wallet');
      row.remove('category');
      final at = DateTime.parse(row['occurred_at'] as String);
      final draft = TransactionDraft(
          type: TransactionType.fromValue(row['type'] as String),
          amount: row['amount'] as int,
          walletId: row['wallet_id'] as String,
          occurredAt: at);
      final matches = await duplicateService.find(draft);
      // Same predicate as DuplicateService for rows not persisted yet. In this
      // matcher "source" means the mapped funding wallet, not provenance.
      final batchMatch = batch.any((r) =>
          r['type'] == row['type'] &&
          r['amount'] == row['amount'] &&
          r['wallet_id'] == row['wallet_id'] &&
          DateTime.parse(r['occurred_at'] as String).difference(at).abs() <=
              const Duration(minutes: 10));
      if (matches.isNotEmpty || batchMatch) {
        plan.duplicates.add(item.line);
        if (skipDuplicates) continue;
      }
      row['id'] = originalId.isEmpty ? exchangeId() : originalId;
      ids.add(row['id'] as String);
      batch.add(row);
      created.addAll(newIds);
      plan.mutations.addAll([...additions, LocalMutation('transactions', row)]);
    }
    return plan;
  }
}
