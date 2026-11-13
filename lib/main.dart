import 'package:fitapp/app/app.dart';
import 'package:fitapp/app/router.dart';
import 'package:fitapp/core/platform_rest_alerts.dart';
import 'package:fitapp/core/rest_alerts.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  final db = AppDatabase.open();
  final alerts = PlatformRestAlerts();
  final container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(db),
      restAlertsProvider.overrideWithValue(alerts),
    ],
  );
  await alerts.init(
    onOpenWorkout: () => container.read(routerProvider).go(Routes.workout),
  );
  runApp(
    UncontrolledProviderScope(container: container, child: const FitApp()),
  );
}
