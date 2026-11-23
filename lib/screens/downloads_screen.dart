import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/anime.dart';
import '../models/download_task.dart';
import '../models/episode.dart';
import '../models/video_source.dart';
import '../providers/download_provider.dart';
import '../providers/player_provider.dart';
import '../services/download/download_service.dart';
import '../theme/app_theme.dart';
import 'player_screen.dart';

/// Screen listing all downloaded anime videos tracked directly via the ani_mobile storage folder
class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  void _playOfflineFile(
    BuildContext context,
    WidgetRef ref,
    DiskVideoFile diskFile,
  ) async {
    final offlineSource = VideoSource(
      url: diskFile.file.path,
      quality: 'Offline (${diskFile.formattedSize})',
      isHls: false,
      serverName: 'Local Storage',
    );

    final anime = Anime(
      id: diskFile.animeTitle.toLowerCase().replaceAll(' ', '-'),
      title: diskFile.animeTitle,
      coverImage: '',
      synopsis: 'Offline downloaded episode from device storage.',
    );

    final episode = Episode(
      id: diskFile.file.path,
      animeId: anime.id,
      number: diskFile.episodeNumber,
      title: 'Episode ${diskFile.episodeNumber}',
      isDub: diskFile.isDub,
      isSub: !diskFile.isDub,
    );

    ref.read(playerProvider.notifier).setupOfflineEpisode(
          anime: anime,
          episode: episode,
          playlist: [episode],
          source: offlineSource,
        );

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const PlayerScreen(),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    DiskVideoFile diskFile,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Download'),
        content: Text(
          'Are you sure you want to delete ${diskFile.animeTitle} Episode ${diskFile.episodeNumber} (${diskFile.formattedSize}) from device storage?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(downloadProvider.notifier).deleteDiskFile(diskFile);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Video file deleted.')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final downloadState = ref.watch(downloadProvider);
    final inProgressTasks = downloadState.tasks.values
        .where((t) => t.isDownloading || t.isPaused || t.status == DownloadStatus.queued)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloaded Anime'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Rescan Download Folder',
            onPressed: () {
              ref.read(downloadProvider.notifier).rescanDiskFiles();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(downloadProvider.notifier).rescanDiskFiles();
        },
        color: isDark ? AppTheme.accentCyan : AppTheme.primaryPurple,
        backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Active & Paused In-Progress Downloads Section
            if (inProgressTasks.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.downloading_rounded,
                        color: isDark ? AppTheme.accentCyan : AppTheme.primaryPurple,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Downloading & In-Progress (${inProgressTasks.length})',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.accentCyan : AppTheme.primaryPurple,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final task = inProgressTasks[index];
                    final isPaused = task.isPaused;
                    final isDling = task.isDownloading;

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurfaceVariant : AppTheme.lightSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isPaused
                              ? (isDark ? Colors.amberAccent.withOpacity(0.4) : Colors.amber.shade700)
                              : (isDark ? AppTheme.accentCyan.withOpacity(0.3) : AppTheme.primaryPurple.withOpacity(0.3)),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isDark ? Colors.black26 : Colors.black.withOpacity(0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title & Status Badge
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${task.anime.title} - Episode ${task.episode.number}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14.5,
                                    color: isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isPaused
                                      ? Colors.amber.withOpacity(0.15)
                                      : (isDark ? AppTheme.accentCyan.withOpacity(0.15) : AppTheme.primaryPurple.withOpacity(0.1)),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isPaused ? Colors.amberAccent : (isDark ? AppTheme.accentCyan : AppTheme.primaryPurple),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  isPaused ? 'PAUSED' : (isDling ? 'DOWNLOADING' : 'QUEUED'),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isPaused ? Colors.amberAccent : (isDark ? AppTheme.accentCyan : AppTheme.primaryPurple),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Progress Bar
                          LinearProgressIndicator(
                            value: task.progress > 0 ? task.progress : null,
                            color: isPaused ? Colors.amberAccent : (isDark ? AppTheme.accentCyan : AppTheme.primaryPurple),
                            backgroundColor: isDark ? Colors.white12 : Colors.black12,
                          ),
                          const SizedBox(height: 8),

                          // Subtitle & Size
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${task.episode.isDub ? "English Dub" : "Japanese Sub"} • ${task.source.quality}'
                                '${task.downloadedBytes > 0 ? " • ${(task.downloadedBytes / (1024 * 1024)).toStringAsFixed(1)} MB" : ""}',
                                style: TextStyle(
                                  color: isDark ? AppTheme.textMuted : AppTheme.lightTextMuted,
                                  fontSize: 12,
                                ),
                              ),
                              if (task.progress > 0)
                                Text(
                                  '${(task.progress * 100).toInt()}%',
                                  style: TextStyle(
                                    color: isPaused
                                        ? (isDark ? Colors.amberAccent : Colors.amber.shade800)
                                        : (isDark ? AppTheme.accentCyan : AppTheme.primaryPurple),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Action Buttons in Next Line with Outline
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (isDling)
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.pause_rounded, size: 16),
                                  label: const Text('Pause', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.amber,
                                    side: const BorderSide(color: Colors.amber, width: 1.2),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    minimumSize: const Size(0, 32),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () {
                                    ref.read(downloadProvider.notifier).pauseDownload(task.episode.id);
                                  },
                                )
                              else if (isPaused)
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.play_arrow_rounded, size: 16),
                                  label: const Text('Resume', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: isDark ? Colors.greenAccent : Colors.green.shade700,
                                    side: BorderSide(
                                      color: isDark ? Colors.greenAccent : Colors.green.shade700,
                                      width: 1.2,
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    minimumSize: const Size(0, 32),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () {
                                    ref.read(downloadProvider.notifier).resumeDownload(task.episode.id);
                                  },
                                ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.close_rounded, size: 16),
                                label: const Text('Cancel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.redAccent,
                                  side: const BorderSide(color: Colors.redAccent, width: 1.2),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  minimumSize: const Size(0, 32),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () {
                                  ref.read(downloadProvider.notifier).cancelDownload(task.episode.id);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                  childCount: inProgressTasks.length,
                ),
              ),
              const SliverToBoxAdapter(child: Divider(height: 28)),
            ],

            // Disk Downloaded Videos List
            if (downloadState.diskFiles.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.download_done_rounded,
                        size: 72,
                        color: (isDark ? AppTheme.textMuted : AppTheme.lightTextMuted).withOpacity(0.4),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Downloaded Videos Found',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'Episodes you download will be saved to your device in the ani_mobile folder and will appear here for offline streaming.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark ? AppTheme.textMuted : AppTheme.lightTextMuted,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Downloaded Files (${downloadState.diskFiles.length})',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
                        ),
                      ),
                      FutureBuilder<Directory>(
                        future: ref.read(downloadServiceProvider).getAniDownloadDirectory(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox.shrink();
                          return Tooltip(
                            message: snapshot.data!.path,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.folder_outlined,
                                  size: 14,
                                  color: isDark ? AppTheme.textMuted : AppTheme.lightTextMuted,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'ani_mobile',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppTheme.textMuted : AppTheme.lightTextMuted,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final diskFile = downloadState.diskFiles[index];
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                      child: Material(
                        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isDark ? const Color(0xFF222638) : const Color(0xFFE2E5EE),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.darkSurfaceVariant : AppTheme.lightSurfaceVariant,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.video_file_rounded,
                                color: isDark ? AppTheme.accentCyan : AppTheme.primaryPurple,
                                size: 26,
                              ),
                            ),
                          ),
                          title: Text(
                            diskFile.animeTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14.5,
                              color: isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
                            ),
                          ),
                          subtitle: Row(
                            children: [
                              Text(
                                'Episode ${diskFile.episodeNumber}',
                                style: const TextStyle(
                                  color: AppTheme.primaryPurpleLight,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '• ${diskFile.isDub ? "DUB" : "SUB"}',
                                style: TextStyle(
                                  color: isDark ? AppTheme.textMuted : AppTheme.lightTextMuted,
                                  fontSize: 11.5,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '• ${diskFile.formattedSize}',
                                style: TextStyle(
                                  color: isDark ? AppTheme.textMuted : AppTheme.lightTextMuted,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.play_circle_fill_rounded,
                                  color: isDark ? AppTheme.accentCyan : AppTheme.primaryPurple,
                                  size: 32,
                                ),
                                tooltip: 'Play Offline',
                                onPressed: () {
                                  _playOfflineFile(context, ref, diskFile);
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.redAccent,
                                  size: 22,
                                ),
                                tooltip: 'Delete File',
                                onPressed: () {
                                  _confirmDelete(context, ref, diskFile);
                                },
                              ),
                            ],
                          ),
                          onTap: () {
                            _playOfflineFile(context, ref, diskFile);
                          },
                        ),
                      ),
                    );
                  },
                  childCount: downloadState.diskFiles.length,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ],
        ),
      ),
    );
  }
}
