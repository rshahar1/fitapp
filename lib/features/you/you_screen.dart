import 'package:fitapp/app/router.dart';
import 'package:fitapp/app/theme/app_icons.dart';
import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/widgets/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// You tab (feature 011): exercise library, gym templates (feature 028)
/// and settings.
class YouScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Space.m),
          children: [
            Text('You', style: text.headlineLarge),
            const SizedBox(height: Space.m),
            Group(
              children: [
                GroupRow(
                  title: 'Gym Exercise Library',
                  leading: const Icon(AppIcons.listAlt),
                  showChevron: true,
                  onTap: () => context.push(Routes.exercises),
                ),
                GroupRow(
                  title: 'Gym Templates',
                  leading: const Icon(AppIcons.list),
                  showChevron: true,
                  onTap: () => context.push(Routes.templates),
                ),
                GroupRow(
                  title: 'Settings',
                  leading: const Icon(AppIcons.settings),
                  showChevron: true,
                  onTap: () => context.push(Routes.settings),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
