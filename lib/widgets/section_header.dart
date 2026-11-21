import 'package:fitapp/app/theme/tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Small display-face header above a group.
class SectionHeader extends StatelessWidget {
  /// Creates a header.
  const new(this.text, {super.key, this.trailing});

  /// Header text (the display face draws capitals).
  final String text;

  /// Optional trailing widget.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: Space.m,
        right: Space.m,
        top: Space.l,
        bottom: Space.s,
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(text, style: Theme.of(context).textTheme.labelSmall),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
