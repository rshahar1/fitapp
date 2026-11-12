import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Haptic feedback abstraction (selection tick, success and warning pulses).
abstract interface class Haptics {
  /// Light selection tick.
  void tick();

  /// Success pulse.
  void success();

  /// Warning pulse.
  void warning();
}

/// Haptics backed by the platform.
class PlatformHaptics implements Haptics {
  /// Creates the platform haptics.
  const new();

  @override
  void tick() => HapticFeedback.selectionClick();

  @override
  void success() => HapticFeedback.mediumImpact();

  @override
  void warning() => HapticFeedback.heavyImpact();
}

/// Provides [Haptics]; override in tests.
final hapticsProvider = Provider<Haptics>((ref) => const PlatformHaptics());
