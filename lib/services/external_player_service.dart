import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service enabling playback in external applications (e.g. VLC, MX Player, MPV)
/// and native system sharing on Android and other platforms.
class ExternalPlayerService {
  /// Opens the stream URL or offline video file in an external media player,
  /// falling back to the native system share sheet.
  static Future<void> openOrShareEpisode({
    required BuildContext context,
    required String title,
    required String urlOrPath,
    bool isLocalFile = false,
  }) async {
    try {
      if (isLocalFile) {
        final file = File(urlOrPath);
        if (file.existsSync()) {
          // Share local video file directly so Android can open it in VLC, MX Player, etc.
          await Share.shareXFiles(
            [XFile(urlOrPath)],
            text: title,
          );
          return;
        }
      }

      // If it's a web stream URL
      final uri = Uri.tryParse(urlOrPath);
      if (uri != null) {
        bool launched = false;
        try {
          // Attempt to open directly in an external media player application
          launched = await launchUrl(
            uri,
            mode: LaunchMode.externalNonBrowserApplication,
          );
        } catch (_) {}

        if (!launched) {
          // Fall back to sharing the video link so user can select their preferred player
          await Share.share(
            urlOrPath,
            subject: title,
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open external player: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}
