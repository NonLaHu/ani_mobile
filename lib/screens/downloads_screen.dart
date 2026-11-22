import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/anime.dart';
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
        backgroundColor: AppTheme.darkSurface,
        title: const Text('Delete Download'),
        content: Text(
          'Are you sure you want to delete ${diskFile.animeTitle} Episode ${diskFile.episodeNumber} (${diskFile.formattedSize}) from device storage?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadState = ref.watch(downloadProvider);
    final activeTasks = downloadState.tasks.values
        .where((t) => t.isDownloading)
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
        color: AppTheme.primaryPurple,
        backgroundColor: AppTheme.darkSurface,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Active In-Progress Downloads Section
            if (activeTasks.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.downloading_rounded, color: AppTheme.accentCyan, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Active Downloads (${activeTasks.length})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accentCyan,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final task = activeTasks[index];
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.darkSurfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.accentCyan.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${task.anime.title} - Episode ${task.episode.number}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14.5,
                                  ),
                                ),
                              ),
                              Text(
                                task.formattedProgress,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.accentCyan,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          LinearProgressIndicator(
                            value: task.progress > 0 ? task.progress : null,
                            color: AppTheme.accentCyan,
                            backgroundColor: Colors.white12,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${task.episode.isDub ? "English Dub" : "Japanese Sub"} • ${task.source.quality}',
                                style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.close, size: 16, color: Colors.redAccent),
                                label: const Text('Cancel', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
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
                  childCount: activeTasks.length,
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
                        color: AppTheme.textMuted.withOpacity(0.4),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No Downloaded Videos Found',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'Episodes you download will be saved to your device in the ani_mobile folder and will appear here for offline streaming.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
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
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      FutureBuilder<Directory>(
                        future: ref.read(downloadServiceProvider).getAniDownloadDirectory(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox.shrink();
                          return Tooltip(
                            message: snapshot.data!.path,
                            child: const Row(
                              children: [
                                Icon(Icons.folder_outlined, size: 14, color: AppTheme.textMuted),
                                SizedBox(width: 4),
                                Text(
                                  'ani_mobile',
                                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
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
                        color: AppTheme.darkSurface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFF222638)),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppTheme.darkSurfaceVariant,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.video_file_rounded,
                                color: AppTheme.accentCyan,
                                size: 26,
                              ),
                            ),
                          ),
                          title: Text(
                            diskFile.animeTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14.5,
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
                                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11.5),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '• ${diskFile.formattedSize}',
                                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11.5),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.play_circle_fill_rounded,
                                  color: AppTheme.accentCyan,
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
