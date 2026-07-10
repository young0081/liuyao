class LocationEvent {
  const LocationEvent({
    required this.title,
    required this.sourceName,
    required this.url,
    this.summary = '',
    this.publishedAt,
  });

  final String title;
  final String sourceName;
  final String url;
  final String summary;
  final DateTime? publishedAt;

  Map<String, dynamic> toJson() => {
    'title': title,
    'sourceName': sourceName,
    'url': url,
    'summary': summary,
    'publishedAt': publishedAt?.millisecondsSinceEpoch,
  };

  factory LocationEvent.fromJson(Map<String, dynamic> json) {
    final published = json['publishedAt'];
    return LocationEvent(
      title: json['title'] as String? ?? '',
      sourceName: json['sourceName'] as String? ?? '',
      url: json['url'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      publishedAt: published is num
          ? DateTime.fromMillisecondsSinceEpoch(published.toInt(), isUtc: true)
          : null,
    );
  }
}

/// 起卦时冻结的地理与公开环境资料。
///
/// 坐标仅保留四位小数（约十米量级），用于位置参照和历史恢复；
/// 外部资料缺失时仍可保存纯定位结果。
class LocationContext {
  const LocationContext({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.capturedAt,
    this.country = '',
    this.region = '',
    this.city = '',
    this.district = '',
    this.timezone = '',
    this.weatherSummary = '',
    this.regionalFacts = const [],
    this.recentEvents = const [],
    this.dataSources = const [],
    this.warnings = const [],
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime capturedAt;
  final String country;
  final String region;
  final String city;
  final String district;
  final String timezone;
  final String weatherSummary;
  final List<String> regionalFacts;
  final List<LocationEvent> recentEvents;
  final List<String> dataSources;
  final List<String> warnings;

  String get placeLabel {
    final parts = <String>[];
    for (final value in [region, city, district]) {
      final normalized = value.trim();
      if (normalized.isNotEmpty && !parts.contains(normalized)) {
        parts.add(normalized);
      }
    }
    if (parts.isNotEmpty) return parts.join(' · ');
    if (country.trim().isNotEmpty) return country.trim();
    return coordinateLabel;
  }

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

  String get coordinateLabel {
    final lat = latitude.abs().toStringAsFixed(3);
    final lon = longitude.abs().toStringAsFixed(3);
    return '${latitude >= 0 ? '北纬' : '南纬'} $lat° · '
        '${longitude >= 0 ? '东经' : '西经'} $lon°';
  }

  bool get hasOnlineContext =>
      weatherSummary.isNotEmpty ||
      regionalFacts.isNotEmpty ||
      recentEvents.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'accuracyMeters': accuracyMeters,
    'capturedAt': capturedAt.millisecondsSinceEpoch,
    'country': country,
    'region': region,
    'city': city,
    'district': district,
    'timezone': timezone,
    'weatherSummary': weatherSummary,
    'regionalFacts': regionalFacts,
    'recentEvents': recentEvents.map((event) => event.toJson()).toList(),
    'dataSources': dataSources,
    'warnings': warnings,
  };

  factory LocationContext.fromJson(Map<String, dynamic> json) {
    return LocationContext(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      accuracyMeters: (json['accuracyMeters'] as num?)?.toDouble() ?? 0,
      capturedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['capturedAt'] as num?)?.toInt() ?? 0,
        isUtc: true,
      ),
      country: json['country'] as String? ?? '',
      region: json['region'] as String? ?? '',
      city: json['city'] as String? ?? '',
      district: json['district'] as String? ?? '',
      timezone: json['timezone'] as String? ?? '',
      weatherSummary: json['weatherSummary'] as String? ?? '',
      regionalFacts: (json['regionalFacts'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      recentEvents: (json['recentEvents'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (item) => LocationEvent.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList(),
      dataSources: (json['dataSources'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      warnings: (json['warnings'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
    );
  }
}
