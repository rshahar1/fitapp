import 'package:fitapp/app/router.dart';
import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/features/settings/privacy_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('renders the explanation', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildAppTheme(), home: const PrivacyScreen()),
    );
    expect(find.text('Step data & privacy'), findsOneWidget);
    expect(find.text('What FitApp reads'), findsOneWidget);
    expect(find.text('What FitApp does not do'), findsOneWidget);
    expect(find.text('How to turn it off'), findsOneWidget);
  });

  testWidgets('route /privacy resolves and back goes to Train', (tester) async {
    final router = GoRouter(
      initialLocation: Routes.privacy,
      routes: [
        GoRoute(path: Routes.privacy, builder: (_, _) => const PrivacyScreen()),
        GoRoute(
          path: Routes.train,
          builder: (_, _) => const Text('train-home'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PrivacyScreen), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('train-home'), findsOneWidget);
  });

  test('buildRouter registers the privacy route', () {
    final router = buildRouter();
    addTearDown(router.dispose);
    expect(Routes.privacy, '/privacy');
    expect(
      router.configuration.routes.whereType<GoRoute>().map((r) => r.path),
      contains(Routes.privacy),
    );
  });
}
