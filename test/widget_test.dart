import 'package:flutter_test/flutter_test.dart';
import 'package:tui_khon_mobile/main.dart';

void main() {
  testWidgets('shows onboarding on the first launch', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TuiKhonApp(onboardingDone: false));

    expect(find.text('Chào mừng đến Túi Khôn'), findsOneWidget);
    expect(find.text('Bỏ qua'), findsOneWidget);
    expect(find.text('Tiếp tục'), findsOneWidget);
  });

  testWidgets('moves to the next onboarding page', (WidgetTester tester) async {
    await tester.pumpWidget(const TuiKhonApp(onboardingDone: false));

    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();

    expect(find.text('Quản lý thu chi dễ dàng'), findsOneWidget);
  });
}
