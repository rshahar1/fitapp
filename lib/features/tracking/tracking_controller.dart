import 'dart:async';
import 'dart:developer' as developer;

import 'package:fitapp/data/providers.dart';
import 'package:fitapp/data/repositories/tracking_repository.dart';
import 'package:fitapp/data/tracking/location_source.dart';
import 'package:fitapp/domain/activity_types.dart';
import 'package:fitapp/domain/tracking/track_profile.dart';
import 'package:fitapp/domain/tracking/track_reducer.dart' as reducer;
import 'package:fitapp/domain/tracking/track_sample.dart';
import 'package:fitapp/domain/tracking/track_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How often buffered fixes are written to the database.
final trackingFlushIntervalProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 5),
);

/// Buffered fixes that trigger an immediate write.
final trackingFlushCountProvider = Provider<int>((ref) => 20);

/// UI state of live GPS tracking (feature 010).
sealed class TrackingUiState {
  const new();
}

/// Nothing is being tracked.
class TrackingIdle extends TrackingUiState {
  const new();
}

/// Waiting for a good GPS fix before the session starts. Nothing is stored.
class TrackingAcquiring extends TrackingUiState {
  const new({
    required this.typeId,
    required this.permission,
    required this.serviceEnabled,
    this.accuracy,
  });

  final String typeId;

  /// Horizontal accuracy of the latest fix in metres, if any yet.
  final double? accuracy;
  final LocationPermissionState permission;
  final bool serviceEnabled;

  /// Whether tracking can start without the "anyway" override.
  bool get hasGoodFix =>
      accuracy != null && accuracy! <= reducer.maxAccuracyMeters;
}

/// A session is recording (possibly manually paused: see [state]).
class TrackingLive extends TrackingUiState {
  const new({
    required this.sessionId,
    required this.typeId,
    required this.state,
  });

  final String sessionId;
  final String typeId;
  final TrackState state;
}

/// The session was saved as activity [activityId].
class TrackingFinished extends TrackingUiState {
  const new(this.activityId);

  final String activityId;
}

class TrackingController extends Notifier<TrackingUiState> {
  StreamSubscription<TrackSample>? _sub;
  Timer? _flushTimer;
  final List<TrackSample> _buffer = [];
  Future<void> _writes = Future.value();

  String? _sessionId;
  String? _typeId;
  TrackProfile? _profile;
  TrackState? _track;

  @override
  TrackingUiState build() {
    ref.onDispose(_stop);
    return const TrackingIdle();
  }

  TrackingRepository get _repo => ref.read(trackingRepositoryProvider);
  LocationSource get _source => ref.read(locationSourceProvider);
  DateTime _now() => ref.read(clockProvider)().toUtc();

  // --- Acquiring --------------------------------------------------------------

  /// Checks (and if needed requests) location permission and, when allowed,
  /// starts listening for fixes to show the accuracy. Nothing is persisted.
  Future<void> prepare(String typeId) async {
    if (state is TrackingLive) return;
    await _cancelListening();
    _typeId = typeId;
    var permission = await _source.checkPermission();
    if (permission == LocationPermissionState.denied) {
      permission = await _source.requestPermission();
    }
    final service = await _source.serviceEnabled();
    if (!ref.mounted) return;
    state = TrackingAcquiring(
      typeId: typeId,
      permission: permission,
      serviceEnabled: service,
    );
    if (permission == LocationPermissionState.granted && service) {
      _listen();
    }
  }

  /// Opens the app's system settings (permission denied forever).
  Future<void> openAppSettings() => _source.openAppSettings();

  /// Opens the system location settings (service switched off).
  Future<void> openLocationSettings() => _source.openLocationSettings();

  // --- Live -------------------------------------------------------------------

  /// Starts recording. Without [anyway] a fix accurate enough to be counted
  /// is required; throws [StateError] otherwise, or when not acquiring.
  Future<void> startSession({bool anyway = false}) async {
    final s = state;
    if (s is! TrackingAcquiring) throw StateError('Not ready to start');
    if (!anyway && !s.hasGoodFix) throw StateError('No accurate GPS fix yet');
    final now = _now();
    final id = await _repo.start(typeId: s.typeId, startedAt: now);
    if (!ref.mounted) return;
    _begin(id, s.typeId, reducer.start(now));
  }

