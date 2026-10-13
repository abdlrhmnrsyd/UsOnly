import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usonly/app/theme/app_theme.dart';
import 'package:usonly/features/pairing/presentation/pairing_onboarding_screen.dart';

void main() {
  testWidgets('Pairing onboarding renders warm intimate copy and buttons', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const PairingOnboardingScreen(),
      ),
    );

    // Verify intimate brand copywriting
    expect(find.text('your person is one code away'), findsOneWidget);
    expect(find.text('this little space is just for the two of you.'), findsOneWidget);

    // Verify action buttons
    expect(find.text('create connection code'), findsOneWidget);
    expect(find.text("enter partner's code"), findsOneWidget);
  });
}
