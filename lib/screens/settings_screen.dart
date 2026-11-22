import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/download_provider.dart';
import '../providers/scraper_provider.dart';
import '../providers/theme_provider.dart';
import '../services/scraper/scraper_factory.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String? _currentDownloadPath;
  bool _isLoadingPath = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentPath();
  }

  Future<void> _loadCurrentPath() async {
    setState(() => _isLoadingPath = true);
    final dir = await ref.read(downloadServiceProvider).getAniDownloadDirectory();
    if (mounted) {
      setState(() {
        _currentDownloadPath = dir.path;
        _isLoadingPath = false;
      });
    }
  }

  void _showChangePathDialog() {
    final controller = TextEditingController(text: _currentDownloadPath);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Custom Download Path'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the absolute directory path where downloaded videos should be saved:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: '/path/to/download/folder',
                prefixIcon: Icon(Icons.folder_open_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newPath = controller.text.trim();
              if (newPath.isNotEmpty) {
                await ref.read(downloadServiceProvider).setCustomDownloadPath(newPath);
                await ref.read(downloadProvider.notifier).rescanDiskFiles();
                await _loadCurrentPath();
              }
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetDownloadPath() async {
    await ref.read(downloadServiceProvider).setCustomDownloadPath(null);
    await ref.read(downloadProvider.notifier).rescanDiskFiles();
    await _loadCurrentPath();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download folder reset to default.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final currentScraper = ref.watch(scraperTypeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Section: Appearance
          _buildSectionHeader(
            icon: Icons.palette_outlined,
            title: 'Appearance',
            color: AppTheme.primaryPurple,
          ),
          Card(
            margin: const EdgeInsets.only(top: 8, bottom: 20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Theme Mode',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Choose between Light, Dark, or System default theme.',
                    style: TextStyle(
                      color: isDark ? AppTheme.textMuted : AppTheme.lightTextMuted,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode_rounded, size: 18),
                        label: Text('Dark'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode_rounded, size: 18),
                        label: Text('Light'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto_rounded, size: 18),
                        label: Text('System'),
                      ),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (selected) {
                      ref.read(themeModeProvider.notifier).setThemeMode(selected.first);
                    },
                  ),
                ],
              ),
            ),
          ),

          // Section: Downloads
          _buildSectionHeader(
            icon: Icons.download_rounded,
            title: 'Downloads & Storage',
            color: AppTheme.accentCyan,
          ),
          Card(
            margin: const EdgeInsets.only(top: 8, bottom: 20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Download Storage Folder',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Offline video files are saved and scanned from this directory:',
                    style: TextStyle(
                      color: isDark ? AppTheme.textMuted : AppTheme.lightTextMuted,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                      ),
                    ),
                    child: _isLoadingPath
                        ? const Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : SelectableText(
                            _currentDownloadPath ?? 'Loading...',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12.5,
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.edit_rounded, size: 16),
                        label: const Text('Change Path'),
                        onPressed: _showChangePathDialog,
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.restart_alt_rounded, size: 16),
                        label: const Text('Reset Default'),
                        onPressed: _resetDownloadPath,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Section: Scraper Engine
          _buildSectionHeader(
            icon: Icons.hub_rounded,
            title: 'Anime Source & Scraper Engine',
            color: AppTheme.accentCoral,
          ),
          Card(
            margin: const EdgeInsets.only(top: 8, bottom: 20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Active Provider',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Select which anime provider backend is used for searching and streaming:',
                    style: TextStyle(
                      color: isDark ? AppTheme.textMuted : AppTheme.lightTextMuted,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  RadioListTile<ScraperType>(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('ani-mobile Engine (HiAnime / ZokoAnime)'),
                    subtitle: const Text('Mirrors ani-mobile shell scraper with full sub/dub streaming.'),
                    value: ScraperType.hianime,
                    groupValue: currentScraper,
                    onChanged: (val) {
                      if (val != null) ref.read(scraperTypeProvider.notifier).state = val;
                    },
                  ),
                  RadioListTile<ScraperType>(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Live Provider (Gogo/AllAnime)'),
                    subtitle: const Text('Secondary public live scraper fallback.'),
                    value: ScraperType.live,
                    groupValue: currentScraper,
                    onChanged: (val) {
                      if (val != null) ref.read(scraperTypeProvider.notifier).state = val;
                    },
                  ),
                  RadioListTile<ScraperType>(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Demo Scraper (Guaranteed Test Streams)'),
                    subtitle: const Text('Provides reliable public test streams for testing player and downloads.'),
                    value: ScraperType.demo,
                    groupValue: currentScraper,
                    onChanged: (val) {
                      if (val != null) ref.read(scraperTypeProvider.notifier).state = val;
                    },
                  ),
                ],
              ),
            ),
          ),

          // Section: About
          _buildSectionHeader(
            icon: Icons.info_outline_rounded,
            title: 'About',
            color: AppTheme.primaryPurpleLight,
          ),
          Card(
            margin: const EdgeInsets.only(top: 8, bottom: 24),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryPurple,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.terminal_rounded,
                          size: 28,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ani-mobile',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            'Version 1.0.0 (Release)',
                            style: TextStyle(
                              color: isDark ? AppTheme.textMuted : AppTheme.lightTextMuted,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(),
                  const SizedBox(height: 10),
                  Text(
                    'ani-mobile is a cross-platform anime streaming and offline download application inspired by the legendary ani-mobile shell tool. Powered by Flutter, media_kit (libmpv), Dio, and Riverpod.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildPill('libmpv Video Engine'),
                      _buildPill('Hardware Acceleration'),
                      _buildPill('FFmpeg Remuxing'),
                      _buildPill('Pure Dart HLS Fallback'),
                      _buildPill('Dual Sub/Dub'),
                      _buildPill('Offline Player'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.4),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }
}
