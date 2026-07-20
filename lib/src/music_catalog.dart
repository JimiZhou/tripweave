import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class MusicTrack {
  const MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.mood,
    required this.streamUrl,
    required this.sourceUrl,
    required this.license,
    required this.licenseUrl,
  });

  final String id;
  final String title;
  final String artist;
  final String mood;
  final String streamUrl;
  final String sourceUrl;
  final String license;
  final String licenseUrl;
}

abstract final class MusicCatalog {
  static const _catalogUrl = String.fromEnvironment(
    'TRIPWEAVE_MUSIC_CATALOG_URL',
  );
  static const _defaults = <MusicTrack>[
    MusicTrack(
      id: 'city-run',
      title: 'City Run',
      artist: 'FreePD collection',
      mood: '城市、轻快、短节奏',
      streamUrl:
          'https://raw.githubusercontent.com/SoundSafari/CC0-1.0-Music/main/freepd.com/City%20Run.mp3',
      sourceUrl:
          'https://github.com/SoundSafari/CC0-1.0-Music/blob/main/freepd.com/City%20Run.mp3',
      license: 'CC0 1.0 公共领域贡献',
      licenseUrl:
          'https://creativecommons.org/publicdomain/zero/1.0/deed.zh-hans',
    ),
    MusicTrack(
      id: 'elevate-inspirate',
      title: 'Elevate Inspirate',
      artist: 'Bryan Teoh',
      mood: '明亮、开阔、启程感',
      streamUrl:
          'https://raw.githubusercontent.com/SoundSafari/CC0-1.0-Music/main/freepd.com/Elevate%20Inspirate.mp3',
      sourceUrl:
          'https://github.com/SoundSafari/CC0-1.0-Music/blob/main/freepd.com/Elevate%20Inspirate.mp3',
      license: 'CC0 1.0 公共领域贡献',
      licenseUrl:
          'https://creativecommons.org/publicdomain/zero/1.0/deed.zh-hans',
    ),
    MusicTrack(
      id: 'eye-of-forgiveness',
      title: 'Eye of Forgiveness',
      artist: 'Rafael Krux',
      mood: '电影、舒缓、回望感',
      streamUrl:
          'https://raw.githubusercontent.com/SoundSafari/CC0-1.0-Music/main/freepd.com/Eye%20of%20Forgiveness.mp3',
      sourceUrl:
          'https://github.com/SoundSafari/CC0-1.0-Music/blob/main/freepd.com/Eye%20of%20Forgiveness.mp3',
      license: 'CC0 1.0 公共领域贡献',
      licenseUrl:
          'https://creativecommons.org/publicdomain/zero/1.0/deed.zh-hans',
    ),
    MusicTrack(
      id: 'happy-whistling-ukulele',
      title: 'Happy Whistling Ukulele',
      artist: 'Rafael Krux',
      mood: '手帐、家庭、温暖、原声',
      streamUrl:
          'https://raw.githubusercontent.com/SoundSafari/CC0-1.0-Music/main/freepd.com/Happy%20Whistling%20Ukulele.mp3',
      sourceUrl:
          'https://github.com/SoundSafari/CC0-1.0-Music/blob/main/freepd.com/Happy%20Whistling%20Ukulele.mp3',
      license: 'CC0 1.0 公共领域贡献',
      licenseUrl:
          'https://creativecommons.org/publicdomain/zero/1.0/deed.zh-hans',
    ),
    MusicTrack(
      id: 'martini-sunset',
      title: 'Martini Sunset',
      artist: 'Kevin MacLeod',
      mood: '海边、夏日、放松',
      streamUrl:
          'https://raw.githubusercontent.com/SoundSafari/CC0-1.0-Music/main/freepd.com/Martini%20Sunset.mp3',
      sourceUrl:
          'https://github.com/SoundSafari/CC0-1.0-Music/blob/main/freepd.com/Martini%20Sunset.mp3',
      license: 'CC0 1.0 公共领域贡献',
      licenseUrl:
          'https://creativecommons.org/publicdomain/zero/1.0/deed.zh-hans',
    ),
    MusicTrack(
      id: 'forest-frolic-loop',
      title: 'Forest Frolic Loop',
      artist: 'Kevin MacLeod',
      mood: '自然、森林、轻盈',
      streamUrl:
          'https://raw.githubusercontent.com/SoundSafari/CC0-1.0-Music/main/freepd.com/Forest%20Frolic%20Loop.mp3',
      sourceUrl:
          'https://github.com/SoundSafari/CC0-1.0-Music/blob/main/freepd.com/Forest%20Frolic%20Loop.mp3',
      license: 'CC0 1.0 公共领域贡献',
      licenseUrl:
          'https://creativecommons.org/publicdomain/zero/1.0/deed.zh-hans',
    ),
    MusicTrack(
      id: 'shenzhen-nightlife',
      title: 'Shenzhen Nightlife',
      artist: 'Kevin MacLeod',
      mood: '夜景、电子、都市',
      streamUrl:
          'https://raw.githubusercontent.com/SoundSafari/CC0-1.0-Music/main/freepd.com/Shenzhen%20Nightlife.mp3',
      sourceUrl:
          'https://github.com/SoundSafari/CC0-1.0-Music/blob/main/freepd.com/Shenzhen%20Nightlife.mp3',
      license: 'CC0 1.0 公共领域贡献',
      licenseUrl:
          'https://creativecommons.org/publicdomain/zero/1.0/deed.zh-hans',
    ),
    MusicTrack(
      id: 'adventure',
      title: 'Adventure',
      artist: 'Rafael Krux',
      mood: '公路、冒险、电影感',
      streamUrl:
          'https://raw.githubusercontent.com/SoundSafari/CC0-1.0-Music/main/freepd.com/Adventure.mp3',
      sourceUrl:
          'https://github.com/SoundSafari/CC0-1.0-Music/blob/main/freepd.com/Adventure.mp3',
      license: 'CC0 1.0 公共领域贡献',
      licenseUrl:
          'https://creativecommons.org/publicdomain/zero/1.0/deed.zh-hans',
    ),
  ];

