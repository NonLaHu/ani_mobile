import 'anime.dart';
import 'episode.dart';
import 'video_source.dart';

enum DownloadStatus {
  queued,
  downloading,
  paused,
  completed,
  failed,
  cancelled,
}

/// Represents a persistent anime episode download job
class DownloadTask {
  final String id;
  final Anime anime;
  final Episode episode;
  final VideoSource source;
  final double progress; // 0.0 to 1.0
  final DownloadStatus status;
  final String? filePath;
  final int downloadedBytes;
  final int totalBytes;
  final String? errorMessage;
  final DateTime createdAt;

  const DownloadTask({
    required this.id,
    required this.anime,
    required this.episode,
    required this.source,
    this.progress = 0.0,
    this.status = DownloadStatus.queued,
    this.filePath,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.errorMessage,
    required this.createdAt,
  });

  bool get isCompleted => status == DownloadStatus.completed;
  bool get isDownloading => status == DownloadStatus.downloading;
  bool get isPaused => status == DownloadStatus.paused;
  bool get isFailed => status == DownloadStatus.failed;

  String get formattedProgress => '${(progress * 100).toStringAsFixed(0)}%';

  DownloadTask copyWith({
    String? id,
    Anime? anime,
    Episode? episode,
    VideoSource? source,
    double? progress,
    DownloadStatus? status,
    String? filePath,
    int? downloadedBytes,
    int? totalBytes,
    String? errorMessage,
    DateTime? createdAt,
  }) {
    return DownloadTask(
      id: id ?? this.id,
      anime: anime ?? this.anime,
      episode: episode ?? this.episode,
      source: source ?? this.source,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      filePath: filePath ?? this.filePath,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'anime': anime.toJson(),
      'episode': episode.toJson(),
      'source': source.toJson(),
      'progress': progress,
      'status': status.name,
      'filePath': filePath,
      'downloadedBytes': downloadedBytes,
      'totalBytes': totalBytes,
      'errorMessage': errorMessage,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    return DownloadTask(
      id: json['id'] as String,
      anime: Anime.fromJson(json['anime'] as Map<String, dynamic>),
      episode: Episode.fromJson(json['episode'] as Map<String, dynamic>),
      source: VideoSource.fromJson(json['source'] as Map<String, dynamic>),
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      status: DownloadStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => DownloadStatus.failed,
      ),
      filePath: json['filePath'] as String?,
      downloadedBytes: (json['downloadedBytes'] as num?)?.toInt() ?? 0,
      totalBytes: (json['totalBytes'] as num?)?.toInt() ?? 0,
      errorMessage: json['errorMessage'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
