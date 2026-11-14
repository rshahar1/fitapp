import 'dart:async';
import 'dart:developer' as developer;

import 'package:fitapp/data/providers.dart';
import 'package:fitapp/data/repositories/tracking_repository.dart';
import 'package:fitapp/data/tracking/location_source.dart';
import 'package:fitapp/domain/activity_types.dart';
import 'package:fitapp/domain/tracking/geo.dart';
import 'package:fitapp/domain/tracking/track_profile.dart';
import 'package:fitapp/domain/tracking/track_reducer.dart' as reducer;
import 'package:fitapp/domain/tracking/track_sample.dart';
import 'package:fitapp/domain/tracking/track_state.dart';
import 'package:fitapp/domain/tracking/track_summary.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How often buffered fixes are written to the database.
final trackingFlushIntervalProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 5),
);

/// Buffered fixes that trigger an immediate write.
final trackingFlushCountProvider = Provider<int>((ref) => 20);

/// Delay before the position stream is re-opened after an error.
final trackingRetryDelayProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 2),
);

/// How long without any fix before the position stream is reopened with the
/// other Android location provider.
final trackingNoFixTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 15),
);

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
    required this.since,
    this.accuracy,
    this.position,
    this.error,
  });

  final String typeId;

  /// Last location error (shown so failures are visible), cleared by a fix.
  final String? error;

  /// When acquiring started (for the "still no good signal" hint).
  final DateTime since;

  /// Latest fix, or the last known position before the first fix. Only for
  /// centring the map: it says nothing about [accuracy].
  final GeoPoint? position;

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
    this.points = const [],
    this.position,
    this.serviceEnabled = true,
  });

  final String sessionId;
  final String typeId;
  final TrackState state;

  /// The accepted fixes drawn as the route so far. A fresh list per change.
  final List<GeoPoint> points;

  /// The latest position received (accepted or not), for the map dot.
  final GeoPoint? position;

  /// False while the device's location service is switched off.
  final bool serviceEnabled;
}

/// The session was saved as activity [activityId].
class TrackingFinished extends TrackingUiState {
  const new(this.activityId);

  final String activityId;
}

class TrackingController extends Notifier<TrackingUiState> {
  StreamSubscription<TrackSample>? _sub;
  StreamSubscription<bool>? _serviceSub;
  Timer? _retryTimer;
  Timer? _watchdog;
  bool _subBackground = false;
  bool _rawGps = false;
  bool _serviceOn = true;
  GeoPoint? _fix;
  Timer? _flushTimer;
  final List<TrackSample> _buffer = [];
  Future<void> _writes = Future.value();

  String? _sessionId;
  String? _typeId;
  TrackProfile? _profile;
  TrackState? _track;

