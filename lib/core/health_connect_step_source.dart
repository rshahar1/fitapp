import 'dart:async';
import 'dart:developer' as developer;

import 'package:fitapp/core/step_source.dart';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

const _timeout = Duration(seconds: 5);
const _types = [HealthDataType.STEPS];
const _perms = [HealthDataAccess.READ];
const _distanceTypes = [HealthDataType.DISTANCE_DELTA];
const _distancePerms = [HealthDataAccess.READ];

/// Production [StepSource] backed by Health Connect (Android only).
class HealthConnectStepSource implements StepSource {
  new({Health? health, bool? isAndroid})
    : _health = health ?? Health(),
      _isAndroid =
          isAndroid ??
          (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  final Health _health;
  final bool _isAndroid;
  Future<void>? _configured;

  /// Configures once; a failed attempt is retried on the next call.
  Future<void> _configure() =>
      _configured ??= _health.configure().catchError((Object e, StackTrace s) {
        _configured = null;
        Error.throwWithStackTrace(e, s);
      });

  void _log(String what, Object error, StackTrace stack) => developer.log(
    'StepSource.$what failed',
    name: 'fitapp.steps',
    error: error,
    stackTrace: stack,
  );

  @override
  Future<StepAccess> access() async {
    if (!_isAndroid) return StepAccess.unavailable;
    try {
      await _configure().timeout(_timeout);
      final status = await _health.getHealthConnectSdkStatus().timeout(
        _timeout,
      );
      switch (status) {
        case HealthConnectSdkStatus.sdkAvailable:
          break;
        case HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired:
          return StepAccess.needsInstall;
        case HealthConnectSdkStatus.sdkUnavailable:
        case null:
          return StepAccess.unavailable;
      }
      final granted = await _health
          .hasPermissions(_types, permissions: _perms)
          .timeout(_timeout);
      return granted == true ? StepAccess.granted : StepAccess.notGranted;
    } on Object catch (e, s) {
      _log('access', e, s);
      return StepAccess.unavailable;
    }
  }

  @override
  Future<bool> requestAccess() async {
    if (!_isAndroid) return false;
    try {
      await _configure().timeout(_timeout);
      // The permission dialog waits on the user: no timeout here.
      // Steps and distance together; steps access is judged on steps alone, so
      // a refused distance permission never hides the step count.
      await _health.requestAuthorization(
        [..._types, ..._distanceTypes],
        permissions: [..._perms, ..._distancePerms],
      );
      return await _health.hasPermissions(_types, permissions: _perms) == true;
    } on Object catch (e, s) {
      _log('requestAccess', e, s);
      return false;
    }
  }

  @override
  Future<void> installHealthConnect() async {
    if (!_isAndroid) return;
    try {
      await _configure().timeout(_timeout);
      await _health.installHealthConnect().timeout(_timeout);
    } on Object catch (e, s) {
      _log('installHealthConnect', e, s);
    }
  }

  @override
  Future<int?> stepsBetween(DateTime start, DateTime end) async {
    if (!_isAndroid) return null;
    try {
      await _configure().timeout(_timeout);
      return await _health
          .getTotalStepsInInterval(start, end)
          .timeout(_timeout);
    } on Object catch (e, s) {
      _log('stepsBetween', e, s);
      return null;
    }
  }

  @override
  Future<bool> distanceAccess() async {
    if (!_isAndroid) return false;
    try {
      await _configure().timeout(_timeout);
      final granted = await _health
          .hasPermissions(_distanceTypes, permissions: _distancePerms)
          .timeout(_timeout);
      return granted == true;
    } on Object catch (e, s) {
      _log('distanceAccess', e, s);
      return false;
    }
  }

  @override
  Future<bool> requestDistanceAccess() async {
    if (!_isAndroid) return false;
    try {
      await _configure().timeout(_timeout);
      // The permission dialog waits on the user: no timeout here.
      return await _health.requestAuthorization(
        _distanceTypes,
        permissions: _distancePerms,
      );
    } on Object catch (e, s) {
      _log('requestDistanceAccess', e, s);
      return false;
    }
  }

  @override
  Future<double?> distanceBetween(DateTime start, DateTime end) async {
    if (!_isAndroid) return null;
    try {
      await _configure().timeout(_timeout);
      final seconds = end.difference(start).inSeconds;
      if (seconds <= 0) return 0;
      // One bucket over the whole window: Health Connect's aggregate
      // de-duplicates overlapping sources (phone and watch).
      final points = await _health
          .getHealthIntervalDataFromTypes(
            startDate: start,
            endDate: end,
            types: _distanceTypes,
            interval: seconds,
          )
          .timeout(_timeout);
      var meters = 0.0;
      for (final p in points) {
        final v = p.value;
        if (v is NumericHealthValue) meters += v.numericValue.toDouble();
      }
      return meters;
    } on Object catch (e, s) {
      _log('distanceBetween', e, s);
      return null;
    }
  }
}
