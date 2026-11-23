import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import '../services/update/app_update_download_service.dart';
import '../services/update/update_service.dart';

final appUpdateDownloadServiceProvider = Provider<AppUpdateDownloadService>((ref) {
  return AppUpdateDownloadService();
});

class AppUpdateDownloadNotifier extends StateNotifier<AppUpdateDownloadState> {
  final AppUpdateDownloadService _service;

  AppUpdateDownloadNotifier(this._service) : super(const AppUpdateDownloadState());

  /// Starts in-app downloading of the compatible release APK.
  Future<void> startDownload({
    required String version,
    String? explicitUrl,
  }) async {
    final cleanVer = version.replaceAll('v', '').trim();
    final fileName = AppUpdateDownloadService.getCompatibleApkFileName(cleanVer);
    final downloadUrl = explicitUrl ??
        AppUpdateDownloadService.getDownloadUrl(
          repo: UpdateService.githubRepo,
          version: cleanVer,
          fileName: fileName,
        );

    state = state.copyWith(
      status: UpdateDownloadStatus.downloading,
      progress: 0.0,
      downloadedBytes: 0,
      totalBytes: 0,
      version: cleanVer,
      fileName: fileName,
      errorMessage: null,
    );

    try {
      final savedPath = await _service.downloadApk(
        downloadUrl: downloadUrl,
        fileName: fileName,
        onProgress: (received, total) {
          if (total > 0) {
            state = state.copyWith(
              progress: received / total,
              downloadedBytes: received,
              totalBytes: total,
            );
          }
        },
      );

      state = state.copyWith(
        status: UpdateDownloadStatus.completed,
        progress: 1.0,
        apkPath: savedPath,
      );
    } catch (e) {
      if (e.toString().contains('Cancelled')) {
        state = const AppUpdateDownloadState(status: UpdateDownloadStatus.idle);
      } else {
        state = state.copyWith(
          status: UpdateDownloadStatus.failed,
          errorMessage: e.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  /// Cancels any active download
  void cancelDownload() {
    _service.cancelDownload();
    state = const AppUpdateDownloadState(status: UpdateDownloadStatus.idle);
  }

  /// Launches the system package installer for the downloaded APK
  Future<OpenResult> installApk() async {
    if (state.apkPath == null) {
      return OpenResult(
        type: ResultType.fileNotFound,
        message: 'No downloaded APK available to install.',
      );
    }

    return await _service.installApk(state.apkPath!);
  }

  /// Resets state and dismisses current update banner
  void clear() {
    state = const AppUpdateDownloadState(status: UpdateDownloadStatus.idle);
  }
}

final appUpdateDownloadProvider =
    StateNotifierProvider<AppUpdateDownloadNotifier, AppUpdateDownloadState>((ref) {
  final service = ref.watch(appUpdateDownloadServiceProvider);
  return AppUpdateDownloadNotifier(service);
});
