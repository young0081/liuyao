import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:liuyao/domain/location_context.dart';
import 'package:liuyao/services/location_context_service.dart';
import 'package:liuyao/state/location_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('定位进行中关闭功能后不会被迟到结果重新开启', () async {
    SharedPreferences.setMockInitialValues({});
    final service = _DelayedLocationService();
    final controller = LocationController(
      service: service,
      initialState: const LocationState(loaded: true),
      restorePreference: false,
    );

    final enabling = controller.enableAndRefresh();
    await service.started.future;
    await controller.disable();
    service.result.complete(_context);
    await enabling;

    expect(controller.state.enabled, isFalse);
    expect(controller.state.phase, LocationPhase.disabled);
    expect(controller.state.context, isNull);
    controller.dispose();
  });
}

final _context = LocationContext(
  latitude: 39.9042,
  longitude: 116.4074,
  accuracyMeters: 20,
  capturedAt: DateTime.utc(2026, 7, 10, 3),
  region: '北京市',
  district: '东城区',
);

class _DelayedLocationService extends LocationContextService {
  _DelayedLocationService()
    : super(
        locationGateway: const _UnusedLocationGateway(),
        client: MockClient((request) async => throw StateError('unused')),
      );

  final started = Completer<void>();
  final result = Completer<LocationContext>();

  @override
  Future<LocationContext> collect({
    required bool requestPermission,
    void Function(LocationFetchStage stage)? onStage,
  }) async {
    onStage?.call(LocationFetchStage.locating);
    if (!started.isCompleted) started.complete();
    return result.future;
  }
}

class _UnusedLocationGateway implements DeviceLocationGateway {
  const _UnusedLocationGateway();

  @override
  Future<DeviceCoordinate> locate({required bool requestPermission}) =>
      throw StateError('unused');

  @override
  Future<bool> openAppSettings() async => false;

  @override
  Future<bool> openLocationSettings() async => false;
}
