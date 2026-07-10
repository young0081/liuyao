import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../domain/location_context.dart';

enum LocationFetchStage { permission, locating, enriching }

enum LocationFailureKind {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  unavailable,
}

class LocationContextException implements Exception {
  const LocationContextException(this.kind, this.message);

  final LocationFailureKind kind;
  final String message;

  @override
  String toString() => message;
}

class DeviceCoordinate {
  const DeviceCoordinate({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.capturedAt,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime capturedAt;
}

abstract class DeviceLocationGateway {
  Future<DeviceCoordinate> locate({required bool requestPermission});

  Future<bool> openAppSettings();

  Future<bool> openLocationSettings();
}

class GeolocatorDeviceLocationGateway implements DeviceLocationGateway {
  @override
  Future<DeviceCoordinate> locate({required bool requestPermission}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationContextException(
        LocationFailureKind.serviceDisabled,
        '系统定位服务尚未开启。',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && requestPermission) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationContextException(
        LocationFailureKind.permissionDenied,
        '未获得位置权限，可重试授权或关闭位置参照。',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationContextException(
        LocationFailureKind.permissionDeniedForever,
        '位置权限已被永久拒绝，请前往系统设置开启。',
      );
    }
    if (permission == LocationPermission.unableToDetermine) {
      throw const LocationContextException(
        LocationFailureKind.unavailable,
        '系统无法确定位置权限状态。',
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 18),
        ),
      );
      return DeviceCoordinate(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
        capturedAt: position.timestamp,
      );
    } on TimeoutException {
      throw const LocationContextException(
        LocationFailureKind.unavailable,
        '定位超时，请移动到开阔处后重试。',
      );
    } catch (error) {
      throw LocationContextException(
        LocationFailureKind.unavailable,
        '无法取得当前位置：${_safeError(error)}',
      );
    }
  }

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}

class LocationContextService {
  LocationContextService({
    DeviceLocationGateway? locationGateway,
    http.Client? client,
    this.requestTimeout = const Duration(seconds: 9),
  }) : locationGateway = locationGateway ?? GeolocatorDeviceLocationGateway(),
       _client = client ?? http.Client(),
       _ownsClient = client == null;

  final DeviceLocationGateway locationGateway;
  final Duration requestTimeout;
  final http.Client _client;
  final bool _ownsClient;

  static const _headers = {
    'Accept': 'application/json, application/xml, text/xml;q=0.9',
    'User-Agent':
        'XuanjiLiuyao/1.1.0 '
        '(https://github.com/young0081/liuyao)',
  };

  Future<LocationContext> collect({
    required bool requestPermission,
    void Function(LocationFetchStage stage)? onStage,
  }) async {
    onStage?.call(LocationFetchStage.permission);
    onStage?.call(LocationFetchStage.locating);
    final coordinate = await locationGateway.locate(
      requestPermission: requestPermission,
    );
    onStage?.call(LocationFetchStage.enriching);
    return enrich(coordinate);
  }

  Future<LocationContext> enrich(DeviceCoordinate coordinate) async {
    final placeFuture = _tryPlace(coordinate);
    final weatherFuture = _tryWeather(coordinate);
    final place = await placeFuture;
    final weather = await weatherFuture;
    final events = place.searchTerm.isEmpty
        ? const <LocationEvent>[]
        : await _fetchRecentEvents(place.searchTerm);

    final warnings = <String>[];
    if (!place.available) warnings.add('地点资料未取得');
    if (weather.summary.isEmpty) warnings.add('实时天气未取得');
    if (events.isEmpty) warnings.add('近期事件未取得');

    final sources = <String>[];
    if (place.available) sources.add('BigDataCloud 反向地理编码');
    if (weather.summary.isNotEmpty) sources.add('Open-Meteo 实时天气');
    if (events.isNotEmpty) {
      final eventSources = events
          .map((event) => event.sourceName)
          .where((name) => name.isNotEmpty)
          .toSet();
      sources.addAll(eventSources);
    }

    return LocationContext(
      latitude: _roundedCoordinate(coordinate.latitude),
      longitude: _roundedCoordinate(coordinate.longitude),
      accuracyMeters: coordinate.accuracyMeters,
      capturedAt: coordinate.capturedAt,
      country: place.country,
      region: place.region,
      city: place.city,
      district: place.district,
      timezone: weather.timezone,
      weatherSummary: weather.summary,
      regionalFacts: place.facts,
      recentEvents: events,
      dataSources: sources,
      warnings: warnings,
    );
  }

  Future<_PlaceInfo> _tryPlace(DeviceCoordinate coordinate) async {
    try {
      return await _fetchPlace(coordinate);
    } catch (_) {
      return const _PlaceInfo();
    }
  }

