import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/location_context.dart';
import '../services/location_context_service.dart';

enum LocationPhase {
  disabled,
  idle,
  requesting,
  locating,
  enriching,
  ready,
  partial,
  error,
}

class LocationState {
  const LocationState({
    this.enabled = false,
    this.loaded = false,
    this.phase = LocationPhase.disabled,
    this.context,
    this.error,
    this.failureKind,
  });

  final bool enabled;
  final bool loaded;
  final LocationPhase phase;
  final LocationContext? context;
  final String? error;
  final LocationFailureKind? failureKind;

  bool get busy =>
      phase == LocationPhase.requesting ||
      phase == LocationPhase.locating ||
      phase == LocationPhase.enriching;

  bool get needsAppSettings =>
      failureKind == LocationFailureKind.permissionDeniedForever;

  bool get needsLocationSettings =>
      failureKind == LocationFailureKind.serviceDisabled;

  LocationState copyWith({
    bool? enabled,
    bool? loaded,
    LocationPhase? phase,
    LocationContext? context,
    bool clearContext = false,
    String? error,
    bool clearError = false,
    LocationFailureKind? failureKind,
    bool clearFailure = false,
  }) {
    return LocationState(
      enabled: enabled ?? this.enabled,
      loaded: loaded ?? this.loaded,
      phase: phase ?? this.phase,
      context: clearContext ? null : (context ?? this.context),
      error: clearError ? null : (error ?? this.error),
      failureKind: clearFailure ? null : (failureKind ?? this.failureKind),
    );
  }
}

class LocationController extends StateNotifier<LocationState> {
  LocationController({
    LocationContextService? service,
    LocationState initialState = const LocationState(),
    bool restorePreference = true,
  }) : _service = service ?? LocationContextService(),
       super(initialState) {
    if (restorePreference) unawaited(_restorePreference());
  }

  static const _enabledKey = 'location_context_enabled_v1';
  static const _freshFor = Duration(minutes: 10);

  final LocationContextService _service;
  Future<LocationContext?>? _activeRequest;
  int _requestGeneration = 0;

  Future<void> _restorePreference() async {
    var enabled = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      enabled = prefs.getBool(_enabledKey) ?? false;
    } catch (_) {
      // 偏好读取失败不影响起卦。
    }
    state = state.copyWith(
      enabled: enabled,
      loaded: true,
      phase: enabled ? LocationPhase.idle : LocationPhase.disabled,
    );
    if (enabled) {
      unawaited(refresh(requestPermission: false));
    }
  }

  Future<LocationContext?> enableAndRefresh() async {
    state = state.copyWith(
      enabled: true,
      loaded: true,
      phase: LocationPhase.requesting,
      clearError: true,
      clearFailure: true,
    );
    await _persistEnabled(true);
    return refresh(requestPermission: true);
  }

  Future<void> disable() async {
    _requestGeneration++;
    _activeRequest = null;
    state = state.copyWith(
      enabled: false,
      loaded: true,
      phase: LocationPhase.disabled,
      clearContext: true,
      clearError: true,
      clearFailure: true,
    );
    await _persistEnabled(false);
  }

  Future<LocationContext?> refresh({bool requestPermission = false}) {
    final active = _activeRequest;
    if (active != null) return active;
    final generation = _requestGeneration;
    final request = _collect(
      requestPermission: requestPermission,
      generation: generation,
    );
    _activeRequest = request;
    request.whenComplete(() {
      if (identical(_activeRequest, request)) _activeRequest = null;
    });
    return request;
  }

  Future<LocationContext?> prepareForReading() async {
    if (!state.enabled) return null;
    final context = state.context;
    if (context != null &&
        DateTime.now().difference(context.capturedAt).abs() <= _freshFor) {
      return context;
    }
    return refresh(requestPermission: false);
  }

  Future<LocationContext?> _collect({
    required bool requestPermission,
    required int generation,
  }) async {
    final previous = state.context;
    try {
      final context = await _service.collect(
        requestPermission: requestPermission,
        onStage: (stage) {
          if (generation != _requestGeneration || !state.enabled) return;
          final phase = switch (stage) {
            LocationFetchStage.permission => LocationPhase.requesting,
            LocationFetchStage.locating => LocationPhase.locating,
            LocationFetchStage.enriching => LocationPhase.enriching,
          };
          state = state.copyWith(
            enabled: true,
            phase: phase,
            clearError: true,
            clearFailure: true,
          );
        },
      );
      if (generation != _requestGeneration || !state.enabled) return null;
      state = state.copyWith(
        enabled: true,
        phase: context.warnings.isEmpty
            ? LocationPhase.ready
            : LocationPhase.partial,
        context: context,
        clearError: true,
        clearFailure: true,
      );
      return context;
    } on LocationContextException catch (error) {
      if (generation != _requestGeneration || !state.enabled) return null;
      state = state.copyWith(
        enabled: true,
        phase: LocationPhase.error,
        error: error.message,
        failureKind: error.kind,
      );
      return previous;
    } catch (error) {
      if (generation != _requestGeneration || !state.enabled) return null;
      state = state.copyWith(
        enabled: true,
        phase: LocationPhase.error,
        error: '位置资料获取失败：${_safeError(error)}',
        failureKind: LocationFailureKind.unavailable,
      );
      return previous;
    }
  }

  Future<void> _persistEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, enabled);
    } catch (_) {
      // 偏好保存失败不阻断本次授权和定位。
    }
  }

  Future<bool> openAppSettings() => _service.openAppSettings();

  Future<bool> openLocationSettings() => _service.openLocationSettings();

  @override
  void dispose() {
    _service.close();
    super.dispose();
  }
}

final locationProvider =
    StateNotifierProvider<LocationController, LocationState>(
      (ref) => LocationController(),
    );

String _safeError(Object error) {
  final value = error.toString();
  return value.length <= 120 ? value : '${value.substring(0, 120)}…';
}