  static List<MusicTrack> tracks = List.of(_defaults);
  static DateTime? _refreshedAt;

  static MusicTrack byId(String id) =>
      tracks.firstWhere((track) => track.id == id, orElse: () => tracks.first);

  static bool containsId(String id) => tracks.any((track) => track.id == id);

  static final Map<String, Uint8List> _cache = {};

  static Future<void> refresh({bool force = false}) async {
    final catalog = Uri.tryParse(_catalogUrl.trim());
    if (catalog == null || catalog.scheme != 'https') return;
    if (!force &&
        _refreshedAt != null &&
        DateTime.now().difference(_refreshedAt!) < const Duration(minutes: 2)) {
      return;
    }
    try {
      final response = await http
          .get(catalog)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final payload = jsonDecode(utf8.decode(response.bodyBytes));
      final rawTracks = payload is Map ? payload['tracks'] : null;
      if (rawTracks is! List) return;
      final parsed = <MusicTrack>[];
      for (final raw in rawTracks.whereType<Map>()) {
        final id = '${raw['id'] ?? ''}'.trim();
        final title = '${raw['title'] ?? ''}'.trim();
        final artist = '${raw['artist'] ?? ''}'.trim();
        final streamUrl = '${raw['streamUrl'] ?? ''}'.trim();
        final sourceUrl = '${raw['sourceUrl'] ?? ''}'.trim();
        final license = '${raw['license'] ?? ''}'.trim();
        final licenseUrl = '${raw['licenseUrl'] ?? ''}'.trim();
        final tags = raw['styleTags'] is List
            ? (raw['styleTags'] as List)
                  .map((value) => '$value'.trim())
                  .where((value) => value.isNotEmpty)
                  .take(12)
                  .toList()
            : <String>[];
        if (id.isEmpty ||
            title.isEmpty ||
            artist.isEmpty ||
            !streamUrl.startsWith('https://') ||
            !sourceUrl.startsWith('https://') ||
            license.isEmpty ||
            !licenseUrl.startsWith('https://')) {
          continue;
        }
        parsed.add(
          MusicTrack(
            id: id,
            title: title,
            artist: artist,
            mood: tags.isEmpty ? '旅行、自然' : tags.join('、'),
            streamUrl: streamUrl,
            sourceUrl: sourceUrl,
            license: license,
            licenseUrl: licenseUrl,
          ),
        );
      }
      if (parsed.length >= 3) {
        tracks = parsed;
        _refreshedAt = DateTime.now();
      }
    } catch (_) {
      // Offline users keep the last known or built-in metadata catalog.
    }
  }

  static Future<Uint8List> loadBytes(String id) async {
    final track = byId(id);
    final cached = _cache[track.id];
    if (cached != null) return cached;
    final response = await http
        .get(Uri.parse(track.streamUrl))
        .timeout(const Duration(seconds: 45));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        '没有获取到背景音乐 ${track.title}（HTTP ${response.statusCode}）。',
      );
    }
    if (response.bodyBytes.isEmpty) {
      throw StateError('背景音乐 ${track.title} 返回了空文件。');
    }
    return _cache[track.id] = response.bodyBytes;
  }
}
