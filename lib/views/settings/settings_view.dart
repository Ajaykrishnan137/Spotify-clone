import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../controllers/auth_controller.dart';
import '../../controllers/download_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/formatters.dart';
import '../../core/services/app_settings_service.dart';
import '../shared_widgets/equalizer_sheet.dart';

class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key});

  @override
  ConsumerState<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<SettingsView> {
  int _storageUsedBytes = 0;
  String _downloadLocation = 'Internal Storage (App Sandbox)';

  @override
  void initState() {
    super.initState();
    _calculateStorageUsed();
  }

  Future<void> _calculateStorageUsed() async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      int total = 0;

      final offlineDir = Directory(p.join(appDocDir.path, 'offline_music'));
      if (offlineDir.existsSync()) {
        for (final file in offlineDir.listSync(recursive: true)) {
          if (file is File) total += file.lengthSync();
        }
      }

      final secureDir = Directory(p.join(appDocDir.path, 'secure_audio'));
      if (secureDir.existsSync()) {
        for (final file in secureDir.listSync(recursive: true)) {
          if (file is File) total += file.lengthSync();
        }
      }

      if (mounted) {
        setState(() {
          _storageUsedBytes = total;
          _downloadLocation = offlineDir.path;
        });
      }
    } catch (_) {}
  }

  void _clearCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        for (final f in tempDir.listSync()) {
          try {
            f.deleteSync(recursive: true);
          } catch (_) {}
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Temporary audio & image cache cleared.')),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final settingsNotifier = ref.read(appSettingsProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ),
      body: ListView(
        children: [
          // 1. Audio Quality
          _buildSectionHeader('AUDIO QUALITY'),
          ListTile(
            title: const Text('Streaming Quality', style: TextStyle(color: AppColors.textPrimary)),
            subtitle: Text(settings.streamingQuality, style: const TextStyle(color: AppColors.cyanAccent)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary),
            onTap: () {
              _showQualityPicker(
                title: 'Streaming Quality',
                current: settings.streamingQuality,
                onSelected: (val) => settingsNotifier.setStreamingQuality(val),
              );
            },
          ),
          ListTile(
            title: const Text('Download Quality', style: TextStyle(color: AppColors.textPrimary)),
            subtitle: Text(settings.downloadQuality, style: const TextStyle(color: AppColors.cyanAccent)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary),
            onTap: () {
              _showQualityPicker(
                title: 'Download Quality',
                current: settings.downloadQuality,
                onSelected: (val) => settingsNotifier.setDownloadQuality(val),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.equalizer, color: AppColors.cyanAccent),
            title: const Text('Equalizer & Audio FX', style: TextStyle(color: AppColors.textPrimary)),
            subtitle: const Text('5-band EQ, bass boost, presets', style: TextStyle(color: AppColors.textSecondary)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary),
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: AppColors.surface,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(Dimensions.radiusLarge)),
                ),
                builder: (_) => const EqualizerSheet(),
              );
            },
          ),
          const Divider(color: AppColors.surface),

          // 2. Playback
          _buildSectionHeader('PLAYBACK'),
          SwitchListTile(
            value: settings.gapless,
            activeColor: AppColors.cyanAccent,
            title: const Text('Gapless Playback', style: TextStyle(color: AppColors.textPrimary)),
            subtitle: const Text('Continuous playback between tracks', style: TextStyle(color: AppColors.textSecondary)),
            onChanged: (val) => settingsNotifier.setGapless(val),
          ),
          SwitchListTile(
            value: settings.crossfade,
            activeColor: AppColors.cyanAccent,
            title: const Text('Crossfade Songs', style: TextStyle(color: AppColors.textPrimary)),
            subtitle: Text(settings.crossfade ? '${settings.crossfadeDurationSec} seconds overlap' : 'Disabled',
                style: const TextStyle(color: AppColors.textSecondary)),
            onChanged: (val) => settingsNotifier.setCrossfade(val),
          ),
          SwitchListTile(
            value: settings.volumeNormalization,
            activeColor: AppColors.cyanAccent,
            title: const Text('Volume Normalization', style: TextStyle(color: AppColors.textPrimary)),
            subtitle: const Text('Set consistent volume for all tracks', style: TextStyle(color: AppColors.textSecondary)),
            onChanged: (val) => settingsNotifier.setVolumeNormalization(val),
          ),
          const Divider(color: AppColors.surface),

          // 3. Downloads & Storage
          _buildSectionHeader('DOWNLOADS & STORAGE'),
          SwitchListTile(
            value: settings.wifiOnly,
            activeColor: AppColors.cyanAccent,
            title: const Text(AppStrings.wifiOnly, style: TextStyle(color: AppColors.textPrimary)),
            subtitle: const Text('Only download music when connected to Wi-Fi', style: TextStyle(color: AppColors.textSecondary)),
            onChanged: (val) {
              settingsNotifier.setWifiOnly(val);
              ref.read(downloadControllerProvider.notifier).setWifiOnly(val);
            },
          ),
          ListTile(
            title: const Text('Concurrent Downloads', style: TextStyle(color: AppColors.textPrimary)),
            subtitle: Text('${settings.concurrentDownloads} files at once', style: const TextStyle(color: AppColors.cyanAccent)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: AppColors.textSecondary),
                  onPressed: settings.concurrentDownloads > 1
                      ? () {
                          final count = settings.concurrentDownloads - 1;
                          settingsNotifier.setConcurrentDownloads(count);
                          ref.read(downloadControllerProvider.notifier).setConcurrencyLimit(count);
                        }
                      : null,
                ),
                Text('${settings.concurrentDownloads}',
                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: AppColors.cyanAccent),
                  onPressed: settings.concurrentDownloads < 4
                      ? () {
                          final count = settings.concurrentDownloads + 1;
                          settingsNotifier.setConcurrentDownloads(count);
                          ref.read(downloadControllerProvider.notifier).setConcurrencyLimit(count);
                        }
                      : null,
                ),
              ],
            ),
          ),
          ListTile(
            title: const Text('Download Location', style: TextStyle(color: AppColors.textPrimary)),
            subtitle: Text(_downloadLocation, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            trailing: const Icon(Icons.folder_open, color: AppColors.textSecondary),
          ),
          ListTile(
            title: const Text(AppStrings.storageUsed, style: TextStyle(color: AppColors.textPrimary)),
            subtitle: Text(Formatters.formatBytes(_storageUsedBytes), style: const TextStyle(color: AppColors.textSecondary)),
            trailing: const Icon(Icons.storage, color: AppColors.textSecondary),
          ),
          ListTile(
            title: const Text(
              AppStrings.clearAllDownloads,
              style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
            ),
            subtitle: const Text('Remove all offline audio files from this device', style: TextStyle(color: AppColors.textSecondary)),
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppColors.surface,
                  title: const Text('Delete all downloads?'),
                  content: const Text('This will remove all downloaded songs from your device. You can download them again anytime.'),
                  actions: [
                    TextButton(
                      child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                    TextButton(
                      child: const Text('Delete', style: TextStyle(color: AppColors.error)),
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        await ref.read(downloadControllerProvider.notifier).deleteAllDownloads();
                        await _calculateStorageUsed();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('All downloaded files removed.')),
                          );
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(color: AppColors.surface),

          // 4. Appearance
          _buildSectionHeader('APPEARANCE'),
          ListTile(
            title: const Text('Theme', style: TextStyle(color: AppColors.textPrimary)),
            subtitle: Text(settings.themeMode == 'dark' ? 'Dark theme (Default)' : 'Light theme',
                style: const TextStyle(color: AppColors.cyanAccent)),
            trailing: const Icon(Icons.palette_outlined, color: AppColors.textSecondary),
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => SimpleDialog(
                  backgroundColor: AppColors.card,
                  title: const Text('Select Theme', style: TextStyle(color: AppColors.textPrimary)),
                  children: [
                    RadioListTile<String>(
                      title: const Text('Dark theme (Recommended)', style: TextStyle(color: AppColors.textPrimary)),
                      value: 'dark',
                      groupValue: settings.themeMode,
                      activeColor: AppColors.cyanAccent,
                      onChanged: (val) {
                        if (val != null) {
                          settingsNotifier.setThemeMode(val);
                          Navigator.pop(ctx);
                        }
                      },
                    ),
                    RadioListTile<String>(
                      title: const Text('Light theme', style: TextStyle(color: AppColors.textPrimary)),
                      value: 'light',
                      groupValue: settings.themeMode,
                      activeColor: AppColors.cyanAccent,
                      onChanged: (val) {
                        if (val != null) {
                          settingsNotifier.setThemeMode(val);
                          Navigator.pop(ctx);
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(color: AppColors.surface),

          // 5. Cache
          _buildSectionHeader('CACHE'),
          ListTile(
            title: const Text('Clear Temporary Cache', style: TextStyle(color: AppColors.textPrimary)),
            subtitle: const Text('Purges temporary downloaded parts and album art cache', style: TextStyle(color: AppColors.textSecondary)),
            trailing: const Icon(Icons.cleaning_services, color: AppColors.textSecondary),
            onTap: _clearCache,
          ),
          const Divider(color: AppColors.surface),

          // 6. Notifications
          _buildSectionHeader('NOTIFICATIONS'),
          SwitchListTile(
            value: settings.enableNotifications,
            activeColor: AppColors.cyanAccent,
            title: const Text('In-App & Download Notifications', style: TextStyle(color: AppColors.textPrimary)),
            subtitle: const Text('Show alerts when downloads complete or fail', style: TextStyle(color: AppColors.textSecondary)),
            onChanged: (val) => settingsNotifier.setEnableNotifications(val),
          ),
          const Divider(color: AppColors.surface),

          // 7. About & Legal Sources
          _buildSectionHeader('ABOUT SKYTUNE'),
          const ListTile(
            title: Text('SkyTune Music Player', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
            subtitle: Text('Version 1.0.0+1 (Production Release)', style: TextStyle(color: AppColors.textSecondary)),
            trailing: Icon(Icons.info_outline, color: AppColors.cyanAccent),
          ),
          const ListTile(
            title: Text('100% Legal Music Sources', style: TextStyle(color: AppColors.textPrimary)),
            subtitle: Text(
              '• Jamendo Music (Creative Commons)\n• Free Music Archive (FMA)\n• Internet Archive (Audio Archive)\n• User Local Storage Files\n\nNote: SkyTune strictly uses legal, licensed, Creative Commons, and free-to-use sources. Songs not available on these platforms cannot be displayed or streamed.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            ),
          ),
          const ListTile(
            title: Text('Image & Artist Media Attribution', style: TextStyle(color: AppColors.textPrimary)),
            subtitle: Text(
              'Artist profile photos and cover visuals are sourced under open licenses from Jamendo Music (Creative Commons) and Wikimedia Commons (CC-BY-SA 3.0/4.0 & Public Domain). All credits belong to their respective creators and license holders. Fallbacks use procedurally generated SkyTune gradients.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            ),
          ),
          ListTile(
            title: const Text(AppStrings.signOut, style: TextStyle(color: AppColors.textPrimary)),
            trailing: const Icon(Icons.logout, color: AppColors.textSecondary),
            onTap: () {
              ref.read(authControllerProvider.notifier).signOut();
            },
          ),
          const SizedBox(height: Dimensions.miniPlayerHeight + 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Dimensions.space16, Dimensions.space16, Dimensions.space16, Dimensions.space8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  void _showQualityPicker({
    required String title,
    required String current,
    required Function(String) onSelected,
  }) {
    const qualities = [
      'Normal (160 kbps)',
      'High (320 kbps)',
      'Lossless (FLAC)',
      'Auto (Adaptive)',
    ];

    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: AppColors.card,
        title: Text(title, style: const TextStyle(color: AppColors.textPrimary)),
        children: qualities.map((q) {
          return RadioListTile<String>(
            title: Text(q, style: const TextStyle(color: AppColors.textPrimary)),
            value: q,
            groupValue: current,
            activeColor: AppColors.cyanAccent,
            onChanged: (val) {
              if (val != null) {
                onSelected(val);
                Navigator.pop(ctx);
              }
            },
          );
        }).toList(),
      ),
    );
  }
}
