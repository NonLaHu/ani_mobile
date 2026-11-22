import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/anime.dart';
import '../models/download_task.dart';
import '../models/episode.dart';
import '../models/video_source.dart';
import '../services/download/download_service.dart';
import '../services/notification/notification_service.dart';
import 'scraper_provider.dart';

final downloadServiceProvider = Provider<DownloadService>((ref) {
  return DownloadService();
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// Combined state holding both live active download tasks and physical files detected on disk
class DownloadState {
  final Map<String, DownloadTask> tasks;
  final List<DiskVideoFile> diskFiles;
  final bool isScanning;

  const DownloadState({
    this.tasks = const {},
    this.diskFiles = const [],
    this.isScanning = false,
  });

  int get activeDownloadCount =>
      tasks.values.where((t) => t.isDownloading).length;

  DownloadTask? getTask(String episodeId) => tasks[episodeId];

  DownloadTask? operator [](String episodeId) => tasks[episodeId];

  bool isDownloaded(String episodeId) {
    final task = tasks[episodeId];
    if (task != null && task.isCompleted && task.filePath != null && File(task.filePath!).existsSync()) {
      return true;
    }
    // Check disk files
    return diskFiles.any((df) => df.file.path.contains(episodeId));
  }

  bool isDownloading(String episodeId) {
    final task = tasks[episodeId];
    return task != null && task.isDownloading;
  }

  DownloadState copyWith({
    Map<String, DownloadTask>? tasks,
    List<DiskVideoFile>? diskFiles,
    bool? isScanning,
  }) {
    return DownloadState(
      tasks: tasks ?? this.tasks,
      diskFiles: diskFiles ?? this.diskFiles,
      isScanning: isScanning ?? this.isScanning,
    );
  }
}

class DownloadNotifier extends StateNotifier<DownloadState> {
  final Ref ref;
  static const String _storageKey = 'ani_mobile_downloads_v1';
  DateTime _lastNotifTime = DateTime.fromMillisecondsSinceEpoch(0);

  DownloadNotifier(this.ref) : super(const DownloadState()) {
    _init();
  }

  Future<void> _init() async {
    await _loadFromStorage();
    await rescanDiskFiles();
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final map = <String, DownloadTask>{};
        for (final entry in decoded.entries) {
          final task = DownloadTask.fromJson(entry.value as Map<String, dynamic>);
          if (task.isCompleted && task.filePath != null && File(task.filePath!).existsSync()) {
            map[entry.key] = task;
          }
        }
        state = state.copyWith(tasks: map);
      }
    } catch (e) {
      print('Error loading downloads from storage: $e');
    }
  }

  Future<void> _persistToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final completedMap = <String, dynamic>{};
      for (final entry in state.tasks.entries) {
        if (entry.value.isCompleted) {
          completedMap[entry.key] = entry.value.toJson();
        }
      }
      await prefs.setString(_storageKey, jsonEncode(completedMap));
    } catch (e) {
      print('Error saving downloads to storage: $e');
    }
  }

  /// Scans the physical download folder on disk for all video files
  Future<void> rescanDiskFiles() async {
    state = state.copyWith(isScanning: true);
    try {
      final service = ref.read(downloadServiceProvider);
      final files = await service.scanDownloadedFiles();
      state = state.copyWith(diskFiles: files, isScanning: false);
    } catch (e) {
      print('Rescan disk files error: $e');
      state = state.copyWith(isScanning: false);
    }
  }

  DownloadTask? getTask(String episodeId) => state.getTask(episodeId);

  bool isDownloaded(String episodeId) => state.isDownloaded(episodeId);

  bool isDownloading(String episodeId) => state.isDownloading(episodeId);

  /// Starts downloading an episode stream
  Future<void> startDownload({
    required Anime anime,
    required Episode episode,
    VideoSource? preselectedSource,
  }) async {
    final episodeId = episode.id;
    if (isDownloading(episodeId)) return;

    final downloadService = ref.read(downloadServiceProvider);
    final notifService = ref.read(notificationServiceProvider);

    // Request permissions only when user initiates a download
    final hasPermission = await downloadService.requestDownloadPermission();
    if (!hasPermission) {
      print('Download storage permission was denied.');
      return;
    }

    try {
      // Step 1: Resolve stream source if not provided
      VideoSource source = preselectedSource ??
          const VideoSource(
            url: '',
            quality: 'Auto',
          );
      String? subtitleUrl;

      if (source.url.isEmpty) {
        final scraper = ref.read(scraperServiceProvider);
        final bundle = await scraper.getStreamSources(episode.id, dub: episode.isDub);
        if (bundle.sources.isEmpty) {
          throw Exception('No stream sources found for download');
        }
        source = bundle.getPreferredSource('1080p') ?? bundle.sources.first;
        if (bundle.subtitles.isNotEmpty) {
          subtitleUrl = bundle.subtitles.first.url;
        }
      }

      final task = DownloadTask(
        id: '${anime.id}_${episode.id}',
        anime: anime,
        episode: episode,
        source: source,
        status: DownloadStatus.downloading,
        progress: 0.0,
        createdAt: DateTime.now(),
      );

      state = state.copyWith(tasks: {...state.tasks, episodeId: task});

      // Notification tracking ID based on hash
      final notifId = episode.id.hashCode.abs() % 100000;

      // Show initial notification
      notifService.showDownloadProgress(
        id: notifId,
        title: 'Downloading ${anime.title}',
        body: 'Episode ${episode.number} (${episode.isDub ? "Dub" : "Sub"}) - 0%',
        progressPercent: 0,
      );

      final downloadedFile = await downloadService.downloadEpisode(
        anime: anime,
        episode: episode,
        source: source,
        subtitleUrl: subtitleUrl,
        onProgress: (progress, downloadedBytes, totalBytes) {
          final current = state.tasks[episodeId];
          if (current != null && current.status == DownloadStatus.downloading) {
            state = state.copyWith(
              tasks: {
                ...state.tasks,
                episodeId: current.copyWith(
                  progress: progress,
                  downloadedBytes: downloadedBytes,
                  totalBytes: totalBytes,
                ),
              },
            );

            // Throttle notifications to avoid flooding Android UI
            final now = DateTime.now();
            if (now.difference(_lastNotifTime).inSeconds >= 2) {
              _lastNotifTime = now;
              notifService.showDownloadProgress(
                id: notifId,
                title: 'Downloading ${anime.title}',
                body: 'Episode ${episode.number}: ${(progress * 100).toInt()}%',
                progressPercent: (progress * 100).toInt(),
              );
            }
          }
        },
      );

      final completedTask = task.copyWith(
        status: DownloadStatus.completed,
        progress: 1.0,
        filePath: downloadedFile.path,
        downloadedBytes: downloadedFile.lengthSync(),
        totalBytes: downloadedFile.lengthSync(),
      );

      state = state.copyWith(
        tasks: {...state.tasks, episodeId: completedTask},
      );
      await _persistToStorage();
      await rescanDiskFiles();

      // Show completion notification
      notifService.showDownloadCompleted(
        id: notifId,
        title: 'Download Complete!',
        body: '${anime.title} Episode ${episode.number} is ready for offline playback.',
      );
    } catch (e) {
      print('Download error for episode $episodeId: $e');
      final current = state.tasks[episodeId];
      if (current != null) {
        state = state.copyWith(
          tasks: {
            ...state.tasks,
            episodeId: current.copyWith(
              status: DownloadStatus.failed,
              errorMessage: e.toString(),
            ),
          },
        );
      }
    }
  }

  /// Cancels an in-flight download
  void cancelDownload(String episodeId) {
    final current = state.tasks[episodeId];
    if (current == null) return;

    ref.read(downloadServiceProvider).cancelDownload(current.id);
    ref.read(notificationServiceProvider).cancel(episodeId.hashCode.abs() % 100000);

    state = state.copyWith(
      tasks: {
        ...state.tasks,
        episodeId: current.copyWith(status: DownloadStatus.cancelled),
      },
    );
  }

  /// Deletes a downloaded video file from disk
  Future<void> deleteDownload(String episodeId) async {
    final current = state.tasks[episodeId];
    if (current != null && current.filePath != null) {
      try {
        final f = File(current.filePath!);
        if (f.existsSync()) f.deleteSync();
        final vtt = File('${current.filePath!.replaceAll('.mp4', '')}.vtt');
        if (vtt.existsSync()) vtt.deleteSync();
      } catch (e) {
        print('Error deleting file: $e');
      }
    }

    final newTasks = Map<String, DownloadTask>.from(state.tasks)..remove(episodeId);
    state = state.copyWith(tasks: newTasks);
    await _persistToStorage();
    await rescanDiskFiles();
  }

  /// Deletes a file directly identified from disk scan
  Future<void> deleteDiskFile(DiskVideoFile diskFile) async {
    try {
      if (diskFile.file.existsSync()) {
        diskFile.file.deleteSync();
      }
      final vtt = File('${diskFile.file.path.replaceAll('.mp4', '')}.vtt');
      if (vtt.existsSync()) vtt.deleteSync();
    } catch (e) {
      print('Error deleting disk file: $e');
    }
    await rescanDiskFiles();
  }
}

final downloadProvider =
    StateNotifierProvider<DownloadNotifier, DownloadState>((ref) {
  return DownloadNotifier(ref);
});
