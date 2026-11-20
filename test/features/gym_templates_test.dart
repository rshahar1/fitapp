import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fitapp/app/router.dart';
import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/data/repositories/template_repository.dart';
import 'package:fitapp/features/templates/templates_screen.dart';
import 'package:fitapp/features/you/you_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

const _incline = '00000000-0000-4000-8000-000000000002';

void main() {
  late AppDatabase db;
  late TemplateRepository templates;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    templates = TemplateRepository(db);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 10));
    await tester.runAsync(db.close);
  }

  Future<void> pumpApp(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => home),
        GoRoute(
          path: Routes.templates,
          builder: (_, _) => const Scaffold(body: Text('templates page')),
        ),
        GoRoute(
          path: Routes.newTemplate,
          builder: (_, _) => const Scaffold(body: Text('new template page')),
        ),
        GoRoute(
          path: '/template/:id',
          builder: (_, s) =>
              Scaffold(body: Text('template ${s.pathParameters['id']}')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
      ),
    );
    await settle(tester);
  }

  testWidgets('You screen lists Library, Gym Templates, Settings in order', (
    tester,
  ) async {
    await pumpApp(tester, const YouScreen());
    final library = tester.getTopLeft(find.text('Gym Exercise Library')).dy;
    final tpl = tester.getTopLeft(find.text('Gym Templates')).dy;
    final settings = tester.getTopLeft(find.text('Settings')).dy;
    expect(library, lessThan(tpl));
    expect(tpl, lessThan(settings));
    await tester.tap(find.text('Gym Templates'));
    await settle(tester);
    expect(find.text('templates page'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Templates screen shows the empty state', (tester) async {
    await pumpApp(tester, const TemplatesScreen());
    expect(find.text('No templates yet'), findsOneWidget);
    expect(
      find.text('Create a template to start a routine in one tap.'),
      findsOneWidget,
    );
    await unmount(tester);
  });

  testWidgets('Templates screen lists a template and opens it', (tester) async {
    final id = await tester.runAsync(
      () => templates.create(name: 'Push', exerciseIds: [_incline]),
    );
    await pumpApp(tester, const TemplatesScreen());
    expect(find.text('Push'), findsOneWidget);
    expect(find.text('No templates yet'), findsNothing);
    await tester.tap(find.text('Push'));
    await settle(tester);
    expect(find.text('template $id'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('New template opens the editor route', (tester) async {
    await pumpApp(tester, const TemplatesScreen());
    await tester.tap(find.text('New template'));
    await settle(tester);
    expect(find.text('new template page'), findsOneWidget);
    await unmount(tester);
  });
}
