import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether today's steps can be read.
enum StepAccess { unavailable, needsInstall, notGranted, granted }

/// Platform boundary for the daily step count (specs/014-daily-steps).
/// Implementations must never throw; failures map to safe values.
abstract interface class StepSource {
  /// SDK availability plus read-permission state.
  Future<StepAccess> access();

  /// Shows the system permission prompt; true when steps may now be read.
  Future<bool> requestAccess();

  /// Opens the store page for Health Connect.
  Future<void> installHealthConnect();

  /// Total steps in [start, end); null when unavailable or on error.
  Future<int?> stepsBetween(DateTime start, DateTime end);
}

/// Used on unsupported platforms and in tests.
class NoopStepSource implements StepSource {
  const new();

  @override
  Future<StepAccess> access() async => StepAccess.unavailable;

  @override
  Future<bool> requestAccess() async => false;

  @override
  Future<void> installHealthConnect() async {}

  @override
  Future<int?> stepsBetween(DateTime start, DateTime end) async => null;
}

/// Local midnight of [now]'s calendar day.
DateTime todayStart(DateTime now) {
  final local = now.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// Days back from today whose steps can be read (Health Connect default).
const stepHistoryDays = 30;

/// The interval to read for local calendar [day], or null when [day] is in the
/// future or older than [stepHistoryDays]. Today ends at [now]; earlier days
/// end at the next local midnight (built by calendar arithmetic, DST-safe).
({DateTime start, DateTime end})? stepWindow(DateTime day, DateTime now) {
  final today = todayStart(now);
  final start = DateTime(day.year, day.month, day.day);
  final oldest = DateTime(today.year, today.month, today.day - stepHistoryDays);
  if (start.isAfter(today) || start.isBefore(oldest)) return null;
  final nextMidnight = DateTime(start.year, start.month, start.day + 1);
  final local = now.toLocal();
  return (
    start: start,
    end: nextMidnight.isAfter(local) ? local : nextMidnight,
  );
}

/// Overridden in main() with the Health Connect implementation on Android.
final stepSourceProvider = Provider<StepSource>(
  (ref) => const NoopStepSource(),
);
