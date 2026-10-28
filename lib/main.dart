import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/supabase/supabase_providers.dart';
import 'core/config/env.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_gate.dart';

/// Entry point of the Túi Khôn Flutter application.
/// Connects to Supabase (keys from `--dart-define-from-file=.env`), then
/// AuthGate shows Login or the dashboard depending on the saved session.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(['Plus Jakarta Sans'],
        await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  final preferences = await SharedPreferences.getInstance();
  final offlineAccount = preferences.getString('offline_account_id');

  if (Env.isSupabaseConfigured) {
    await Supabase.initialize(
        url: Env.supabaseUrl, publishableKey: Env.supabaseAnonKey);
  }

  // Edge-to-Edge display configuration for iOS and Android
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    ProviderScope(
      overrides: [
        offlineAccountIdProvider.overrideWith((ref) => offlineAccount)
      ],
      child: const TuiKhonApp(),
    ),
  );
}

/// Root widget configuring the application theme and the AuthGate root route.
class TuiKhonApp extends StatelessWidget {
  const TuiKhonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Túi Khôn',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Env.isSupabaseConfigured
          ? const AuthGate()
          : const MissingConfigScreen(),
    );
  }
}
