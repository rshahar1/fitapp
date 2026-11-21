import 'package:fitapp/app/theme/tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Centered icon, title, message and optional action.
class EmptyState extends StatelessWidget {
  /// Creates an empty state.
  const new({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  /// Illustration icon.
  final IconData icon;

  /// Title.
  final String title;

  /// Optional explanation.
  final String? message;

  /// Optional action widget (e.g. an AppButton).
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: Space.xxl, color: AppColors.textTertiary),
            const SizedBox(height: Space.m),
            Text(title, style: text.titleLarge, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: Space.s),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: Space.l), action!],
          ],
        ),
      ),
    );
  }
}
