import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/app_update_info.dart';
import '../../theme/app_theme.dart';

/// Service responsible for querying app updates and presenting update alerts.
class UpdateService {
  final Dio _dio;
  static const String currentAppVersion = '1.0.0';
  static const String githubRepo = 'NonLaHu/ani_mobile';
  static const String githubReleasesUrl = 'https://github.com/$githubRepo/releases';
  static const String versionJsonUrl =
      'https://raw.githubusercontent.com/$githubRepo/main/version.json';

  UpdateService({Dio? customDio}) : _dio = customDio ?? Dio();

  /// Checks for available application updates.
  ///
  /// Priority:
  /// 1. Fast, uncapped Fastly CDN query to `version.json` in the GitHub repository.
  /// 2. Fallback to GitHub REST Releases API (`api.github.com/repos/.../releases/latest`).
  /// 3. Offline/error fallback (silently reports up-to-date).
  Future<AppUpdateInfo> checkForUpdates({bool forceMockUpdate = false}) async {
    if (forceMockUpdate) {
      return const AppUpdateInfo(
        currentVersion: currentAppVersion,
        latestVersion: '1.1.0',
        hasUpdate: true,
        releaseTitle: 'v1.1.0 - Media Gestures & External Player',
        releaseNotes:
            '• Volume swipe gesture: drag up/down on screen to adjust volume\n'
            '• External Player support: open streams directly in VLC, MX Player, or MPV\n'
            '• Real-time startup update notifications\n'
            '• Subtitle silent toggle & enhanced offline download validation\n'
            '• General performance improvements and bug fixes',
        downloadUrl: githubReleasesUrl,
      );
    }

    // Step 1: Attempt ultra-fast CDN fetch from version.json in raw GitHub content
    try {
      final response = await _dio.get<dynamic>(
        versionJsonUrl,
        options: Options(
          responseType: ResponseType.plain,
          headers: {
            'Cache-Control': 'no-cache',
            'Pragma': 'no-cache',
          },
          receiveTimeout: const Duration(seconds: 4),
          sendTimeout: const Duration(seconds: 4),
        ),
      );

      if (response.data != null) {
        final Map<String, dynamic> data = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : (jsonDecode(response.data.toString()) as Map<String, dynamic>);

        final latest = (data['latest_version'] as String? ?? '').replaceAll('v', '').trim();
        if (latest.isNotEmpty) {
          final title = data['release_title'] as String? ?? 'v$latest';
          final notes = data['release_notes'] as String? ?? 'Bug fixes and performance improvements.';
          final downloadUrl = data['download_url'] as String? ??
              data['apk_url'] as String? ??
              githubReleasesUrl;
          final hasUpdate = _isVersionGreater(latest, currentAppVersion);

          return AppUpdateInfo(
            currentVersion: currentAppVersion,
            latestVersion: latest,
            hasUpdate: hasUpdate,
            releaseTitle: title,
            releaseNotes: notes,
            downloadUrl: downloadUrl,
          );
        }
      }
    } catch (_) {
      // Proceed to GitHub Releases API fallback if raw version.json cannot be reached
    }

    // Step 2: Fallback to GitHub Releases REST API
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'https://api.github.com/repos/$githubRepo/releases/latest',
        options: Options(
          headers: {
            'Accept': 'application/vnd.github.v3+json',
            'User-Agent': 'ani_mobile-updater',
          },
          receiveTimeout: const Duration(seconds: 4),
          sendTimeout: const Duration(seconds: 4),
        ),
      );

      final data = response.data;
      if (data != null && data['tag_name'] != null) {
        final tagName = (data['tag_name'] as String).replaceAll('v', '').trim();
        final name = data['name'] as String? ?? 'v$tagName';
        final body = data['body'] as String? ?? 'Bug fixes and performance improvements.';
        final htmlUrl = data['html_url'] as String? ?? githubReleasesUrl;
        final hasUpdate = _isVersionGreater(tagName, currentAppVersion);

        return AppUpdateInfo(
          currentVersion: currentAppVersion,
          latestVersion: tagName,
          hasUpdate: hasUpdate,
          releaseTitle: name,
          releaseNotes: body,
          downloadUrl: htmlUrl,
        );
      }
    } catch (_) {
      // Silently fall through on network failure or if no GitHub releases exist yet
    }

    // Default behavior when offline or already on latest version
    return const AppUpdateInfo(
      currentVersion: currentAppVersion,
      latestVersion: currentAppVersion,
      hasUpdate: false,
      releaseTitle: 'Latest Version',
      releaseNotes: 'Your app is up to date.',
      downloadUrl: githubReleasesUrl,
    );
  }

  /// Compares semantic versions (e.g. "1.1.0" > "1.0.0")
  static bool _isVersionGreater(String remote, String current) {
    try {
      final rParts = remote.split('.').map((p) => int.tryParse(p) ?? 0).toList();
      final cParts = current.split('.').map((p) => int.tryParse(p) ?? 0).toList();

      for (var i = 0; i < 3; i++) {
        final r = i < rParts.length ? rParts[i] : 0;
        final c = i < cParts.length ? cParts[i] : 0;
        if (r > c) return true;
        if (r < c) return false;
      }
      return false;
    } catch (_) {
      return remote != current;
    }
  }

  /// Presents a closable update pop-up dialog to the user.
  static Future<void> showUpdateDialog(
    BuildContext context,
    AppUpdateInfo updateInfo,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isDark ? AppTheme.accentCyan.withOpacity(0.3) : AppTheme.primaryPurple.withOpacity(0.2),
              width: 1.2,
            ),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accentCyan.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.rocket_launch_rounded,
                  color: AppTheme.accentCyan,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Update Available',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'v${updateInfo.latestVersion} (Current: v${updateInfo.currentVersion})',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? AppTheme.accentCyan : AppTheme.primaryPurple,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (updateInfo.releaseTitle.isNotEmpty) ...[
                    Text(
                      updateInfo.releaseTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.black12,
                      ),
                    ),
                    child: Text(
                      updateInfo.releaseNotes.isNotEmpty
                          ? updateInfo.releaseNotes
                          : 'New version released with improvements and bug fixes.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Later',
                style: TextStyle(
                  color: isDark ? AppTheme.textMuted : AppTheme.lightTextMuted,
                ),
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentCyan,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Update Now', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () async {
                Navigator.of(ctx).pop();
                final url = updateInfo.downloadUrl ?? githubReleasesUrl;
                final uri = Uri.tryParse(url);
                if (uri != null) {
                  try {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } catch (_) {}
                }
              },
            ),
          ],
        );
      },
    );
  }
}
