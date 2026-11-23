import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/download_provider.dart';
import '../providers/playback_settings_provider.dart';
import '../providers/scraper_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/update_provider.dart';
import '../services/scraper/scraper_factory.dart';
import '../services/update/update_service.dart';
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
    final hwAccel = ref.watch(hardwareAccelerationProvider);
    final subsEnabled = ref.watch(subtitlesEnabledProvider);
    final subFontSize = ref.watch(subtitleFontSizeProvider);
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

          // Section: Video Playback & Rendering
          _buildSectionHeader(
            icon: Icons.play_circle_outline_rounded,
            title: 'Video Playback & Rendering',
            color: AppTheme.accentGreen,
          ),
          Card(
            margin: const EdgeInsets.only(top: 8, bottom: 20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hardware Video Acceleration (H/W)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Disabled by default (S/W Software Rendering). Software rendering eliminates blue screens and OpenGL texture conflicts on Linux Impeller.',
                    style: TextStyle(
                      color: isDark ? AppTheme.textMuted : AppTheme.lightTextMuted,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      hwAccel ? 'Hardware Acceleration (H/W)' : 'Software Rendering (S/W)',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: Text(
                      hwAccel
                          ? 'Active: Uses GPU video textures (may render blue screen on some Linux GPUs)'
                          : 'Active: CPU/software pixel buffer decoding (stable, fixes blue screen)',
                      style: TextStyle(
                        fontSize: 12,
                        color: hwAccel ? Colors.amber : Colors.greenAccent,
                      ),
                    ),
                    value: hwAccel,
                    onChanged: (val) {
                      ref.read(playbackSettingsProvider.notifier).setHardwareAcceleration(val);
                    },
                  ),
                ],
              ),
            ),
          ),

          // Section: Subtitles & Captions
          _buildSectionHeader(
            icon: Icons.subtitles_rounded,
            title: 'Subtitles & Captions',
            color: AppTheme.accentCyan,
          ),
          Card(
            margin: const EdgeInsets.only(top: 8, bottom: 20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Enable Subtitles by Default',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                    ),
                    subtitle: Text(
                      subsEnabled
                          ? 'Subtitles automatically turn ON when opening video streams'
                          : 'Subtitles stay OFF until turned on manually using the CC button in player',
                      style: TextStyle(
                        color: isDark ? AppTheme.textMuted : AppTheme.lightTextMuted,
                        fontSize: 12,
                      ),
                    ),
                    value: subsEnabled,
                    onChanged: (val) {
                      ref.read(playbackSettingsProvider.notifier).setSubtitlesEnabled(val);
                    },
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Subtitle Font Size',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryPurple.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.primaryPurple.withOpacity(0.5)),
                        ),
                        child: Text(
                          '${subFontSize.toInt()} pt',
                          style: const TextStyle(
                            color: AppTheme.primaryPurpleLight,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppTheme.primaryPurple,
                      thumbColor: AppTheme.accentCyan,
                    ),
                    child: Slider(
                      value: subFontSize,
                      min: 14.0,
                      max: 38.0,
                      divisions: 12,
                      label: '${subFontSize.toInt()} pt',
                      onChanged: (val) {
                        ref.read(playbackSettingsProvider.notifier).setSubtitleFontSize(val);
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Live Subtitle Preview Container
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Preview: [Anime Subtitles Style]',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: subFontSize,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        shadows: const [
                          Shadow(offset: Offset(-1.5, -1.5), color: Colors.black, blurRadius: 4),
                          Shadow(offset: Offset(1.5, -1.5), color: Colors.black, blurRadius: 4),
                          Shadow(offset: Offset(-1.5, 1.5), color: Colors.black, blurRadius: 4),
                          Shadow(offset: Offset(1.5, 1.5), color: Colors.black, blurRadius: 4),
                        ],
                      ),
                    ),
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
                    'Primary anime backend provider for searching and streaming:',
                    style: TextStyle(
                      color: isDark ? AppTheme.textMuted : AppTheme.lightTextMuted,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  RadioListTile<ScraperType>(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Primary Provider', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Primary online provider with multi-quality sub & dub streaming.'),
                    value: ScraperType.hianime,
                    groupValue: ScraperType.hianime,
                    onChanged: (val) {
                      ref.read(scraperTypeProvider.notifier).state = ScraperType.hianime;
                    },
                  ),
                  const Divider(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    enabled: false,
                    title: Row(
                      children: [
                        Text(
                          'Secondary Provider',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.amber.withOpacity(0.4)),
                          ),
                          child: const Text(
                            'Coming Soon',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      'Alternative provider fallback (currently in development).',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    enabled: false,
                    title: Row(
                      children: [
                        Text(
                          'Provider 3',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.amber.withOpacity(0.4)),
                          ),
                          child: const Text(
                            'Coming Soon',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      'Backup provider (coming in future update).',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
                    ),
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
                            'Version ${UpdateService.currentAppVersion} (Release)',
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
                    'ani-mobile is a cross-platform anime streaming and offline download application. Powered by Flutter, media_kit (libmpv), Dio, and Riverpod.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.accentCyan.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.system_update_rounded, color: AppTheme.accentCyan, size: 22),
                    ),
                    title: const Text('Check for Updates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Verify if a newer version is available'),
                    trailing: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.accentCyan),
                        foregroundColor: AppTheme.accentCyan,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                      onPressed: () {
                        UpdateController.checkManualUpdate(context, ref);
                      },
                      child: const Text('Check Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.bug_report_outlined, color: Colors.amber, size: 22),
                    ),
                    title: const Text('Test Update Alert (Mock)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                    subtitle: const Text('Simulate new update popup (for testing)'),
                    trailing: TextButton(
                      onPressed: () {
                        UpdateController.checkManualUpdate(context, ref, forceMock: true);
                      },
                      child: const Text('Simulate', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 10),
                  const Text(
                    'Developer & Contact',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'For questions, feedback, bug reports, or feature requests, contact on GitHub:',
                    style: TextStyle(
                      color: isDark ? AppTheme.textMuted : AppTheme.lightTextMuted,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryPurple.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.code_rounded, color: AppTheme.accentCyan, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'NonLaHu',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              Text(
                                'github.com/NonLaHu',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  color: AppTheme.accentCyan,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 20),
                          tooltip: 'Copy GitHub Link',
                          onPressed: () {
                            Clipboard.setData(const ClipboardData(text: 'https://github.com/NonLaHu'));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Copied GitHub link (https://github.com/NonLaHu) to clipboard!'),
                                duration: Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildPill('libmpv Video Engine'),
                      _buildPill('Software Rendering (S/W)'),
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
