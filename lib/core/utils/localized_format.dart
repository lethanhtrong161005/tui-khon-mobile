import 'package:flutter/widgets.dart';
import '../../l10n/app_l10n.dart';
import 'currency_formatter.dart';
import 'package:intl/intl.dart';
import '../../features/home/models/transaction_model.dart';

String formatMoney(BuildContext? context, num amount,
        {bool showSign = false}) =>
    CurrencyFormatter.formatVND(amount,
        showSign: showSign, locale: appL10n(context).localeName);

String transactionDisplayTitle(BuildContext context, TransactionModel tx) =>
    tx.note?.trim().isNotEmpty == true
        ? tx.note!.trim()
        : tx.categoryName ?? appL10n(context).transaction;

String financialDateTime(DateTime instant) => DateFormat('dd/MM/yyyy · HH:mm')
    .format(instant.toUtc().add(const Duration(hours: 7)));
