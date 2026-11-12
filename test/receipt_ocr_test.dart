import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:tui_khon_mobile/features/home/models/category_model.dart';
import 'package:tui_khon_mobile/features/home/models/transaction_model.dart';
import 'package:tui_khon_mobile/features/home/models/wallet_model.dart';
import 'package:tui_khon_mobile/features/receipt/data/receipt_parser.dart';
import 'package:tui_khon_mobile/features/receipt/data/receipt_ocr_service.dart';

const sampleReceiptText = '''Saigon Co.op
Co.opFood D512 Trường Thọ
PHIẾU TÍNH TIỀN
01/11/2026 18:55
Bánh mì 7,600.00
Nước uống 12,000.00
Tổng tiền 62,700.00
Tổng số lượng hàng 6.000
Tiền khách trả 62,700.00
Tiền trả lại cho khách 0.00
Tổng tiền giảm giá 1,100.00
VAT 8.00 2,074.07
VAT 10.00 3,154.55
Chi tiết thanh toán
VIETCOMBANK 62,700.00''';

void main() {
  final categories = [
    const CategoryModel(
      id: 'food',
      name: 'Ăn uống',
      type: TransactionType.expense,
    ),
  ];
  final wallets = [
    const WalletModel(id: 'cash', name: 'Tiền mặt', type: 'cash'),
    const WalletModel(id: 'vcb', name: 'TK Vietcombank', type: 'bank'),
  ];
  parse(String text, {List<WalletModel>? sources}) => ReceiptParser().parse(
    ReceiptOcrResult(text.split('\n').map((l) => ReceiptOcrLine(l)).toList()),
    categories: categories,
    wallets: sources ?? wallets,
    receiptPath: 'user/receipt.jpg',
  );

  test(
    'Co.op receipt uses final total, local calendar time and matching source',
    () {
      final result = parse(sampleReceiptText);
      expect(result.draft!.amount, 62700);
      expect(result.draft!.occurredAt, DateTime.utc(2026, 11, 1, 11, 55));
      expect(result.draft!.walletId, 'vcb');
      expect(result.draft!.type, TransactionType.expense);
      expect(result.draft!.merchant, contains('D512'));
      expect(result.allItems.single.needsClarification, false);
      expect(result.draft!.receiptPath, 'user/receipt.jpg');
    },
  );
  test('printed amounts reject fractional VND and preserve integer value', () {
    for (final value in [
      '62,700.00',
      '62.700,00',
      '62.700',
      '62,700',
      '62700',
      '62 700 VND',
    ]) {
      expect(printedVnd(value), 62700, reason: value);
    }
    for (final value in [
      '2,074.07',
      '62,700.50',
      '89347602120888',
      '6.00.00',
    ]) {
      expect(printedVnd(value), null, reason: value);
    }
  });
  test('unknown or archived source is never replaced by the first wallet', () {
    final result = parse(sampleReceiptText, sources: wallets.take(1).toList());
    expect(result.draft!.walletId, isNull);
    expect(result.allItems.single.missingFields, contains('wallet'));
    expect(result.allItems.single.needsClarification, true);
  });
  test('conflicting totals block saving and preserve evidence', () {
    final result = parse(
      '$sampleReceiptText\nTổng thanh toán 65.000 VND\nTổng cộng 70.000 VND',
    );
    expect(result.draft!.amount, 0);
    expect(result.warnings, contains('AMOUNT_MISMATCH'));
  });
  test(
    'transfer role is not inferred from successful transfer or recipient',
    () {
      final result = parse(
        'Chuyển khoản thành công\nNgười nhận Nguyễn A\nSố tiền 200.000 VND\n01/11/2026 18:55\nVIETCOMBANK',
      );
      expect(result.draft!.amount, 200000);
      expect(result.allItems.single.missingFields, contains('type'));
      expect(result.allItems.single.needsClarification, true);
      final incoming = parse(
        'Bạn đã nhận\nChuyển khoản\nSố tiền 200.000 VND\n01/11/2026 18:55\nVIETCOMBANK',
      );
      expect(incoming.draft!.type, TransactionType.income);
    },
  );
  test('unreadable images retain a manual draft with missing fields', () {
    final result = parse('');
    expect(result.draft!.amount, 0);
    expect(result.draft!.receiptPath, 'user/receipt.jpg');
    expect(
      result.allItems.single.missingFields,
      containsAll(['amount', 'date', 'wallet']),
    );
  });
  test('OCR label and right-hand amount are merged using their geometry', () {
    final result = ReceiptParser().parse(
      const ReceiptOcrResult([
        ReceiptOcrLine('Tổng tiền', bounds: Rect.fromLTWH(10, 100, 80, 20)),
        ReceiptOcrLine('62,700.00', bounds: Rect.fromLTWH(200, 102, 90, 20)),
        ReceiptOcrLine('VAT', bounds: Rect.fromLTWH(10, 140, 30, 20)),
        ReceiptOcrLine('2,074.07', bounds: Rect.fromLTWH(200, 140, 90, 20)),
      ]),
      categories: categories,
      wallets: wallets,
      receiptPath: 'user/receipt.jpg',
    );
    expect(result.draft!.amount, 62700);
  });
  test('skewed label and amount share a row after baseline projection', () {
    final result = ReceiptParser().parse(const ReceiptOcrResult([
      ReceiptOcrLine('Tổng tiền',bounds:Rect.fromLTWH(10,100,80,20),angle:.157),
      ReceiptOcrLine('62,700.00',bounds:Rect.fromLTWH(200,136,90,20),angle:.157),
    ]),categories:categories,wallets:wallets,receiptPath:'user/image.jpg');
    expect(result.draft!.amount,62700);
  });
  test('OCR spacing is normalized only inside labelled money and date tokens', () {
    final result = parse('Co.opFood\n01 / 11 / 2026 18 : 55\nTổng tiền 62, 700.00\nVIETCOMBANK');
    expect(result.draft!.amount,62700);
    expect(result.draft!.occurredAt,DateTime.utc(2026,11,1,11,55));
    final low=ReceiptParser().parse(const ReceiptOcrResult([
      ReceiptOcrLine('Tổng tiền 62 700',confidence:.3),
    ]),categories:categories,wallets:wallets,receiptPath:'user/image.jpg');
    expect(low.draft!.amount,62700);
    expect(low.allItems.single.missingFields,contains('review'));
  });
}
