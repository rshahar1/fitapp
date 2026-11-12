import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/widgets/section_header.dart';
import 'package:material_ui/material_ui.dart';

/// Rounded surface card with hairline-separated children.
class Group extends StatelessWidget {
  /// Creates a group.
  const new({super.key, required this.children, this.header});

  /// Rows.
  final List<Widget> children;

  /// Optional header above the card.
  final String? header;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        items.add(const Divider(indent: Space.m));
      }
      items.add(children[i]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null) SectionHeader(header!),
        Material(
          color: AppColors.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(Radii.card)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: items),
        ),
      ],
    );
  }
}

/// A row inside a [Group].
class GroupRow extends StatelessWidget {
  /// Creates a row.
  const new({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.showChevron = false,
  });

  /// Main text.
  final String title;

  /// Secondary text.
  final String? subtitle;

  /// Leading widget.
  final Widget? leading;

  /// Trailing widget.
  final Widget? trailing;

  /// Tap handler.
  final VoidCallback? onTap;

  /// Show a trailing chevron.
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: Sizes.tap + Space.xs),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.m,
            vertical: Space.s,
          ),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: Space.m),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: theme.bodyLarge),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: theme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: Space.s),
                trailing!,
              ],
              if (showChevron) ...[
                const SizedBox(width: Space.xs),
                const Icon(Icons.chevron_right, color: AppColors.textTertiary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
