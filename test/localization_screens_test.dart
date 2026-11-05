import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tui_khon_mobile/core/offline/local_store.dart';
import 'package:tui_khon_mobile/core/offline/sync_controller.dart';
import 'package:tui_khon_mobile/core/offline/sync_screen.dart';
import 'package:tui_khon_mobile/core/offline/offline_planning_repository.dart';
import 'package:tui_khon_mobile/core/theme/app_theme.dart';
import 'package:tui_khon_mobile/core/theme/appearance.dart';
import 'package:tui_khon_mobile/core/services/app_lock_service.dart';
import 'package:tui_khon_mobile/core/services/debt_reminder_service.dart';
import 'package:tui_khon_mobile/core/services/voice_input_service.dart';
import 'package:tui_khon_mobile/core/supabase/supabase_providers.dart';
import 'package:tui_khon_mobile/features/auth/providers/auth_providers.dart';
import 'package:tui_khon_mobile/features/auth/models/user_profile.dart';
import 'package:tui_khon_mobile/features/home/providers/home_providers.dart';
import 'package:tui_khon_mobile/features/planning/data/planning_repository.dart';
import 'package:tui_khon_mobile/features/planning/models/planning_models.dart';
import 'package:tui_khon_mobile/features/quick_record/data/quick_record_repository.dart';
import 'package:tui_khon_mobile/features/advisor/data/advisor_repository.dart';
import 'package:tui_khon_mobile/l10n/app_l10n.dart';
import 'fakes.dart';
import 'support/local_wallet_repository.dart';
import 'support/report_debt_fixture.dart';
import 'package:tui_khon_mobile/features/auth/presentation/login_screen.dart';
import 'package:tui_khon_mobile/features/auth/presentation/app_lock_screen.dart';
import 'package:tui_khon_mobile/features/auth/presentation/auth_gate.dart';
import 'package:tui_khon_mobile/features/planning/presentation/planning_screen.dart';
import 'package:tui_khon_mobile/features/auth/presentation/register_screen.dart';
import 'package:tui_khon_mobile/features/auth/presentation/forgot_password_screen.dart';
import 'package:tui_khon_mobile/features/auth/presentation/reset_password_screen.dart';
import 'package:tui_khon_mobile/features/auth/presentation/otp_verification_screen.dart';
import 'package:tui_khon_mobile/features/home/presentation/home_screen.dart';
import 'package:tui_khon_mobile/features/statistics/presentation/statistics_screen.dart';
import 'package:tui_khon_mobile/features/planning/presentation/budgets_tab.dart';
import 'package:tui_khon_mobile/features/planning/presentation/debts_tab.dart';
import 'package:tui_khon_mobile/features/planning/presentation/goals_tab.dart';
import 'package:tui_khon_mobile/features/planning/presentation/debt_history_screen.dart';
import 'package:tui_khon_mobile/features/planning/presentation/debt_payment_sheet.dart';
import 'package:tui_khon_mobile/features/profile/presentation/profile_settings_screen.dart';
import 'package:tui_khon_mobile/features/profile/presentation/edit_profile_screen.dart';
import 'package:tui_khon_mobile/features/transactions/presentation/transaction_history_screen.dart';
import 'package:tui_khon_mobile/features/quick_record/presentation/quick_record_screen.dart';
import 'package:tui_khon_mobile/features/quick_record/presentation/category_rules_screen.dart';
import 'package:tui_khon_mobile/features/advisor/presentation/advisor_screen.dart';
import 'package:tui_khon_mobile/features/reports/monthly_report_screen.dart';
import 'package:tui_khon_mobile/features/data_exchange/data_exchange_screen.dart';
import 'package:tui_khon_mobile/features/reminders/presentation/reminder_settings_screen.dart';
import 'package:tui_khon_mobile/features/reminders/presentation/payables_screen.dart';
import 'package:tui_khon_mobile/features/reminders/data/reminder_scheduler.dart';
import 'package:tui_khon_mobile/features/settings/presentation/categories_screen.dart';
import 'package:tui_khon_mobile/features/settings/presentation/wallets_screen.dart';

class NoNetwork implements SyncRemote {
  @override
  String? get userId => 'appearance-qa';
  @override
  Future<Map<String, dynamic>> pull(int cursor) async =>
      {'changes': [], 'cursor': cursor, 'has_more': false};
  @override
  Future<Map<String, dynamic>> push(Map<String, dynamic> parameters) async =>
      throw StateError('No network in UI fixtures');
  @override
  Future<void> upload(String path, Uint8List bytes, String mime) async {}
}