  Future<_WeatherInfo> _tryWeather(DeviceCoordinate coordinate) async {
    try {
      return await _fetchWeather(coordinate);
    } catch (_) {
      return const _WeatherInfo();
    }
  }

  Future<_PlaceInfo> _fetchPlace(DeviceCoordinate coordinate) async {
    final uri =
        Uri.https('api.bigdatacloud.net', '/data/reverse-geocode-client', {
          'latitude': coordinate.latitude.toString(),
          'longitude': coordinate.longitude.toString(),
          'localityLanguage': 'zh',
        });
    final json = await _getJson(uri);
    final facts = <String>[];
    final localityInfo = json['localityInfo'];
    if (localityInfo is Map) {
      final groups = [
        localityInfo['administrative'],
        localityInfo['informative'],
      ];
      for (final group in groups) {
        if (group is! List) continue;
        for (final item in group) {
          if (item is! Map) continue;
          final name = item['name']?.toString().trim() ?? '';
          final description = item['description']?.toString().trim() ?? '';
          if (name.isEmpty || description.isEmpty) continue;
          final fact = '$name：$description';
          if (!facts.contains(fact)) facts.add(fact);
          if (facts.length == 4) break;
        }
        if (facts.length == 4) break;
      }
    }
    return _PlaceInfo(
      country: json['countryName']?.toString() ?? '',
      region: json['principalSubdivision']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      district: json['locality']?.toString() ?? '',
      facts: facts,
      available: true,
    );
  }

