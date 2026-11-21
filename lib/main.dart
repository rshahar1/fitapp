import 'package:fitapp/app/app.dart';
import 'package:fitapp/app/router.dart';
import 'package:fitapp/core/env.dart';
import 'package:fitapp/core/health_connect_step_source.dart';
import 'package:fitapp/core/platform_rest_alerts.dart';
import 'package:fitapp/core/rest_alerts.dart';
import 'package:fitapp/core/step_source.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/data/tracking/sim/simulation_switch.dart';
import 'package:fitapp/features/tracking/simulation_driver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  // Dev builds only: `--dart-define=SIMULATE_GPS=true` (feature 019). The
  // simulation's clock then drives the app and the database alike.
  final simulation = kSimulateGps ? (valThorensSimulation()..start()) : null;
  final db = AppDatabase.open(clock: simulation?.now);
  final alerts = PlatformRestAlerts();
  final supabase = await _initSupabase();
  final container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(db),
      restAlertsProvider.overrideWithValue(alerts),
      stepSourceProvider.overrideWithValue(HealthConnectStepSource()),
      supabaseClientProvider.overrideWithValue(supabase),
      if (simulation != null) ...simulationOverrides(simulation),
    ],
  );
  if (simulation != null) driveSimulation(container, simulation);
  await alerts.init(
    onOpenWorkout: () => container.read(routerProvider).go(Routes.workout),
  );
  runApp(
    UncontrolledProviderScope(container: container, child: const FitApp()),
  );
}

/// Adds the bundled typefaces' SIL OFL licences to the licence page
/// (feature 034).
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (family, file) in const [
      ('Big Shoulders Display (PlateDisplay)', 'OFL-BigShouldersDisplay.txt'),
      ('Barlow', 'OFL-Barlow.txt'),
      ('Barlow Condensed', 'OFL-BarlowCondensed.txt'),
    ]) {
      final text = await rootBundle.loadString('assets/fonts/$file');
      yield LicenseEntryWithLineBreaks([family], text);
    }
  });
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
