import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tui_khon_mobile/core/config/env.dart';
import 'package:tui_khon_mobile/core/theme/app_theme.dart';
import 'package:tui_khon_mobile/core/utils/error_messages.dart';
import 'package:tui_khon_mobile/features/auth/data/auth_repository.dart';
import 'package:tui_khon_mobile/features/auth/providers/auth_providers.dart';
import 'package:tui_khon_mobile/features/auth/presentation/login_screen.dart';
import 'package:tui_khon_mobile/features/auth/presentation/register_screen.dart';
import 'package:tui_khon_mobile/features/auth/presentation/widgets/auth_widgets.dart';

class TestAuth extends AuthRepository {
  TestAuth()
      : super(SupabaseClient('http://127.0.0.1:54321', 'test',
            authOptions: const AuthClientOptions(autoRefreshToken: false)));
  int calls = 0;
  Completer<void>? pending;
  @override
  Future<void> signInWithPassword(
      {required String email, required String password}) async {
    calls++;
    await pending?.future;
    throw const AuthException('invalid', code: 'invalid_credentials');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final boundary = GlobalKey();
  late TestAuth auth;
  setUp(() => auth = TestAuth());
  setUpAll(() async {
    await (FontLoader('PlusJakartaSans')
          ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  Future<void> pump(WidgetTester t,
      {Widget home = const LoginScreen(),
      double width = 390,
      double height = 844,
      double scale = 1,
      double keyboard = 0}) async {
    t.view.physicalSize = Size(width, height);
    t.view.devicePixelRatio = 1;
    t.view.padding = const FakeViewPadding(top: 28, bottom: 16);
    t.view.viewInsets = FakeViewPadding(bottom: keyboard);
    addTearDown(t.view.reset);
    await t.pumpWidget(RepaintBoundary(
        key: boundary,
        child: ProviderScope(
            overrides: [authRepositoryProvider.overrideWithValue(auth)],
            child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.light,
                home: home,
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!)))));
    await t.runAsync(() async {
      final context = t.element(find.byType(Scaffold).first);
      await precacheImage(
          const AssetImage('assets/images/google-g.png'), context);
      await precacheImage(
          const AssetImage(AuthHeroIllustration.asset), context);
    });
    await t.pumpAndSettle();
  }

  Future<void> capture(WidgetTester t, String name) async {
    final directory = Platform.environment['TUIKHON_UI_PREVIEW_DIR'];
    if (directory == null) return;
    await t.runAsync(() async {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(directory).create(recursive: true);
      await File('$directory/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets('login register navigation and local Google explanation',
      (t) async {
    await pump(t);
    await capture(t, 'login');
    await t.tap(find.text('Tiếp tục với Google'));
    await t.pumpAndSettle();
    expect(find.textContaining('Google chưa được cấu hình.'), findsOneWidget);
    expect(auth.calls, 0);
    ScaffoldMessenger.of(t.element(find.byType(Scaffold).first))
        .hideCurrentSnackBar();
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Đăng ký ngay'));
    await t.tap(find.text('Đăng ký ngay'));
    await t.pumpAndSettle();
    expect(find.byType(RegisterScreen), findsOneWidget);
    await capture(t, 'register');
    await t.ensureVisible(find.text('Đăng nhập'));
    await t.tap(find.text('Đăng nhập'));
    await t.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('inline validation and password visibility', (t) async {
    await pump(t);
    await t.ensureVisible(find.text('Đăng nhập'));
    await t.tap(find.text('Đăng nhập'));
    await t.pumpAndSettle();
    expect(find.text('Vui lòng nhập email hợp lệ'), findsOneWidget);
    expect(auth.calls, 0);
    await t.ensureVisible(find.byTooltip('Hiện mật khẩu'));
    await t.tap(find.byTooltip('Hiện mật khẩu'));
    await t.pump();
    expect(find.byTooltip('Ẩn mật khẩu'), findsOneWidget);
  });
  testWidgets('busy login prevents duplicate submissions and shows auth error',
      (t) async {
    auth.pending = Completer<void>();
    await pump(t);
    await t.enterText(find.byType(TextFormField).first, 'tester@example.test');
    await t.enterText(find.byType(TextFormField).last, 'secret123');
    await t.ensureVisible(find.text('Đăng nhập'));
    await t.tap(find.text('Đăng nhập'));
    await t.pump();
    final fields = t.widgetList<TextField>(find.byType(TextField));
    fields.last.onSubmitted?.call('secret123');
    expect(auth.calls, 1);
    auth.pending!.complete();
    await t.pumpAndSettle();
    expect(find.text('Email hoặc mật khẩu không đúng'), findsOneWidget);
  });
  testWidgets('register validates confirmation and small screens with keyboard',
      (t) async {
    await pump(t,
        home: const RegisterScreen(), width: 320, scale: 1.4, keyboard: 280);
    final fields = find.byType(TextFormField);
    await t.enterText(fields.at(0), 'Tên thử');
    await t.enterText(fields.at(1), 'tester@example.test');
    await t.enterText(fields.at(2), 'secret123');
    await t.enterText(fields.at(3), 'different');
    await t.ensureVisible(find.text('Đăng ký'));
    await t.tap(find.text('Đăng ký'));
    await t.pumpAndSettle();
    expect(find.text('Mật khẩu nhập lại không khớp'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  for (final size in [const Size(390, 844), const Size(411, 914)]) {
    for (final register in [false, true]) {
      testWidgets(
          '${register ? 'Register' : 'Login'} fits $size without scrolling',
          (t) async {
        await pump(t,
            home: register ? const RegisterScreen() : const LoginScreen(),
            width: size.width,
            height: size.height);
        for (final input in find.byType(TextFormField).evaluate()) {
          final bounds = t.getRect(find.byWidget(input.widget));
          expect(bounds.top, greaterThanOrEqualTo(28));
          expect(bounds.bottom, lessThanOrEqualTo(size.height - 16));
        }
        final footer = t.getRect(find.text(register
            ? 'Đã có tài khoản?'
            : 'Ghi chép riêng theo tài khoản của bạn'));
        expect(footer.bottom, lessThanOrEqualTo(size.height - 16),
            reason: 'Footer must be visible before any scroll');
        if (!register) {
          final frame =
              t.getRect(find.byKey(const ValueKey('auth-hero-frame')));
          final image = t.widget<Image>(find.descendant(
              of: find.byType(AuthHeroIllustration),
              matching: find.byType(Image)));
          expect(image.fit, BoxFit.contain);
          expect(frame.height, 132);
          expect(frame.left, greaterThanOrEqualTo(24));
          expect(frame.right, lessThanOrEqualTo(size.width - 24));
        }
        await capture(
            t, '${register ? 'register' : 'login'}-${size.width.toInt()}');
        expect(t.takeException(), isNull);
      });
    }
  }
  for (final scale in [1.0, 1.4, 2.0]) {
    for (final register in [false, true]) {
      testWidgets(
          'small ${register ? 'Register' : 'Login'} at $scale text scale stays scrollable',
          (t) async {
        await pump(t,
            home: register ? const RegisterScreen() : const LoginScreen(),
            width: 320,
            height: 568,
            scale: scale,
            keyboard: 220);
        await t.ensureVisible(find.text(register ? 'Đăng ký' : 'Đăng nhập'));
        await t.tap(find.text(register ? 'Đăng ký' : 'Đăng nhập'));
        await t.pumpAndSettle();
        expect(find.text('Vui lòng nhập email hợp lệ'), findsOneWidget);
        await t.ensureVisible(find.text(register
            ? 'Đã có tài khoản?'
            : 'Ghi chép riêng theo tài khoản của bạn'));
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets(
      'hero asset decodes with a transparent margin around every object',
      (t) async {
    await t.runAsync(() async {
      final data = await rootBundle.load(AuthHeroIllustration.asset);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      final pixels =
          (await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba))!
              .buffer
              .asUint8List();
      final width = frame.image.width, height = frame.image.height;
      for (var x = 0; x < width; x++) {
        expect(pixels[x * 4 + 3], lessThanOrEqualTo(3));
        expect(
            pixels[((height - 1) * width + x) * 4 + 3], lessThanOrEqualTo(3));
      }
      for (var y = 0; y < height; y++) {
        expect(pixels[y * width * 4 + 3], lessThanOrEqualTo(3));
        expect(pixels[(y * width + width - 1) * 4 + 3], lessThanOrEqualTo(3));
      }
      expect(pixels.any((v) => v > 0), true);
      frame.image.dispose();
      codec.dispose();
    });
  });

  test('placeholder configuration and connection failures are distinguished',
      () {
    expect(
        Env.validSupabaseConfig(
            'https://your-project-ref.supabase.co', 'REPLACE_KEY'),
        false);
    expect(
        Env.validSupabaseConfig(
            'http://10.0.2.2:54321', 'sb_publishable_local'),
        true);
    expect(
        friendlyError(const SocketException('refused')), contains('máy chủ'));
    expect(
        friendlyError(const AuthException('bad', code: 'invalid_credentials')),
        'Email hoặc mật khẩu không đúng');
  });
}