  Future<_WeatherInfo> _fetchWeather(DeviceCoordinate coordinate) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': coordinate.latitude.toString(),
      'longitude': coordinate.longitude.toString(),
      'current': [
        'temperature_2m',
        'apparent_temperature',
        'precipitation',
        'weather_code',
        'cloud_cover',
        'wind_speed_10m',
        'wind_direction_10m',
      ].join(','),
      'timezone': 'auto',
    });
    final json = await _getJson(uri);
    final current = json['current'];
    if (current is! Map) return const _WeatherInfo();

    final temperature = (current['temperature_2m'] as num?)?.toDouble();
    final apparent = (current['apparent_temperature'] as num?)?.toDouble();
    final precipitation = (current['precipitation'] as num?)?.toDouble();
    final cloud = (current['cloud_cover'] as num?)?.toDouble();
    final windSpeed = (current['wind_speed_10m'] as num?)?.toDouble();
    final windDirection = (current['wind_direction_10m'] as num?)?.toDouble();
    final weatherCode = (current['weather_code'] as num?)?.toInt();
    if (temperature == null) return const _WeatherInfo();

    final parts = <String>[
      _weatherName(weatherCode),
      '${temperature.toStringAsFixed(1)}℃',
    ];
    if (apparent != null) parts.add('体感 ${apparent.toStringAsFixed(1)}℃');
    if (precipitation != null && precipitation > 0) {
      parts.add('降水 ${precipitation.toStringAsFixed(1)}mm');
    }
    if (cloud != null) parts.add('云量 ${cloud.toStringAsFixed(0)}%');
    if (windSpeed != null && windDirection != null) {
      parts.add(
        '${_compassDirection(windDirection)}风 '
        '${windSpeed.toStringAsFixed(1)}km/h',
      );
    }
    return _WeatherInfo(
      summary: parts.join('，'),
      timezone: json['timezone']?.toString() ?? '',
    );
  }

  Future<List<LocationEvent>> _fetchRecentEvents(String searchTerm) async {
    final results = await Future.wait([
      _ignoreEventFailure(_fetchGdeltEvents(searchTerm)),
      _ignoreEventFailure(_fetchGoogleNewsEvents(searchTerm)),
      _ignoreEventFailure(_fetchBingNewsEvents(searchTerm)),
      _ignoreEventFailure(_fetchDailyNewsEvents(searchTerm)),
    ]);
    final merged = <LocationEvent>[];
    final seen = <String>{};
    for (final group in results.take(3)) {
      for (final event in group) {
        final key = event.title.trim().toLowerCase();
        if (key.isEmpty || !seen.add(key)) continue;
        merged.add(event);
      }
    }
    if (merged.isEmpty) {
      for (final event in results.last) {
        final key = event.title.trim().toLowerCase();
        if (key.isEmpty || !seen.add(key)) continue;
        merged.add(event);
      }
    }
    merged.sort((a, b) {
      final left = a.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final right = b.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return right.compareTo(left);
    });
    return merged.take(6).toList();
  }

  Future<List<LocationEvent>> _ignoreEventFailure(
    Future<List<LocationEvent>> request,
  ) async {
    try {
      return await request;
    } catch (_) {
      return const [];
    }
  }

  Future<List<LocationEvent>> _fetchGdeltEvents(String searchTerm) async {
    final uri = Uri.https('api.gdeltproject.org', '/api/v2/doc/doc', {
      'query': '"$searchTerm"',
      'mode': 'artlist',
      'maxrecords': '8',
      'format': 'json',
      'sort': 'datedesc',
      'timespan': '14d',
    });
    final json = await _getJson(uri);
    final articles = json['articles'];
    if (articles is! List) return const [];
    return [
      for (final article in articles)
        if (article is Map &&
            (article['title']?.toString().trim().isNotEmpty ?? false))
          LocationEvent(
            title: _limited(article['title'].toString().trim(), 180),
            sourceName: article['domain']?.toString() ?? 'GDELT',
            url: _limited(article['url']?.toString() ?? '', 500),
            publishedAt: _parsePublishedAt(
              article['seendate']?.toString() ?? '',
            ),
          ),
    ];
  }

  Future<List<LocationEvent>> _fetchGoogleNewsEvents(String searchTerm) {
    final uri = Uri.https('news.google.com', '/rss/search', {
      'q': '"$searchTerm" when:14d',
      'hl': 'zh-CN',
      'gl': 'CN',
      'ceid': 'CN:zh-Hans',
    });
    return _fetchRssEvents(uri, 'Google News');
  }

  Future<List<LocationEvent>> _fetchBingNewsEvents(String searchTerm) {
    final uri = Uri.https('www.bing.com', '/news/search', {
      'q': '$searchTerm 近期事件',
      'format': 'RSS',
      'setlang': 'zh-cn',
      'cc': 'CN',
    });
    return _fetchRssEvents(uri, 'Bing News');
  }

  Future<List<LocationEvent>> _fetchDailyNewsEvents(String searchTerm) async {
    final uri = Uri.https('60s.viki.moe', '/v2/60s');
    final json = await _getJson(uri);
    final data = json['data'];
    if (data is! Map) return const [];
    final news = data['news'];
    if (news is! List) return const [];
    final publishedRaw = data['api_updated_at'];
    final publishedAt = publishedRaw is num
        ? DateTime.fromMillisecondsSinceEpoch(publishedRaw.toInt(), isUtc: true)
        : _parsePublishedAt(data['date']?.toString() ?? '');
    final terms = _locationTerms(searchTerm);
    final allTitles = news
        .map((item) => item.toString().trim())
        .where((title) => title.isNotEmpty)
        .toList();
    final local = allTitles
        .where((title) => terms.any(title.contains))
        .take(5)
        .toList();
    final selected = local.isNotEmpty ? local : allTitles.take(3).toList();
    final sourceName = local.isNotEmpty ? '60s 日报（本地匹配）' : '60s 日报（全国背景）';
    return [
      for (final title in selected)
        LocationEvent(
          title: _limited(title, 180),
          sourceName: sourceName,
          url: 'https://60s.viki.moe/',
          publishedAt: publishedAt,
        ),
    ];
  }

  Future<List<LocationEvent>> _fetchRssEvents(
    Uri uri,
    String fallbackSource,
  ) async {
    final response = await _client
        .get(uri, headers: _headers)
        .timeout(requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException('HTTP ${response.statusCode}', uri);
    }
    final body = utf8.decode(response.bodyBytes, allowMalformed: true).trim();
    if (!body.startsWith('<?xml') &&
        !body.startsWith('<rss') &&
        !body.startsWith('<feed')) {
      return const [];
    }
    final document = XmlDocument.parse(body);
    final events = <LocationEvent>[];
    for (final item in document.findAllElements('item')) {
      final title = item.getElement('title')?.innerText.trim() ?? '';
      if (title.isEmpty) continue;
      final link = item.getElement('link')?.innerText.trim() ?? '';
      final source = item.getElement('source')?.innerText.trim();
      final description =
          item.getElement('description')?.innerText.trim() ?? '';
      events.add(
        LocationEvent(
          title: _limited(title, 180),
          sourceName: source?.isNotEmpty == true
              ? source!
              : _sourceFromUrl(link, fallbackSource),
          url: _limited(link, 500),
          summary: _limited(_plainText(description), 320),
          publishedAt: _parsePublishedAt(
            item.getElement('pubDate')?.innerText.trim() ?? '',
          ),
        ),
      );
    }
    return events;
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final response = await _client
        .get(uri, headers: _headers)
        .timeout(requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException('HTTP ${response.statusCode}', uri);
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) {
      throw const FormatException('Expected a JSON object');
    }
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }

  Future<bool> openAppSettings() => locationGateway.openAppSettings();

  Future<bool> openLocationSettings() => locationGateway.openLocationSettings();

  void close() {
    if (_ownsClient) _client.close();
  }
}

