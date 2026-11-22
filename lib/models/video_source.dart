/// Video source model representing a streamable URL, quality tier, and required HTTP headers.
class VideoSource {
  final String url;
  final String quality; // '1080p', '720p', '480p', '360p', 'Auto', etc.
  final Map<String, String> headers; // Crucial for video CDNs requiring Referer/User-Agent
  final bool isHls; // true if stream is .m3u8 HLS playlist
  final String serverName; // e.g., 'Vidstreaming', 'MegaCloud', 'StreamSB'
  final bool isBackup;

  const VideoSource({
    required this.url,
    required this.quality,
    this.headers = const {},
    this.isHls = false,
    this.serverName = 'Default',
    this.isBackup = false,
  });

  Map<String, dynamic> toJson() => {
    'url': url,
    'quality': quality,
    'headers': headers,
    'isHls': isHls,
    'serverName': serverName,
    'isBackup': isBackup,
  };

  factory VideoSource.fromJson(Map<String, dynamic> json) => VideoSource(
    url: json['url'] as String,
    quality: json['quality'] as String? ?? 'Auto',
    headers: (json['headers'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, v.toString()),
        ) ??
        const {},
    isHls: json['isHls'] as bool? ?? false,
    serverName: json['serverName'] as String? ?? 'Default',
    isBackup: json['isBackup'] as bool? ?? false,
  );

  VideoSource copyWith({
    String? url,
    String? quality,
    Map<String, String>? headers,
    bool? isHls,
    String? serverName,
    bool? isBackup,
  }) {
    return VideoSource(
      url: url ?? this.url,
      quality: quality ?? this.quality,
      headers: headers ?? this.headers,
      isHls: isHls ?? this.isHls,
      serverName: serverName ?? this.serverName,
      isBackup: isBackup ?? this.isBackup,
    );
  }

  @override
  String toString() =>
      'VideoSource($quality via $serverName, HLS: $isHls, url: $url)';
}

/// Subtitle track representation for soft-subbed media
class SubtitleTrack {
  final String url;
  final String language;
  final String label;

  const SubtitleTrack({
    required this.url,
    required this.language,
    required this.label,
  });

  Map<String, dynamic> toJson() => {
    'url': url,
    'language': language,
    'label': label,
  };

  factory SubtitleTrack.fromJson(Map<String, dynamic> json) => SubtitleTrack(
    url: json['url'] as String,
    language: json['language'] as String? ?? 'en',
    label: json['label'] as String? ?? 'English',
  );
}

/// A bundle of stream sources, subtitle tracks, and timestamp metadata for an episode
class StreamBundle {
  final String episodeId;
  final String animeId;
  final int episodeNumber;
  final List<VideoSource> sources;
  final List<SubtitleTrack> subtitles;
  final int? introStart; // in seconds (for ani-mobile style skip intro)
  final int? introEnd; // in seconds
  final int? outroStart;
  final int? outroEnd;

  const StreamBundle({
    required this.episodeId,
    required this.animeId,
    required this.episodeNumber,
    required this.sources,
    this.subtitles = const [],
    this.introStart,
    this.introEnd,
    this.outroStart,
    this.outroEnd,
  });

  /// Finds the best source matching a requested quality (e.g. '1080p', '720p', 'Auto')
  VideoSource? getPreferredSource(String preferredQuality) {
    if (sources.isEmpty) return null;

    if (preferredQuality.toLowerCase() == 'auto') {
      final autoSource = sources.where((s) => s.quality.toLowerCase() == 'auto');
      if (autoSource.isNotEmpty) return autoSource.first;
      return sources.first;
    }

    final exact = sources.where(
      (s) => s.quality.toLowerCase() == preferredQuality.toLowerCase(),
    );
    if (exact.isNotEmpty) return exact.first;

    // Fallback to highest available quality
    return sources.first;
  }

  /// Get the fallback source if the current source fails to play
  VideoSource? getNextFallbackSource(VideoSource current) {
    if (sources.isEmpty) return null;
    final currentIndex = sources.indexOf(current);
    if (currentIndex >= 0 && currentIndex + 1 < sources.length) {
      return sources[currentIndex + 1];
    }
    // If not found in list or was last, return first non-identical source
    for (final s in sources) {
      if (s.url != current.url) return s;
    }
    return null;
  }
}
