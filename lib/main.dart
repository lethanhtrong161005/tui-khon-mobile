import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/env.dart';
import 'core/constants/app_colors.dart';
import 'features/auth/presentation/auth_gate.dart';

/// Entry point of the Túi Khôn Flutter application.
/// Connects to Supabase (keys from `--dart-define-from-file=.env`), then
/// AuthGate shows Login or the dashboard depending on the saved session.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Env.isSupabaseConfigured) {
    await Supabase.initialize(url: Env.supabaseUrl, publishableKey: Env.supabaseAnonKey);
  }

  // Edge-to-Edge display configuration for iOS and Android
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    const ProviderScope(
      child: TuiKhonApp(),
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
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          surface: AppColors.surface,
          error: AppColors.error,
        ),
        textTheme: GoogleFonts.plusJakartaSansTextTheme(
          Theme.of(context).textTheme,
        ),
      ),
      home: Env.isSupabaseConfigured ? const AuthGate() : const MissingConfigScreen(),
    );
  }
}
