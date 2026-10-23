import '../../features/home/models/transaction_model.dart';
import '../utils/currency_formatter.dart';

/// VietnameseNlpService processes natural Vietnamese conversational sentences
/// and extracts monetary amounts, transaction categories, and sources on-device.
///
/// It is the offline fallback of the Gemini quick record: the result carries
/// category / wallet *names* that the caller resolves to the user's ids.
class VietnameseNlpService {
  VietnameseNlpService._();

  /// Parses user text/voice input into a [TransactionDraft].
  /// `amount` is 0 when no amount could be found.
  static TransactionDraft parseInput(String input, {TransactionSource source = TransactionSource.manual}) {
    final lower = input.toLowerCase().trim();
    final amount = CurrencyFormatter.parseSlangAmount(lower);

    // Whole-word match so that "thuê" is not read as "thu" and "căn hộ" not as "ăn"
    bool has(List<String> words) => words.any(
          (w) => RegExp('(?<!\\p{L})${RegExp.escape(w)}(?!\\p{L})', unicode: true).hasMatch(lower),
        );

    // Determine whether this is income or expense
    final isIncome = has(['trúng', 'lương', 'thưởng', 'nhận', 'thu', 'thu nhập', 'được cho']);

    // Categorization logic based on Vietnamese keywords
    String category = 'Chi tiêu khác';

    if (has(['phở', 'ăn', 'cafe', 'cà phê', 'cơm', 'bún', 'trà sữa'])) {
      category = 'Ăn uống';
    } else if (has(['xăng', 'xe', 'grab', 'buýt', 'taxi'])) {
      category = 'Di chuyển';
    } else if (has(['nhà', 'phòng', 'điện', 'nước', 'thuê', 'căn hộ'])) {
      category = 'Nhà ở & Tiện ích';
    } else if (has(['mua', 'áo', 'quần', 'shopee', 'lazada'])) {
      category = 'Mua sắm & Tiêu dùng';
    } else if (has(['lương'])) {
      category = 'Lương';
    } else if (isIncome) {
      category = 'Thu nhập khác';
    }

    // Determine payment wallet/account
    String? walletSource;
    if (lower.contains('momo')) {
      walletSource = 'Ví MoMo';
    } else if (lower.contains('vcb') || lower.contains('vietcombank')) {
      walletSource = 'Vietcombank';
    } else if (lower.contains('techcombank')) {
      walletSource = 'Techcombank';
    } else if (lower.contains('tiền mặt')) {
      walletSource = 'Tiền mặt';
    }

    // Generate a clean title
    String title = input.trim();
    if (title.length > 60) {
      title = '${title.substring(0, 57)}...';
    }

    return TransactionDraft(
      type: isIncome ? TransactionType.income : TransactionType.expense,
      amount: amount,
      categoryName: category,
      walletName: walletSource,
      note: title,
      occurredAt: DateTime.now(),
      source: source,
    );
  }
}
