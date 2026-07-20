import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'release_platform.dart';

class AvailableUpdate {
  const AvailableUpdate({
    required this.version,
    required this.downloadUrl,
    required this.notes,
    required this.sha256,
  });

  final String version;
  final String downloadUrl;
  final String notes;
  final String sha256;
}

class UpdateService {
  static const manifestUrl = String.fromEnvironment(
    'TRIPWEAVE_UPDATE_MANIFEST_URL',
  );

  Future<AvailableUpdate?> check() async {
    final manifest = Uri.tryParse(manifestUrl.trim());
    if (manifest == null || manifest.scheme != 'https') return null;
    final platform = releasePlatformKey();
    if (platform == null) return null;
    final package = await PackageInfo.fromPlatform();
    final response = await http
        .get(
          manifest.replace(
            queryParameters: {
              ...manifest.queryParameters,
              't': '${DateTime.now().millisecondsSinceEpoch}',
            },
          ),
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    final root = jsonDecode(utf8.decode(response.bodyBytes));
    if (root is! Map || root['release'] is! Map) return null;
    final release = root['release'] as Map;
    final version = '${release['version'] ?? ''}'.trim();
    final platforms = release['platforms'];
    if (version.isEmpty || platforms is! Map || platforms[platform] is! Map) {
      return null;
    }
    if (_compareVersions(version, package.version) <= 0) return null;
    final entry = platforms[platform] as Map;
    final url = '${entry['url'] ?? ''}'.trim();
    final download = Uri.tryParse(url);
    if (download == null || download.scheme != 'https') return null;
    return AvailableUpdate(
      version: version,
      downloadUrl: url,
      notes: '${release['summary'] ?? '包含功能改进和问题修复。'}'.trim(),
      sha256: '${entry['sha256'] ?? ''}'.trim(),
    );
  }

  Future<bool> open(AvailableUpdate update) => launchUrl(
    Uri.parse(update.downloadUrl),
    mode: releasePlatformKey() == 'web'
        ? LaunchMode.platformDefault
        : LaunchMode.externalApplication,
  );
}

int _compareVersions(String left, String right) {
  List<int> parse(String value) => value
      .split(RegExp(r'[^0-9]+'))
      .where((part) => part.isNotEmpty)
      .take(4)
      .map(int.parse)
      .toList();
  final a = parse(left);
  final b = parse(right);
  for (var index = 0; index < 4; index++) {
    final av = index < a.length ? a[index] : 0;
    final bv = index < b.length ? b[index] : 0;
    if (av != bv) return av.compareTo(bv);
  }
  return 0;
}