class QuietScheduler extends ReminderScheduler {
  QuietScheduler() : super(onRoute: (_) {});
  @override
  Future<void> replace(String group, List<ReminderNotice> notices) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LocalStore store;
  setUpAll(() async {
    await (FontLoader('PlusJakartaSans')
          ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = LocalStore.memory('appearance-qa');
    await seedReportDebtFixture(store);
  });
  tearDown(() => store.close());
  final screens = <String, Widget Function(DebtModel)>{
    'login': (_) => const LoginScreen(),
    'lock': (_) => const AppLockScreen(),
    'config': (_) => const MissingConfigScreen(),
    'planning': (_) => const PlanningScreen(),
    'register': (_) => const RegisterScreen(),
    'forgot': (_) => const ForgotPasswordScreen(),
    'reset': (_) => const ResetPasswordScreen(),
    'otp': (_) => const OtpVerificationScreen(
        email: 'qa@example.com', purpose: OtpPurpose.signup),
    'home': (_) => const HomeScreen(),
    'statistics': (_) => const StatisticsScreen(),
    'budgets': (_) => const Scaffold(body: BudgetsTab()),
    'debts': (_) => const Scaffold(body: DebtsTab()),
    'goals': (_) => const Scaffold(body: GoalsTab()),
    'debt-detail': (d) => DebtHistoryScreen(debt: d),
    'payment': (d) => Scaffold(body: DebtPaymentSheet(debt: d)),
    'profile': (_) => const ProfileSettingsScreen(),
    'edit-profile': (_) => const EditProfileScreen(initialName: 'QA'),
    'transactions': (_) => const TransactionHistoryScreen(),
    'quick-record': (_) => const QuickRecordScreen(),
    'rules': (_) => const CategoryRulesScreen(),
    'advisor': (_) => const AdvisorScreen(),
    'report': (_) => MonthlyReportScreen(initialMonth: DateTime(2026, 10)),
    'csv': (_) => const DataExchangeScreen(),
    'reminders': (_) => const ReminderSettingsScreen(),
    'payables': (_) => const PayablesScreen(),
    'categories': (_) => const CategoriesScreen(),
    'wallets': (_) => const WalletsScreen(),
    'sync': (_) => const SyncScreen(),
  };
  for (final layout in [
    (name: 'standard', size: const Size(390, 844), scale: 1.0, keyboard: 0.0),
    (name: 'large', size: const Size(411, 914), scale: 1.0, keyboard: 0.0),
    (name: 'small', size: const Size(320, 568), scale: 1.0, keyboard: 0.0),
    (name: 'text200', size: const Size(390, 844), scale: 2.0, keyboard: 0.0),
    (name: 'small200', size: const Size(320, 568), scale: 2.0, keyboard: 0.0),
    (name: 'keyboard', size: const Size(390, 844), scale: 1.4, keyboard: 300.0),
  ])
    for (final dark in [false, true])
      for (final language in ['vi', 'en'])
        for (final screen in screens.entries) {
          if (layout.name != 'standard' && (!dark || language != 'en'))
            continue;
          testWidgets(
              '${screen.key} ${dark ? 'dark' : 'light'} $language ${layout.name}',
              (tester) async {
            tester.view.physicalSize = layout.size;
            tester.view.viewInsets = FakeViewPadding(bottom: layout.keyboard);
            tester.view.devicePixelRatio = 1;
            tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
            addTearDown(tester.view.reset);
            final previousError = FlutterError.onError;
            FlutterError.onError = (details) {
              if (Platform.environment['TUIKHON_LAYOUT_DIAGNOSTICS'] == '1') {
                debugPrint(details.toString());
              }
              previousError!(details);
            };
            addTearDown(() => FlutterError.onError = previousError);
            final debt =
                (await OfflinePlanningRepository(store).fetchDebts()).single;
            final appearance = AppearanceController(null);
            await appearance.change(
                language: language,
                theme: dark ? ThemeMode.dark : ThemeMode.light);
            final boundary = GlobalKey();
            await tester.pumpWidget(RepaintBoundary(
                key: boundary,
                child: ProviderScope(
                    overrides: [
                      localStoreProvider.overrideWithValue(store),
                      currentUserIdProvider.overrideWithValue(store.userId),
                      sessionProvider.overrideWithValue(null),
                      appearanceProvider.overrideWith((ref) => appearance),
                      syncControllerProvider.overrideWith((ref) =>
                          SyncController.withRemote(store, NoNetwork(),
                              autoStart: false)),
                      walletRepositoryProvider
                          .overrideWithValue(LocalWalletRepository()),
                      planningRepositoryProvider.overrideWithValue(
                          FakePlanningRepository()..debts.clear()),
                      quickRecordRepositoryProvider
                          .overrideWithValue(FakeQuickRecordRepository()),
                      advisorRepositoryProvider
                          .overrideWithValue(FakeAdvisorRepository()),
                      debtRemindersProvider
                          .overrideWithValue(FakeDebtReminders()),
                      appLockProvider.overrideWithValue(FakeAppLock()),
                      voiceInputProvider
                          .overrideWithValue(FakeVoiceInput('Cà phê 35k')),
                      reminderSchedulerProvider
                          .overrideWithValue(QuietScheduler()),
                      profileProvider.overrideWith((ref) async =>
                          const UserProfile(
                              id: 'appearance-qa',
                              email: 'qa@example.com',
                              displayName: 'QA')),
                    ],
                    child: MaterialApp(
                        debugShowCheckedModeBanner: false,
                        theme: dark ? AppTheme.dark : AppTheme.light,
                        locale: Locale(language),
                        localizationsDelegates:
                            AppLocalizations.localizationsDelegates,
                        supportedLocales: AppLocalizations.supportedLocales,
                        builder: (context, child) => MediaQuery(
                            data: MediaQuery.of(context).copyWith(
                                textScaler: TextScaler.linear(layout.scale)),
                            child: child!),
                        home: screen.value(debt)))));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            final dir = Platform.environment['TUIKHON_APPEARANCE_PREVIEW'];
            if (dir != null && layout.name == 'standard')
              await tester.runAsync(() async {
                final image = await (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 1);
                final bytes =
                    await image.toByteData(format: ui.ImageByteFormat.png);
                await Directory(dir).create(recursive: true);
                await File(
                        '$dir/${screen.key}-${dark ? 'dark' : 'light'}-$language.png')
                    .writeAsBytes(bytes!.buffer.asUint8List());
                image.dispose();
              });
            await tester.pumpWidget(const SizedBox());
            await tester.pumpAndSettle();
          });
        }
}