class _PlaceInfo {
  const _PlaceInfo({
    this.country = '',
    this.region = '',
    this.city = '',
    this.district = '',
    this.facts = const [],
    this.available = false,
  });

  final String country;
  final String region;
  final String city;
  final String district;
  final List<String> facts;
  final bool available;

  String get searchTerm {
    final local = <String>[];
    for (final value in [city, district]) {
      final normalized = value.trim();
      if (normalized.isNotEmpty && !local.contains(normalized)) {
        local.add(normalized);
      }
    }
    if (local.isNotEmpty) return local.join(' ');
    for (final value in [region, country]) {
      if (value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }
}

class _WeatherInfo {
  const _WeatherInfo({this.summary = '', this.timezone = ''});

  final String summary;
  final String timezone;
}

double _roundedCoordinate(double value) =>
    double.parse(value.toStringAsFixed(4));

String _weatherName(int? code) {
  if (code == null) return '天气未知';
  if (code == 0) return '晴';
  if (code <= 3) return '多云';
  if (code == 45 || code == 48) return '雾';
  if (code >= 51 && code <= 57) return '毛毛雨';
  if (code >= 61 && code <= 67) return '雨';
  if (code >= 71 && code <= 77) return '雪';
  if (code >= 80 && code <= 82) return '阵雨';
  if (code >= 85 && code <= 86) return '阵雪';
  if (code >= 95) return '雷雨';
  return '天气代码 $code';
}

String _compassDirection(double degrees) {
  const names = ['北', '东北', '东', '东南', '南', '西南', '西', '西北'];
  final normalized = ((degrees % 360) + 360) % 360;
  final index = ((normalized + 22.5) ~/ 45) % names.length;
  return names[index];
}

String _sourceFromUrl(String value, String fallback) {
  final uri = Uri.tryParse(value);
  if (uri == null || uri.host.isEmpty) return fallback;
  return uri.host.replaceFirst(RegExp(r'^www\.'), '');
}

String _plainText(String value) {
  final withoutTags = value.replaceAll(RegExp(r'<[^>]+>'), ' ');
  return withoutTags.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _limited(String value, int maxLength) {
  if (value.length <= maxLength) return value;
  return '${value.substring(0, maxLength)}…';
}

List<String> _locationTerms(String searchTerm) {
  final terms = <String>{};
  for (final raw in searchTerm.split(RegExp(r'\s+'))) {
    final value = raw.trim();
    if (value.isEmpty) continue;
    terms.add(value);
    final shortened = value.replaceFirst(
      RegExp(r'(特别行政区|自治区|自治州|省|市|区|县)$'),
      '',
    );
    if (shortened.length >= 2) terms.add(shortened);
  }
  return terms.toList();
}

DateTime? _parsePublishedAt(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) return null;
  final direct = DateTime.tryParse(normalized);
  if (direct != null) return direct;

  final gdelt = RegExp(
    r'^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z$',
  ).firstMatch(normalized);
  if (gdelt != null) {
    return DateTime.utc(
      int.parse(gdelt.group(1)!),
      int.parse(gdelt.group(2)!),
      int.parse(gdelt.group(3)!),
      int.parse(gdelt.group(4)!),
      int.parse(gdelt.group(5)!),
      int.parse(gdelt.group(6)!),
    );
  }

  final rfc = RegExp(
    r'^(?:[A-Za-z]{3},\s*)?(\d{1,2})\s+([A-Za-z]{3})\s+'
    r'(\d{4})\s+(\d{2}):(\d{2}):(\d{2})',
  ).firstMatch(normalized);
  if (rfc == null) return null;
  const months = {
    'Jan': 1,
    'Feb': 2,
    'Mar': 3,
    'Apr': 4,
    'May': 5,
    'Jun': 6,
    'Jul': 7,
    'Aug': 8,
    'Sep': 9,
    'Oct': 10,
    'Nov': 11,
    'Dec': 12,
  };
  final month = months[rfc.group(2)];
  if (month == null) return null;
  return DateTime.utc(
    int.parse(rfc.group(3)!),
    month,
    int.parse(rfc.group(1)!),
    int.parse(rfc.group(4)!),
    int.parse(rfc.group(5)!),
    int.parse(rfc.group(6)!),
  );
}

String _safeError(Object error) {
  final value = error.toString();
  return value.length <= 120 ? value : '${value.substring(0, 120)}…';
}
