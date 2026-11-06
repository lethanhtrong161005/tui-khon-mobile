import 'package:flutter/widgets.dart';
import '../../features/planning/models/planning_models.dart';
import '../../l10n/app_l10n.dart';

String? debtDueLabel(BuildContext context, DebtModel debt, DateTime today) {
  final days = debt.daysUntilDue(today);
  final l = appL10n(context);
  if (days == null) return null;
  if (days < 0) return l.daysOverdue(-days);
  if (days == 0) return l.msgDueToday270;
  if (days == 1) return l.dueTomorrow;
  return l.daysRemaining(days);
}
