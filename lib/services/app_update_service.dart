import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class AppUpdateRelease {
  const AppUpdateRelease({
    required this.version,
    required this.buildNumber,
    required this.releaseNotes,
    required this.downloadUri,
  });

  final String version;
  final int buildNumber;
  final String releaseNotes;
  final Uri downloadUri;
}

class AppUpdateService {
  const AppUpdateService();

  static final Uri _endpoint = Uri.parse(
    'https://scooby-backend.vercel.app/api/app-update',
  );

  Future<AppUpdateRelease?> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final response = await http.get(_endpoint).timeout(
        const Duration(seconds: 8),
      );
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['enabled'] != true) return null;

      final version = decoded['latestVersion'];
      final buildNumber = decoded['latestBuildNumber'];
      final releaseNotes = decoded['releaseNotes'];
      final downloadUrl = decoded['downloadUrl'];
      if (version is! String ||
          buildNumber is! int ||
          releaseNotes is! String ||
          downloadUrl is! String) {
        return null;
      }

      final downloadUri = Uri.tryParse(downloadUrl);
      if (downloadUri == null || downloadUri.scheme != 'https') return null;

      final isNewerVersion = _compareVersions(version, packageInfo.version) > 0;
      final installedBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
      final isNewerBuild = buildNumber > installedBuild;
      if (!isNewerVersion && !isNewerBuild) return null;

      return AppUpdateRelease(
        version: version,
        buildNumber: buildNumber,
        releaseNotes: releaseNotes,
        downloadUri: downloadUri,
      );
    } catch (_) {
      // Update checks are optional; network or metadata errors should not
      // interrupt connecting to the scooter.
      return null;
    }
  }

  int _compareVersions(String first, String second) {
    List<int> parts(String version) {
      final core = version.split('+').first.split('-').first;
      return core.split('.').map((part) => int.tryParse(part) ?? 0).toList();
    }

    final firstParts = parts(first);
    final secondParts = parts(second);
    final length = firstParts.length > secondParts.length
        ? firstParts.length
        : secondParts.length;

    for (var index = 0; index < length; index++) {
      final firstPart = index < firstParts.length ? firstParts[index] : 0;
      final secondPart = index < secondParts.length ? secondParts[index] : 0;
      if (firstPart != secondPart) return firstPart.compareTo(secondPart);
    }
    return 0;
  }
}
