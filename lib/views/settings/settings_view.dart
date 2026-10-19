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

enum AudioQualityLevel {
  auto('Auto (Optimized)'),
  normal('Normal (160 kbps)'),
  high('High (320 kbps)'),
  lossless('Lossless (FLAC)');

  final String label;
  const AudioQualityLevel(this.label);
}

class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key});

  @override
  ConsumerState<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<SettingsView> {
  bool _wifiOnly = false;
  int _storageUsedBytes = 0;
  AudioQualityLevel _streamingQuality = AudioQualityLevel.high;
  AudioQualityLevel _downloadQuality = AudioQualityLevel.high;

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
        setState(() => _storageUsedBytes = total);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ),
      body: ListView(
        children: [
          // Audio Quality Settings
          const Padding(
            padding: EdgeInsets.fromLTRB(Dimensions.space16, Dimensions.space16, Dimensions.space16, Dimensions.space8),
            child: Text(
              'AUDIO QUALITY',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ),
          ListTile(
            title: const Text('Streaming Quality', style: TextStyle(color: AppColors.textPrimary)),
            subtitle: Text(_streamingQuality.label, style: const TextStyle(color: AppColors.cyanAccent)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary),
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => SimpleDialog(
                  backgroundColor: AppColors.card,
                  title: const Text('Select Streaming Quality', style: TextStyle(color: AppColors.textPrimary)),
                  children: AudioQualityLevel.values.map((q) {
                    return RadioListTile<AudioQualityLevel>(
                      title: Text(q.label, style: const TextStyle(color: AppColors.textPrimary)),
                      value: q,
                      groupValue: _streamingQuality,
                      activeColor: AppColors.cyanAccent,
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _streamingQuality = val);
                          Navigator.pop(ctx);
                        }
                      },
                    );
                  }).toList(),
                ),
              );
            },
          ),
          ListTile(
            title: const Text('Download Quality', style: TextStyle(color: AppColors.textPrimary)),
            subtitle: Text(_downloadQuality.label, style: const TextStyle(color: AppColors.cyanAccent)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary),
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => SimpleDialog(
                  backgroundColor: AppColors.card,
                  title: const Text('Select Download Quality', style: TextStyle(color: AppColors.textPrimary)),
                  children: AudioQualityLevel.values.map((q) {
                    return RadioListTile<AudioQualityLevel>(
                      title: Text(q.label, style: const TextStyle(color: AppColors.textPrimary)),
                      value: q,
                      groupValue: _downloadQuality,
                      activeColor: AppColors.cyanAccent,
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _downloadQuality = val);
                          Navigator.pop(ctx);
                        }
                      },
                    );
                  }).toList(),
                ),
              );
            },
          ),
          const Divider(color: AppColors.surface),

          // Downloads & Storage
          const Padding(
            padding: EdgeInsets.fromLTRB(Dimensions.space16, Dimensions.space16, Dimensions.space16, Dimensions.space8),
            child: Text(
              'DOWNLOADS & STORAGE',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ),
          SwitchListTile(
            value: _wifiOnly,
            activeColor: AppColors.cyanAccent,
            title: const Text(AppStrings.wifiOnly, style: TextStyle(color: AppColors.textPrimary)),
            subtitle: const Text('Only download music when connected to Wi-Fi', style: TextStyle(color: AppColors.textSecondary)),
            onChanged: (val) {
              setState(() {
                _wifiOnly = val;
                ref.read(downloadControllerProvider.notifier).setWifiOnly(val);
              });
            },
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

          // Account
          const Padding(
            padding: EdgeInsets.fromLTRB(Dimensions.space16, Dimensions.space16, Dimensions.space16, Dimensions.space8),
            child: Text(
              'ACCOUNT & LEGAL SOURCES',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const ListTile(
            title: Text('Licensed Music Sources', style: TextStyle(color: AppColors.textPrimary)),
            subtitle: Text('Local Audio Library, Jamendo (Creative Commons), Free Music Archive, Internet Archive', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            trailing: Icon(Icons.verified, color: AppColors.cyanAccent),
          ),
          ListTile(
            title: const Text(AppStrings.signOut, style: TextStyle(color: AppColors.textPrimary)),
            trailing: const Icon(Icons.logout, color: AppColors.textSecondary),
            onTap: () {
              ref.read(authControllerProvider.notifier).signOut();
            },
          ),
        ],
      ),
    );
  }
}
