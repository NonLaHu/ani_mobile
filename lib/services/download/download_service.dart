import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/anime.dart';
import '../../models/episode.dart';
import '../../models/video_source.dart';

typedef DownloadProgressCallback = void Function(double progress, int downloadedBytes, int totalBytes);

/// Exception thrown when a download is suspended by user action
class DownloadPausedException implements Exception {
  final String message;
  const DownloadPausedException([this.message = 'Download paused by user']);
  @override
  String toString() => message;
}

/// Represents an offline video file detected on disk inside the downloads folder
class DiskVideoFile {
  final File file;
  final String animeTitle;
  final int episodeNumber;
  final bool isDub;
  final int sizeBytes;
  final DateTime modifiedAt;

  const DiskVideoFile({
    required this.file,
    required this.animeTitle,
    required this.episodeNumber,
    required this.isDub,
    required this.sizeBytes,
    required this.modifiedAt,
  });

  String get formattedSize {
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Service managing anime video stream downloads (supporting ffmpeg remuxing and pure Dart HLS fallback).
class DownloadService {
  final Dio _dio;
  final Map<String, Process> _activeFfmpegProcesses = {};
  final Map<String, CancelToken> _activeDioTokens = {};
  final Set<String> _pausedTasks = {};

  DownloadService({Dio? customDio})
      : _dio = customDio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(minutes: 5),
              ),
            );

