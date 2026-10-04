import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/constants/app_colors.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/home/data/local_wallet_repository.dart';

/// Entry point of the Túi Khôn Flutter application.
/// Launches directly into the LoginScreen (Google & Phone/Password auth gate).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalWalletRepository.instance.initialize();

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

/// Root widget configuring the application theme and initial route to LoginScreen.
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
      // Starts directly at LoginScreen when opening the app
      home: const LoginScreen(),
    );
  }
}
