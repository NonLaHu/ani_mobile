/// Model containing application version and update check information.
class AppUpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final bool hasUpdate;
  final String releaseTitle;
  final String releaseNotes;
  final String? downloadUrl;
  final DateTime? publishedAt;

  const AppUpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.hasUpdate,
    required this.releaseTitle,
    required this.releaseNotes,
    this.downloadUrl,
    this.publishedAt,
  });

  Map<String, dynamic> toJson() => {
        'currentVersion': currentVersion,
        'latestVersion': latestVersion,
        'hasUpdate': hasUpdate,
        'releaseTitle': releaseTitle,
        'releaseNotes': releaseNotes,
        'downloadUrl': downloadUrl,
        'publishedAt': publishedAt?.toIso8601String(),
      };

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      currentVersion: json['currentVersion'] as String? ?? '1.0.0',
      latestVersion: json['latestVersion'] as String? ?? '1.0.0',
      hasUpdate: json['hasUpdate'] as bool? ?? false,
      releaseTitle: json['releaseTitle'] as String? ?? '',
      releaseNotes: json['releaseNotes'] as String? ?? '',
      downloadUrl: json['downloadUrl'] as String?,
      publishedAt: json['publishedAt'] != null
          ? DateTime.tryParse(json['publishedAt'] as String)
          : null,
    );
  }
}
