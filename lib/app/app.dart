import 'package:fitapp/app/backdrop.dart';
import 'package:fitapp/app/router.dart';
import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/features/workout/rest_timer_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class FitApp extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<FitApp> createState() => _FitAppState();
}

class _FitAppState extends ConsumerState<FitApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: _background,
      onPause: _background,
      onShow: _foreground,
      onResume: _foreground,
    );
  }

  void _background() => ref.read(restTimerProvider.notifier).onBackground();

  void _foreground() => ref.read(restTimerProvider.notifier).onForeground();

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'FitApp',
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    darkTheme: buildAppTheme(),
    themeMode: ThemeMode.dark,
    routerConfig: ref.watch(routerProvider),
    builder: (context, child) => AppBackdrop(child: child ?? const SizedBox()),
  );
}
