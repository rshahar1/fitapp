import 'dart:async';
import 'dart:developer' as developer;

import 'package:fitapp/core/step_source.dart';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

const _timeout = Duration(seconds: 5);
const _types = [HealthDataType.STEPS];
const _perms = [HealthDataAccess.READ];

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
      return await _health.requestAuthorization(_types, permissions: _perms);
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
}