  /// Requests runtime storage and notification permissions on mobile only when download is initiated
  Future<bool> requestDownloadPermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return true; // Desktop platforms have standard filesystem access
    }

    try {
      // Notification permission (Android 13+)
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }

      // Storage permissions
      if (Platform.isAndroid) {
        final storage = await Permission.storage.request();
        if (storage.isGranted) return true;

        final videos = await Permission.videos.request();
        if (videos.isGranted) return true;

        final manage = await Permission.manageExternalStorage.request();
        if (manage.isGranted) return true;
      }
      return true;
    } catch (e) {
      print('Permission request handled with fallback: $e');
      return true;
    }
  }

  static const String customDownloadPathKey = 'ani_mobile_custom_download_path_v1';

  /// Resolves the app's persistent downloads directory inside the system Downloads folder (or custom path)
  Future<Directory> getAniDownloadDirectory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customPath = prefs.getString(customDownloadPathKey);
      if (customPath != null && customPath.trim().isNotEmpty) {
        final customDir = Directory(customPath.trim());
        if (!customDir.existsSync()) {
          customDir.createSync(recursive: true);
        }
        return customDir;
      }
    } catch (_) {}

    Directory? baseDir;

    if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
      if (home != null) {
        final candidate = Directory('$home/Downloads');
        if (candidate.existsSync()) {
          baseDir = candidate;
        }
      }
      if (baseDir == null) {
        try {
          baseDir = await path_provider.getDownloadsDirectory();
        } catch (_) {}
      }
    } else if (Platform.isAndroid) {
      // Standard Android public Download directory
      final publicDownload = Directory('/storage/emulated/0/Download');
      if (publicDownload.existsSync()) {
        baseDir = publicDownload;
      } else {
        try {
          baseDir = await path_provider.getDownloadsDirectory();
        } catch (_) {}
      }
    }

    baseDir ??= await path_provider.getApplicationDocumentsDirectory();

    final aniDir = Directory('${baseDir.path}/ani_mobile');
    if (!aniDir.existsSync()) {
      aniDir.createSync(recursive: true);
    }
    return aniDir;
  }

  /// Sets or clears a custom download directory path
  Future<void> setCustomDownloadPath(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    if (path == null || path.trim().isEmpty) {
      await prefs.remove(customDownloadPathKey);
    } else {
      await prefs.setString(customDownloadPathKey, path.trim());
    }
  }

  /// Sanitizes string for safe filesystem usage
  String sanitizeFilename(String name) {
    return name
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Scans the ani_mobile directory on disk and returns all downloaded video files
  Future<List<DiskVideoFile>> scanDownloadedFiles() async {
    final rootDir = await getAniDownloadDirectory();
    final results = <DiskVideoFile>[];

    if (!rootDir.existsSync()) return results;

    try {
      final entities = rootDir.listSync(recursive: true, followLinks: false);
      for (final entity in entities) {
        if (entity is File) {
          final path = entity.path;
          if (path.endsWith('.mp4') || path.endsWith('.mkv') || path.endsWith('.ts')) {
            final fileName = entity.uri.pathSegments.last;
            // Pattern: <Title>_EP<Number>_<mode>.mp4
            final match = RegExp(r'^(.*?)_EP(\d+)_?(sub|dub)?\.(mp4|mkv|ts)$', caseSensitive: false)
                .firstMatch(fileName);

            final title = match != null ? match.group(1)!.replaceAll('_', ' ') : fileName;
            final epNum = match != null ? int.tryParse(match.group(2)!) ?? 1 : 1;
            final isDub = match != null && match.group(3)?.toLowerCase() == 'dub';
            final stat = entity.statSync();

            results.add(
              DiskVideoFile(
                file: entity,
                animeTitle: title,
                episodeNumber: epNum,
                isDub: isDub,
                sizeBytes: stat.size,
                modifiedAt: stat.modified,
              ),
            );
          }
        }
      }
      // Sort newest downloads first
      results.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    } catch (e) {
      print('Error scanning downloaded files on disk: $e');
    }

    return results;
  }

  /// Tests if system ffmpeg is available
  Future<bool> hasFfmpeg() async {
    try {
      final res = await Process.run('which', ['ffmpeg']);
      return res.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Downloads an episode stream to disk with real-time progress callbacks
  Future<File> downloadEpisode({
    required Anime anime,
    required Episode episode,
    required VideoSource source,
    String? subtitleUrl,
    required DownloadProgressCallback onProgress,
  }) async {
    final baseDir = await getAniDownloadDirectory();
    final animeFolder = Directory('${baseDir.path}/${sanitizeFilename(anime.title)}');
    if (!animeFolder.existsSync()) {
      animeFolder.createSync(recursive: true);
    }

    final filename = '${sanitizeFilename(anime.title)}_EP${episode.number}_${episode.isDub ? "DUB" : "SUB"}.mp4';
    final targetFile = File('${animeFolder.path}/$filename');
    final taskId = '${anime.id}_${episode.id}';

    // Download subtitle track if available
    if (subtitleUrl != null && subtitleUrl.isNotEmpty) {
      try {
        final subFilename = '${sanitizeFilename(anime.title)}_EP${episode.number}_${episode.isDub ? "DUB" : "SUB"}.vtt';
        final subFile = File('${animeFolder.path}/$subFilename');
        final referer = source.headers['Referer'] ?? 'https://zokoanime.video/';
        await _dio.download(
          subtitleUrl,
          subFile.path,
          options: Options(headers: {'Referer': referer, ...source.headers}),
        );
      } catch (e) {
        print('Subtitle download ignored: $e');
      }
    }

    final stateFile = File('${targetFile.path}.state');
    final isResuming = stateFile.existsSync() && File('${targetFile.path}.tmp').existsSync();

    // Attempt ffmpeg remuxing if available and not resuming a segment download
    if (!isResuming && await hasFfmpeg()) {
      try {
        return await _downloadWithFfmpeg(
          taskId: taskId,
          source: source,
          targetFile: targetFile,
          onProgress: onProgress,
        );
      } catch (e) {
        if (_pausedTasks.contains(taskId)) {
          _pausedTasks.remove(taskId);
          throw const DownloadPausedException();
        }
        print('ffmpeg download failed, falling back to pure Dart HLS: $e');
      }
    }

    // Pure Dart HLS / Direct MP4 fallback
    return await _downloadWithDart(
      taskId: taskId,
      source: source,
      targetFile: targetFile,
      onProgress: onProgress,
    );
  }

  /// Downloads and remuxes video using ffmpeg with -extension_picky 0 (required for disguised .ts.jpg chunks)
  Future<File> _downloadWithFfmpeg({
    required String taskId,
    required VideoSource source,
    required File targetFile,
    required DownloadProgressCallback onProgress,
  }) async {
    final referer = source.headers['Referer'] ?? 'https://zokoanime.video/';
    final userAgent = source.headers['User-Agent'] ??
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

    final tempFile = File('${targetFile.path}.tmp');
    if (tempFile.existsSync()) {
      tempFile.deleteSync();
    }

    // Resolve variant stream URL from master playlist so ffmpeg with -extension_picky 0 operates directly on segments
    String targetUrl = source.url;
    if (targetUrl.contains('master.m3u8') || source.quality == 'Auto') {
      try {
        final masterResp = await _dio.get<String>(
          targetUrl,
          options: Options(
            headers: {'Referer': referer, 'User-Agent': userAgent},
            responseType: ResponseType.plain,
          ),
        );
        final playlistText = masterResp.data ?? '';
        final baseDir = targetUrl.substring(0, targetUrl.lastIndexOf('/'));
        final lines = playlistText.split('\n');
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].startsWith('#EXT-X-STREAM-INF') && i + 1 < lines.length) {
            final sub = lines[i + 1].trim();
            targetUrl = sub.startsWith('http') ? sub : '$baseDir/$sub';
            break;
          }
        }
      } catch (e) {
        print('Master variant resolution note: $e');
      }
    }

    final headersString = 'Referer: $referer\r\nUser-Agent: $userAgent\r\n';

    final args = [
      '-y',
      '-extension_picky',
      '0',
      '-headers',
      headersString,
      '-i',
      targetUrl,
      '-c',
      'copy',
      tempFile.path,
    ];

    final process = await Process.start('ffmpeg', args);
    _activeFfmpegProcesses[taskId] = process;

    double totalDurationSec = 1420.0; // default 23:40 fallback
    double currentPosSec = 0.0;

    process.stderr.transform(utf8.decoder).listen((output) {
      // Parse total duration e.g. "Duration: 00:23:40.00"
      final durMatch = RegExp(r'Duration:\s*(\d+):(\d+):(\d+\.?\d*)').firstMatch(output);
      if (durMatch != null) {
        final h = double.tryParse(durMatch.group(1)!) ?? 0;
        final m = double.tryParse(durMatch.group(2)!) ?? 0;
        final s = double.tryParse(durMatch.group(3)!) ?? 0;
        final parsed = h * 3600 + m * 60 + s;
        if (parsed > 0) totalDurationSec = parsed;
      }

      // Parse current position e.g. "time=00:05:12.30"
      final timeMatch = RegExp(r'time=\s*(\d+):(\d+):(\d+\.?\d*)').firstMatch(output);
      if (timeMatch != null) {
        final h = double.tryParse(timeMatch.group(1)!) ?? 0;
        final m = double.tryParse(timeMatch.group(2)!) ?? 0;
        final s = double.tryParse(timeMatch.group(3)!) ?? 0;
        currentPosSec = h * 3600 + m * 60 + s;

        final ratio = (currentPosSec / totalDurationSec).clamp(0.0, 0.99);
        final currentBytes = tempFile.existsSync() ? tempFile.lengthSync() : 0;
        onProgress(ratio, currentBytes, (currentBytes / (ratio > 0 ? ratio : 1)).toInt());
      }
    });

    final exitCode = await process.exitCode;
    _activeFfmpegProcesses.remove(taskId);

    if (exitCode != 0) {
      if (tempFile.existsSync()) tempFile.deleteSync();
      throw Exception('FFmpeg exited with error code $exitCode');
    }

    if (targetFile.existsSync()) targetFile.deleteSync();
    tempFile.renameSync(targetFile.path);

    onProgress(1.0, targetFile.lengthSync(), targetFile.lengthSync());
    return targetFile;
  }

  /// Pure Dart HLS and direct video downloader fallback (no ffmpeg dependency required)
  Future<File> _downloadWithDart({
    required String taskId,
    required VideoSource source,
    required File targetFile,
    required DownloadProgressCallback onProgress,
  }) async {
    final cancelToken = CancelToken();
    _activeDioTokens[taskId] = cancelToken;

    final tempFile = File('${targetFile.path}.tmp');
    final stateFile = File('${targetFile.path}.state');

    int startIndex = 0;
    int downloadedBytes = 0;

    if (stateFile.existsSync() && tempFile.existsSync()) {
      try {
        final stateJson = jsonDecode(stateFile.readAsStringSync()) as Map<String, dynamic>;
        startIndex = (stateJson['segmentIndex'] as num?)?.toInt() ?? 0;
        downloadedBytes = tempFile.lengthSync();
      } catch (_) {
        startIndex = 0;
        downloadedBytes = 0;
      }
    } else {
      if (tempFile.existsSync()) {
        try { tempFile.deleteSync(); } catch (_) {}
      }
      if (stateFile.existsSync()) {
        try { stateFile.deleteSync(); } catch (_) {}
      }
    }

    try {
      final referer = source.headers['Referer'] ?? 'https://zokoanime.video/';
      final reqHeaders = {
        'Referer': referer,
        'User-Agent': source.headers['User-Agent'] ??
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      };

      if (!source.isHls && !source.url.contains('.m3u8')) {
        // Direct MP4 file download
        await _dio.download(
          source.url,
          tempFile.path,
          cancelToken: cancelToken,
          options: Options(headers: reqHeaders),
          onReceiveProgress: (received, total) {
            final progress = total > 0 ? (received / total).clamp(0.0, 1.0) : 0.0;
            onProgress(progress, received, total > 0 ? total : received);
          },
        );
      } else {
        // HLS playlist parser & segment downloader
        final playlistResp = await _dio.get<String>(
          source.url,
          options: Options(headers: reqHeaders, responseType: ResponseType.plain),
          cancelToken: cancelToken,
        );

        final playlistText = playlistResp.data ?? '';
        final baseDir = source.url.substring(0, source.url.lastIndexOf('/'));

        // If master playlist, resolve first stream variant
        String variantUrl = source.url;
        if (playlistText.contains('#EXT-X-STREAM-INF')) {
          final lines = playlistText.split('\n');
          for (var i = 0; i < lines.length; i++) {
            if (lines[i].startsWith('#EXT-X-STREAM-INF') && i + 1 < lines.length) {
              final subUrl = lines[i + 1].trim();
              variantUrl = subUrl.startsWith('http') ? subUrl : '$baseDir/$subUrl';
              break;
            }
          }
        }

        // Fetch segment list from variant playlist
        final variantResp = variantUrl == source.url
            ? playlistResp
            : await _dio.get<String>(
                variantUrl,
                options: Options(headers: reqHeaders, responseType: ResponseType.plain),
                cancelToken: cancelToken,
              );

        final variantLines = (variantResp.data ?? '').split('\n');
        final variantBaseDir = variantUrl.substring(0, variantUrl.lastIndexOf('/'));
        final segments = <String>[];

        for (final line in variantLines) {
          final trimmed = line.trim();
          if (trimmed.isNotEmpty && !trimmed.startsWith('#')) {
            final fullSeg = trimmed.startsWith('http') ? trimmed : '$variantBaseDir/$trimmed';
            segments.add(fullSeg);
          }
        }

        if (segments.isEmpty) {
          throw Exception('No video segments found in HLS playlist');
        }

        final sink = tempFile.openSync(mode: FileMode.writeOnlyAppend);

        try {
          for (var i = startIndex; i < segments.length; i++) {
            if (cancelToken.isCancelled) break;

            final segUrl = segments[i];
            final resp = await _dio.get<List<int>>(
              segUrl,
              options: Options(
                headers: reqHeaders,
                responseType: ResponseType.bytes,
              ),
              cancelToken: cancelToken,
            );

            final bytes = resp.data;
            if (bytes != null && bytes.isNotEmpty) {
              sink.writeFromSync(bytes);
              downloadedBytes += bytes.length;
            }

            try {
              stateFile.writeAsStringSync(jsonEncode({
                'segmentIndex': i + 1,
                'totalSegments': segments.length,
                'downloadedBytes': downloadedBytes,
              }));
            } catch (_) {}

            final ratio = ((i + 1) / segments.length).clamp(0.0, 1.0);
            onProgress(ratio, downloadedBytes, (downloadedBytes / ratio).toInt());
          }
        } finally {
          sink.closeSync();
        }
      }

      if (cancelToken.isCancelled && _pausedTasks.contains(taskId)) {
        throw const DownloadPausedException();
      }

      if (stateFile.existsSync()) {
        try { stateFile.deleteSync(); } catch (_) {}
      }
      if (targetFile.existsSync()) targetFile.deleteSync();
      tempFile.renameSync(targetFile.path);

      onProgress(1.0, targetFile.lengthSync(), targetFile.lengthSync());
      return targetFile;
    } catch (e) {
      if (_pausedTasks.contains(taskId) || (e is DioException && cancelToken.isCancelled && _pausedTasks.contains(taskId))) {
        throw const DownloadPausedException();
      }
      rethrow;
    } finally {
      _activeDioTokens.remove(taskId);
      final wasPaused = _pausedTasks.remove(taskId);
      if (!wasPaused && cancelToken.isCancelled) {
        if (tempFile.existsSync()) {
          try { tempFile.deleteSync(); } catch (_) {}
        }
        if (stateFile.existsSync()) {
          try { stateFile.deleteSync(); } catch (_) {}
        }
      }
    }
  }

  /// Pauses an active download, preserving downloaded segments for later resumption
  void pauseDownload(String taskId) {
    _pausedTasks.add(taskId);
    if (_activeFfmpegProcesses.containsKey(taskId)) {
      _activeFfmpegProcesses[taskId]?.kill();
      _activeFfmpegProcesses.remove(taskId);
    }
    if (_activeDioTokens.containsKey(taskId)) {
      _activeDioTokens[taskId]?.cancel('Paused by user');
      _activeDioTokens.remove(taskId);
    }
  }

  /// Cancels an in-progress download task and removes temporary files
  void cancelDownload(String taskId) {
    _pausedTasks.remove(taskId);
    if (_activeFfmpegProcesses.containsKey(taskId)) {
      _activeFfmpegProcesses[taskId]?.kill();
      _activeFfmpegProcesses.remove(taskId);
    }
    if (_activeDioTokens.containsKey(taskId)) {
      _activeDioTokens[taskId]?.cancel('Cancelled by user');
      _activeDioTokens.remove(taskId);
    }
  }
}
