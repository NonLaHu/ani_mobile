import 'dart:ffi';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

enum UpdateDownloadStatus {
  idle,
  downloading,
  completed,
  failed,
}

/// State tracking an in-app APK update download and local installation.
class AppUpdateDownloadState {
  final UpdateDownloadStatus status;
  final double progress; // 0.0 to 1.0
  final int downloadedBytes;
  final int totalBytes;
  final String? apkPath;
  final String? version;
  final String? fileName;
  final String? errorMessage;

  const AppUpdateDownloadState({
    this.status = UpdateDownloadStatus.idle,
    this.progress = 0.0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.apkPath,
    this.version,
    this.fileName,
    this.errorMessage,
  });

  bool get isDownloading => status == UpdateDownloadStatus.downloading;
  bool get isCompleted => status == UpdateDownloadStatus.completed;
  bool get isFailed => status == UpdateDownloadStatus.failed;

  String get formattedProgress => '${(progress * 100).toInt()}%';

  String get formattedDownloadedSize {
    if (totalBytes > 0) {
      final dlMb = (downloadedBytes / (1024 * 1024)).toStringAsFixed(1);
      final totMb = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
      return '$dlMb MB / $totMb MB';
    }
    if (downloadedBytes > 0) {
      return '${(downloadedBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '';
  }

  AppUpdateDownloadState copyWith({
    UpdateDownloadStatus? status,
    double? progress,
    int? downloadedBytes,
    int? totalBytes,
    String? apkPath,
    String? version,
    String? fileName,
    String? errorMessage,
  }) {
    return AppUpdateDownloadState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      apkPath: apkPath ?? this.apkPath,
      version: version ?? this.version,
      fileName: fileName ?? this.fileName,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Service that resolves compatible APK binaries for the current device architecture,
/// downloads them with progress tracking, and invokes the Android Package Installer.
class AppUpdateDownloadService {
  final Dio _dio;
  CancelToken? _cancelToken;

  AppUpdateDownloadService({Dio? customDio}) : _dio = customDio ?? Dio();

  /// Detects the target device architecture and resolves the most compatible APK file name.
  static String getCompatibleApkFileName(String version) {
    final cleanVer = version.replaceAll('v', '').trim();
    if (!Platform.isAndroid) {
      return 'ani_mobile-v$cleanVer.apk';
    }

    try {
      final abi = Abi.current();
      switch (abi) {
        case Abi.androidArm64:
          return 'app-arm64-v8a-release.apk';
        case Abi.androidArm:
          return 'app-armeabi-v7a-release.apk';
        case Abi.androidX64:
          return 'app-x86_64-release.apk';
        default:
          return 'ani_mobile-v$cleanVer.apk';
      }
    } catch (_) {
      return 'ani_mobile-v$cleanVer.apk';
    }
  }

  /// Builds the direct download URL for the target binary from GitHub Releases.
  static String getDownloadUrl({
    required String repo,
    required String version,
    String? fileName,
  }) {
    final cleanVer = version.replaceAll('v', '').trim();
    final name = fileName ?? getCompatibleApkFileName(cleanVer);
    return 'https://github.com/$repo/releases/download/v$cleanVer/$name';
  }

  /// Returns the persistent directory where update APKs are stored.
  Future<Directory> getUpdateStorageDirectory() async {
    Directory? baseDir;
    if (Platform.isAndroid) {
      final publicDownload = Directory('/storage/emulated/0/Download/ani_mobile/updates');
      try {
        if (!publicDownload.existsSync()) {
          publicDownload.createSync(recursive: true);
        }
        return publicDownload;
      } catch (_) {}
    }

    baseDir ??= await getApplicationDocumentsDirectory();
    final updateDir = Directory('${baseDir.path}/ani_mobile/updates');
    if (!updateDir.existsSync()) {
      updateDir.createSync(recursive: true);
    }
    return updateDir;
  }

  /// Downloads the specified APK file while reporting real-time byte progress.
  Future<String> downloadApk({
    required String downloadUrl,
    required String fileName,
    required void Function(int received, int total) onProgress,
  }) async {
    final targetDir = await getUpdateStorageDirectory();
    final targetPath = '${targetDir.path}/$fileName';
    final targetFile = File(targetPath);

    // If already downloaded and valid, return immediately
    if (targetFile.existsSync() && targetFile.lengthSync() > 1024 * 1024) {
      onProgress(targetFile.lengthSync(), targetFile.lengthSync());
      return targetPath;
    }

    _cancelToken = CancelToken();

    try {
      await _dio.download(
        downloadUrl,
        targetPath,
        cancelToken: _cancelToken,
        onReceiveProgress: onProgress,
        deleteOnError: true,
      );
      return targetPath;
    } catch (e) {
      if (CancelToken.isCancel(e as DioException)) {
        rethrow;
      }
      // If ABI-specific APK fails with 404, attempt fallback to universal APK
      if (e.response?.statusCode == 404 && !fileName.startsWith('ani_mobile')) {
        final universalName = 'ani_mobile-v${downloadUrl.split('/').reversed.elementAt(1).replaceAll('v', '')}.apk';
        final universalUrl = downloadUrl.substring(0, downloadUrl.lastIndexOf('/') + 1) + universalName;
        final universalPath = '${targetDir.path}/$universalName';

        await _dio.download(
          universalUrl,
          universalPath,
          cancelToken: _cancelToken,
          onReceiveProgress: onProgress,
          deleteOnError: true,
        );
        return universalPath;
      }
      rethrow;
    }
  }

  /// Cancels an in-progress download
  void cancelDownload() {
    _cancelToken?.cancel('Cancelled by user');
  }

  /// Launches the Android Package Installer using open_filex.
  Future<OpenResult> installApk(String apkPath) async {
    final file = File(apkPath);
    if (!file.existsSync()) {
      return OpenResult(
        type: ResultType.fileNotFound,
        message: 'APK file not found on disk at $apkPath',
      );
    }

    return await OpenFilex.open(
      apkPath,
      type: 'application/vnd.android.package-archive',
    );
  }
}