  /// Resumes a session left behind by a killed app: rebuilds the metrics
  /// from the stored points and listens again. No-op without a session.
  Future<void> recover() async {
    if (state is TrackingLive) return;
    final row = await _repo.session();
    if (row == null) return;
    final points = await _repo.loadPoints(row.id);
    if (!ref.mounted) return;
    await _cancelListening();
    _begin(row.id, row.typeId, TrackingRepository.replayState(row, points));
  }

  void _begin(String sessionId, String typeId, TrackState track) {
    _sessionId = sessionId;
    _typeId = typeId;
    _profile = TrackProfile.forType(typeId);
    _track = track;
    state = TrackingLive(sessionId: sessionId, typeId: typeId, state: track);
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(
      ref.read(trackingFlushIntervalProvider),
      (_) => unawaited(_flush()),
    );
    if (_sub == null) _listen();
  }

  Future<void> pause() async {
    final id = _sessionId;
    final track = _track;
    if (id == null || track == null || track.manualPaused) return;
    final now = _now();
    _setTrack(reducer.pause(track, now));
    await _flush();
    await _repo.setPaused(id, paused: true, at: now);
  }

  Future<void> resume() async {
    final id = _sessionId;
    final track = _track;
    if (id == null || track == null || !track.manualPaused) return;
    final now = _now();
    await _flush();
    _setTrack(reducer.resume(track, now));
    await _repo.setPaused(id, paused: false, at: now);
  }

  /// Saves the session as an activity and returns its id.
  Future<String> finish({String? notes}) async {
    final id = _sessionId;
    if (id == null) throw StateError('No tracking session');
    await _cancelListening();
    await _flush();
    final activityId = await _repo.finish(id, endedAt: _now(), notes: notes);
    _clear();
    if (ref.mounted) state = TrackingFinished(activityId);
    return activityId;
  }

  /// Throws the session away (or stops acquiring).
  Future<void> discard() async {
    final id = _sessionId;
    await _cancelListening();
    _buffer.clear();
    if (id != null) {
      await _writes;
      await _repo.discard(id);
    }
    _clear();
    if (ref.mounted) state = const TrackingIdle();
  }

  // --- Internals --------------------------------------------------------------

  void _listen() {
    final type = _typeId;
    if (type == null) return;
    _sub = _source
        .positions(
          notificationTitle: '${activityLabel(type)} in progress',
          notificationText: 'Tracking time and distance',
        )
        .listen(_onFix, onError: _logError);
  }

  void _onFix(TrackSample fix) {
    final track = _track;
    final profile = _profile;
    if (track == null || profile == null) {
      final s = state;
      if (s is TrackingAcquiring) {
        state = TrackingAcquiring(
          typeId: s.typeId,
          permission: s.permission,
          serviceEnabled: s.serviceEnabled,
          accuracy: fix.accuracy,
        );
      }
      return;
    }
    final sample = fix.withPaused(paused: track.manualPaused);
    _setTrack(reducer.accumulate(track, sample, profile));
    _buffer.add(sample);
    if (_buffer.length >= ref.read(trackingFlushCountProvider)) {
      unawaited(_flush());
    }
  }

  void _setTrack(TrackState track) {
    _track = track;
    state = TrackingLive(
      sessionId: _sessionId!,
      typeId: _typeId!,
      state: track,
    );
  }

  /// Writes buffered fixes; writes are serialised so order is kept.
  Future<void> _flush() {
    final id = _sessionId;
    if (id == null || _buffer.isEmpty) return _writes;
    final batch = List<TrackSample>.of(_buffer);
    _buffer.clear();
    return _writes = _writes.then((_) async {
      try {
        await _repo.appendPoints(id, batch);
      } on Object catch (e, st) {
        _logError(e, st);
      }
    });
  }

  void _logError(Object e, StackTrace st) =>
      developer.log('tracking error', error: e, stackTrace: st);

  Future<void> _cancelListening() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    final sub = _sub;
    _sub = null;
    await sub?.cancel();
  }

  void _clear() {
    _sessionId = null;
    _track = null;
    _profile = null;
    _buffer.clear();
  }

  void _stop() {
    _flushTimer?.cancel();
    unawaited(_sub?.cancel());
    _sub = null;
  }
}

final trackingControllerProvider =
    NotifierProvider<TrackingController, TrackingUiState>(
      TrackingController.new,
    );
