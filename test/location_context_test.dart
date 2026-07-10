import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:liuyao/domain/casting.dart';
import 'package:liuyao/domain/location_context.dart';
import 'package:liuyao/services/location_context_service.dart';

void main() {
  final coordinate = DeviceCoordinate(
    latitude: 39.904212,
    longitude: 116.407396,
    accuracyMeters: 26.4,
    capturedAt: _fixedTime,
  );

  test('定位、行政区、天气与近期事件合并为可追溯快照', () async {
    final stages = <LocationFetchStage>[];
    final service = LocationContextService(
      locationGateway: _FakeLocationGateway(coordinate),
      client: MockClient((request) async {
        switch (request.url.host) {
          case 'api.bigdatacloud.net':
            return http.Response(
              '''{
                "countryName":"中国",
                "principalSubdivision":"北京市",
                "city":"北京市",
                "locality":"东城区",
                "localityInfo":{
                  "administrative":[
                    {"name":"北京市","description":"中国首都和直辖市"}
                  ],
                  "informative":[
                    {"name":"东城区","description":"北京中心城区之一"}
                  ]
                }
              }''',
              200,
              headers: {'content-type': 'application/json'},
            );
          case 'api.open-meteo.com':
            return http.Response(
              '''{
                "timezone":"Asia/Shanghai",
                "current":{
                  "temperature_2m":29.4,
                  "apparent_temperature":35.3,
                  "precipitation":0.1,
                  "weather_code":51,
                  "cloud_cover":100,
                  "wind_speed_10m":5.1,
                  "wind_direction_10m":122
                }
              }''',
              200,
              headers: {'content-type': 'application/json'},
            );
          case 'api.gdeltproject.org':
            return http.Response('{}', 429);
          case 'news.google.com':
            return http.Response.bytes(
              utf8.encode('''<?xml version="1.0" encoding="UTF-8"?>
              <rss version="2.0"><channel><item>
                <title>东城区发布近期公共文化活动安排</title>
                <link>https://example.com/local-event</link>
                <source>京报网</source>
                <description>本周将举行多场公共文化活动。</description>
                <pubDate>Fri, 10 Jul 2026 02:30:00 GMT</pubDate>
              </item></channel></rss>'''),
              200,
              headers: {'content-type': 'application/rss+xml; charset=utf-8'},
            );
          case 'www.bing.com':
            return http.Response('<html>not rss</html>', 200);
          default:
            return http.Response('not found', 404);
        }
      }),
    );

    final context = await service.collect(
      requestPermission: true,
      onStage: stages.add,
    );

    expect(stages, LocationFetchStage.values);
    expect(context.latitude, 39.9042);
    expect(context.longitude, 116.4074);
    expect(context.placeLabel, '北京市 · 东城区');
    expect(context.coordinateLabel, contains('北纬'));
    expect(context.weatherSummary, contains('29.4℃'));
    expect(context.regionalFacts, hasLength(2));
    expect(context.recentEvents, hasLength(1));
    expect(context.recentEvents.single.sourceName, '京报网');
    expect(context.recentEvents.single.publishedAt, isNotNull);
    expect(context.dataSources, contains('Open-Meteo 实时天气'));
    expect(context.warnings, isEmpty);
    service.close();
  });

  test('外部数据源全部失败时仍保留定位并标记缺失项', () async {
    final service = LocationContextService(
      locationGateway: _FakeLocationGateway(coordinate),
      client: MockClient((request) async => http.Response('unavailable', 503)),
    );

    final context = await service.collect(requestPermission: false);

    expect(context.coordinateLabel, contains('东经'));
    expect(context.hasOnlineContext, isFalse);
    expect(context.warnings, contains('地点资料未取得'));
    expect(context.warnings, contains('实时天气未取得'));
    expect(context.warnings, contains('近期事件未取得'));
    service.close();
  });

  test('地区新闻检索不可用时从日报筛选所在地事件', () async {
    final service = LocationContextService(
      locationGateway: _FakeLocationGateway(coordinate),
      client: MockClient((request) async {
        if (request.url.host == 'api.bigdatacloud.net') {
          return http.Response.bytes(
            utf8.encode(
              '{"countryName":"中国","principalSubdivision":"上海市",'
              '"city":"上海市","locality":"黄浦区","localityInfo":{}}',
            ),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (request.url.host == 'api.open-meteo.com') {
          return http.Response('{}', 503);
        }
        if (request.url.host == '60s.viki.moe') {
          return http.Response.bytes(
            utf8.encode('''{
              "code":200,
              "data":{
                "date":"2026-07-10",
                "api_updated_at":1783641600000,
                "news":[
                  "上海医保局发布近期便民服务安排",
                  "全国多地迎来高温天气"
                ]
              }
            }'''),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('unavailable', 503);
      }),
    );

    final context = await service.collect(requestPermission: false);

    expect(context.recentEvents, hasLength(1));
    expect(context.recentEvents.single.title, contains('上海医保局'));
    expect(context.recentEvents.single.sourceName, contains('本地匹配'));
    service.close();
  });

  test('位置快照 JSON 往返保留事件、来源与采集时间', () {
    final original = LocationContext(
      latitude: 31.2304,
      longitude: 121.4737,
      accuracyMeters: 18,
      capturedAt: _fixedTime,
      country: '中国',
      region: '上海市',
      city: '上海市',
      district: '黄浦区',
      timezone: 'Asia/Shanghai',
      weatherSummary: '晴，30℃',
      regionalFacts: const ['黄浦区：上海中心城区'],
      recentEvents: [
        LocationEvent(
          title: '公共活动安排发布',
          sourceName: '本地新闻',
          url: 'https://example.com/event',
          publishedAt: _fixedTime,
        ),
      ],
      dataSources: const ['Open-Meteo 实时天气'],
    );

    final restored = LocationContext.fromJson(original.toJson());

    expect(restored.placeLabel, '上海市 · 黄浦区');
    expect(restored.capturedAt, _fixedTime);
    expect(restored.recentEvents.single.title, '公共活动安排发布');
    expect(restored.recentEvents.single.publishedAt, _fixedTime);
    expect(restored.dataSources, original.dataSources);
  });

  test('位置上下文不会改变相同六爻掷值的排盘结果', () {
    final caster = Caster();
    final tosses = caster.fromValues([9, 7, 8, 6, 7, 8]);
    final plain = caster.castFromTosses(
      tosses: tosses,
      question: '测试',
      method: '手动排爻',
      at: _fixedTime,
    );
    final located = caster.castFromTosses(
      tosses: tosses,
      question: '测试',
      method: '手动排爻',
      at: _fixedTime,
      locationContext: LocationContext(
        latitude: 39.9042,
        longitude: 116.4074,
        accuracyMeters: 20,
        capturedAt: _fixedTime,
      ),
    );

    expect(located.tossValues, plain.tossValues);
    expect(located.primary.name, plain.primary.name);
    expect(
      located.primary.yaos.map((yao) => yao.ganZhi),
      plain.primary.yaos.map((yao) => yao.ganZhi),
    );
    expect(located.movingPositions, plain.movingPositions);
    expect(located.changed?.name, plain.changed?.name);
  });
}

final _fixedTime = DateTime.utc(2026, 7, 10, 3, 0);

class _FakeLocationGateway implements DeviceLocationGateway {
  const _FakeLocationGateway(this.coordinate);

  final DeviceCoordinate coordinate;

  @override
  Future<DeviceCoordinate> locate({required bool requestPermission}) async =>
      coordinate;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}
