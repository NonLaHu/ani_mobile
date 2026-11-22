import 'package:flutter/material.dart';
import '../models/video_source.dart';
import '../theme/app_theme.dart';

/// Bottom modal sheet for picking streaming video quality and server
class QualitySelectorSheet extends StatelessWidget {
  final List<VideoSource> sources;
  final VideoSource? currentSource;
  final ValueChanged<VideoSource> onSourceSelected;

  const QualitySelectorSheet({
    super.key,
    required this.sources,
    required this.currentSource,
    required this.onSourceSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required List<VideoSource> sources,
    required VideoSource? currentSource,
    required ValueChanged<VideoSource> onSourceSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => QualitySelectorSheet(
        sources: sources,
        currentSource: currentSource,
        onSourceSelected: onSourceSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.tune_rounded,
                    color: AppTheme.accentCyan,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Select Quality & Server',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(),

            // Source list
            if (sources.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'No alternative video sources found',
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sources.length,
                itemBuilder: (context, index) {
                  final source = sources[index];
                  final isSelected = currentSource?.url == source.url;

                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryPurple.withOpacity(0.2)
                            : AppTheme.darkSurfaceVariant,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        source.isHls ? Icons.stream_rounded : Icons.hd_rounded,
                        color: isSelected
                            ? AppTheme.primaryPurpleLight
                            : AppTheme.textMuted,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      source.quality,
                      style: TextStyle(
                        color: isSelected
                            ? AppTheme.primaryPurpleLight
                            : AppTheme.textPrimary,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                    subtitle: Text(
                      '${source.serverName} • ${source.isHls ? "HLS (.m3u8)" : "MP4 Direct"}${source.isBackup ? " [Backup]" : ""}',
                      style: TextStyle(
                        color: isSelected
                            ? AppTheme.accentCyan.withOpacity(0.8)
                            : AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: AppTheme.accentCyan,
                            size: 22,
                          )
                        : null,
                    onTap: () {
                      Navigator.of(context).pop();
                      onSourceSelected(source);
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