  /// Fixes the reducer accepted, and the same as an immutable route snapshot.
  final List<TrackSample> _accepted = [];
  List<GeoPoint> _route = const [];

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
    final previous = state;
    await _cancelListening();
    _typeId = typeId;
    var permission = await _source.checkPermission();
    if (permission == LocationPermissionState.denied) {
      permission = await _source.requestPermission();
    }
    final service = await _source.serviceEnabled();
    final known = previous is TrackingAcquiring && previous.position != null
        ? null
        : await _source.lastKnownPosition();
    if (!ref.mounted) return;
    _serviceOn = service;
    state = TrackingAcquiring(
      typeId: typeId,
      permission: permission,
      serviceEnabled: service,
      since: previous is TrackingAcquiring ? previous.since : _now(),
      position: previous is TrackingAcquiring && previous.position != null
          ? previous.position
          : known == null
          ? null
          : (lat: known.lat, lon: known.lon),
    );
    _watchService();
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
    _fix = s.position;
    _begin(id, s.typeId, reducer.start(now), const []);
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
    final profile = TrackProfile.forType(row.typeId);
    _begin(
      row.id,
      row.typeId,
      TrackingRepository.replayState(row, points),
      reducer.acceptedSamples(
        row.startedAt.toUtc(),
        points,
        profile,
        pauses: TrackingRepository.pausesOf(row, points),
      ),
    );
  }

  void _begin(
    String sessionId,
    String typeId,
    TrackState track,
    List<TrackSample> accepted,
  ) {
    _sessionId = sessionId;
    _typeId = typeId;
    _profile = TrackProfile.forType(typeId);
    _track = track;
    _accepted
      ..clear()
      ..addAll(accepted);
    _route = _routeOf(_accepted);
    _publish();
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(
      ref.read(trackingFlushIntervalProvider),
      (_) => unawaited(_flush()),
    );
    _watchService();
    final waiting = _sub;
    if (waiting != null && !_subBackground) {
      // Reopen in background mode so recording survives the screen off.
      _sub = null;
      unawaited(waiting.cancel());
    }
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

  /// What [finish] would store right now (for the finish sheet), or null
  /// without a session.
  TrackSummary? previewSummary() {
    final track = _track;
    if (track == null) return null;
    return summarize(track, _accepted, endedAt: _now());
  }

  /// Saves the session as an activity and returns its id.
  Future<String> finish({String? notes}) async {
    final id = _sessionId;
    if (id == null) throw StateError('No tracking session');
    await _cancelListening();
    final String activityId;
    try {
      await _flush();
      activityId = await _repo.finish(id, endedAt: _now(), notes: notes);
    } catch (_) {
      // Saving failed: keep recording so nothing is lost; the UI shows the
      // error and the user can retry.
      if (ref.mounted) {
        _watchService();
        _listen();
      }
      rethrow;
    }
    _clear();
    if (ref.mounted) state = TrackingFinished(activityId);
    return activityId;
  }

  /// Stops listening when the setup screen closes without starting.
  Future<void> cancelAcquiring() async {
    if (!ref.mounted || state is! TrackingAcquiring) return;
    await discard();
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
    if (type == null || _sub != null) return;
    // The background (foreground-service) mode is only needed once a
    // session records; while waiting for a fix the screen is visible.
    _subBackground = _sessionId != null;
    _armWatchdog();
    _sub = _source
        .positions(
          notificationTitle: '${activityLabel(type)} in progress',
          notificationText: 'Tracking time and distance',
          background: _subBackground,
          rawGps: _rawGps,
        )
        .listen(
          _onFix,
          onError: (Object e, StackTrace st) {
            _logError(e, st);
            final s = state;
            if (s is TrackingAcquiring) {
              state = _acquiring(s, error: e.toString());
            }
            _scheduleRetry();
          },
          onDone: _scheduleRetry,
        );
  }

  void _watchService() {
    _serviceSub ??= _source.serviceStatus().listen(
      _onServiceStatus,
      onError: _logError,
    );
  }

  /// The location service was switched on or off.
  void _onServiceStatus(bool enabled) {
    _serviceOn = enabled;
    final s = state;
    if (s is TrackingAcquiring) {
      state = _acquiring(s, serviceEnabled: enabled);
      if (enabled &&
          _sub == null &&
          s.permission == LocationPermissionState.granted) {
        _listen();
      } else if (!enabled) {
        unawaited(_dropStream());
      }
    } else if (s is TrackingLive && _track != null) {
      _publish();
      if (enabled && _sub == null) _listen();
    }
  }

  Future<void> _dropStream() async {
    _watchdog?.cancel();
    _watchdog = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    final sub = _sub;
    _sub = null;
    await sub?.cancel();
  }

  /// The position stream failed or ended while it should run: open it again
  /// after a short pause, unless permission or the service is missing.
  void _scheduleRetry() {
    if (!ref.mounted) return;
    _watchdog?.cancel();
    _watchdog = null;
    final dead = _sub;
    _sub = null;
    if (dead != null) unawaited(dead.cancel());
    final s = state;
    if (s is! TrackingAcquiring && s is! TrackingLive) return;
    _retryTimer?.cancel();
    _retryTimer = Timer(
      ref.read(trackingRetryDelayProvider),
      () => unawaited(_retry()),
    );
  }

  Future<void> _retry() async {
    _retryTimer = null;
    if (!ref.mounted || _sub != null) return;
    final permission = await _source.checkPermission();
    final service = await _source.serviceEnabled();
    if (!ref.mounted || _sub != null) return;
    _serviceOn = service;
    final s = state;
    if (s is TrackingAcquiring) {
      state = _acquiring(s, permission: permission, serviceEnabled: service);
    } else if (s is TrackingLive) {
      _publish();
    } else {
      return;
    }
    // Without permission there is nothing to retry; with the service off the
    // service stream restarts listening when it comes back.
    if (permission == LocationPermissionState.granted && service) _listen();
  }

  TrackingAcquiring _acquiring(
    TrackingAcquiring s, {
    LocationPermissionState? permission,
    bool? serviceEnabled,
    double? accuracy,
    GeoPoint? position,
    String? error,
    bool clearError = false,
  }) => TrackingAcquiring(
    typeId: s.typeId,
    permission: permission ?? s.permission,
    serviceEnabled: serviceEnabled ?? s.serviceEnabled,
    since: s.since,
    accuracy: accuracy ?? s.accuracy,
    position: position ?? s.position,
    error: clearError ? null : error ?? s.error,
  );

  void _onFix(TrackSample fix) {
    _armWatchdog();
    final track = _track;
    final profile = _profile;
    if (track == null || profile == null) {
      final s = state;
      if (s is TrackingAcquiring) {
        state = _acquiring(
          s,
          accuracy: fix.accuracy,
          position: (lat: fix.lat, lon: fix.lon),
          clearError: true,
        );
      }
      return;
    }
    _fix = (lat: fix.lat, lon: fix.lon);
    final sample = fix.withPaused(paused: track.manualPaused);
    final next = reducer.accumulate(track, sample, profile);
    if (identical(next.lastAccepted, sample)) {
      _accepted.add(sample);
      _route = _routeOf(_accepted);
    }
    _setTrack(next);
    _buffer.add(sample);
    if (_buffer.length >= ref.read(trackingFlushCountProvider)) {
      unawaited(_flush());
    }
  }

  void _setTrack(TrackState track) {
    _track = track;
    _publish();
  }

  void _publish() => state = TrackingLive(
    sessionId: _sessionId!,
    typeId: _typeId!,
    state: _track!,
    points: _route,
    position: _fix ?? _lastAcceptedPoint(),
    serviceEnabled: _serviceOn,
  );

  GeoPoint? _lastAcceptedPoint() {
    final a = _track?.lastAccepted;
    return a == null ? null : (lat: a.lat, lon: a.lon);
  }

  static List<GeoPoint> _routeOf(List<TrackSample> samples) =>
      List.unmodifiable([for (final s in samples) (lat: s.lat, lon: s.lon)]);

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

  /// Restarts the watchdog: when no fix arrives in time the stream is
  /// reopened with the other Android provider (fused ↔ raw GPS).
  void _armWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer(ref.read(trackingNoFixTimeoutProvider), _onNoFix);
  }

  void _onNoFix() {
    _watchdog = null;
    if (!ref.mounted || _sub == null) return;
    _rawGps = !_rawGps;
    final s = state;
    if (s is TrackingAcquiring) {
      state = _acquiring(
        s,
        error: 'No location updates yet. Trying another GPS provider…',
      );
    }
    final old = _sub;
    _sub = null;
    unawaited(old?.cancel());
    _listen();
  }

  void _logError(Object e, StackTrace st) =>
      developer.log('tracking error', error: e, stackTrace: st);

  Future<void> _cancelListening() async {
    _watchdog?.cancel();
    _watchdog = null;
    _flushTimer?.cancel();
    _flushTimer = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    final service = _serviceSub;
    _serviceSub = null;
    final sub = _sub;
    _sub = null;
    await service?.cancel();
    await sub?.cancel();
  }

  void _clear() {
    _sessionId = null;
    _track = null;
    _profile = null;
    _accepted.clear();
    _route = const [];
    _buffer.clear();
    _fix = null;
    _serviceOn = true;
  }

  void _stop() {
    _watchdog?.cancel();
    _watchdog = null;
    _flushTimer?.cancel();
    _retryTimer?.cancel();
    unawaited(_sub?.cancel());
    unawaited(_serviceSub?.cancel());
    _sub = null;
    _serviceSub = null;
  }
}

final trackingControllerProvider =
    NotifierProvider<TrackingController, TrackingUiState>(
      TrackingController.new,
    );
