import 'dart:developer' as developer;

import 'package:material_ui/material_ui.dart';

/// Runs [action] and turns any error into a short message instead of a crash
/// (PRD §9.3 Errors). Returns true on success.
Future<bool> guard(
  BuildContext context,
  Future<void> Function() action, {
  String message = 'Something went wrong. Please try again.',
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    await action();
    return true;
  } on Object catch (e, st) {
    developer.log('Action failed', error: e, stackTrace: st, name: 'fitapp');
    final text = e is ArgumentError || e is StateError
        ? _clean(e.toString())
        : message;
    messenger?.showSnackBar(SnackBar(content: Text(text)));
    return false;
  }
}

String _clean(String s) => s
    .replaceFirst(RegExp(r'^(Bad state|Invalid argument\(s\)[^:]*): '), '')
    .trim();

/// Asks the user to confirm a destructive action (PRD §2.3 rule 6).
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
