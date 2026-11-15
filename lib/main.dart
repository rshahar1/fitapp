import 'package:fitapp/app/app.dart';
import 'package:fitapp/app/router.dart';
import 'package:fitapp/core/env.dart';
import 'package:fitapp/core/platform_rest_alerts.dart';
import 'package:fitapp/core/rest_alerts.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  final db = AppDatabase.open();
  final alerts = PlatformRestAlerts();
  final supabase = await _initSupabase();
  final container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(db),
      restAlertsProvider.overrideWithValue(alerts),
      supabaseClientProvider.overrideWithValue(supabase),
    ],
  );
  await alerts.init(
    onOpenWorkout: () => container.read(routerProvider).go(Routes.workout),
  );
  runApp(
    UncontrolledProviderScope(container: container, child: const FitApp()),
  );
}

/// Cloud backup is optional (feature 013): without configuration, or if
/// initialisation fails, the app runs fully offline.
Future<SupabaseClient?> _initSupabase() async {
  if (!Env.isSyncConfigured) return null;
  try {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseAnonKey,
    );
    return Supabase.instance.client;
  } on Object catch (e) {
    debugPrint('Cloud backup unavailable: $e');
    return null;
  }
}
