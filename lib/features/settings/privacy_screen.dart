import 'package:fitapp/app/router.dart';
import 'package:fitapp/app/theme/tokens.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// What FitApp does with step data (feature 014). Also shown for Health
/// Connect's permission rationale intents.
class PrivacyScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget section(String title, String body) => Padding(
      padding: const EdgeInsets.only(bottom: Space.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.titleMedium),
          const SizedBox(height: Space.xs),
          Text(
            body,
            style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Step data & privacy'),
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.train),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(Space.m),
        children: [
          section(
            'What FitApp reads',
            'Your daily step count and distance from Health Connect, where Google Fit and '
                'other apps share it. Access is read-only and limited to steps and distance.',
          ),
          section(
            'What FitApp does not do',
            'Step data is not stored in the FitApp database, not backed up, '
                'and not sent anywhere. It is read when you open the app and '
                'shown on the Home screen.',
          ),
          section(
            'How to turn it off',
            'Go to Settings, then Activity, then switch off Daily steps. You '
                'can also revoke access for this app in Health Connect.',
          ),
        ],
      ),
    );
  }
}
