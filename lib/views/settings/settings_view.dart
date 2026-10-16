import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/auth_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/formatters.dart';

class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key});

  @override
  ConsumerState<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<SettingsView> {
  bool _wifiOnly = false;
  final int _storageUsedBytes = 145 * 1024 * 1024; // 145 MB demo storage

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(Dimensions.space16, Dimensions.space16, Dimensions.space16, Dimensions.space8),
            child: Text(
              'Downloads & Storage',
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
            activeColor: AppColors.accent,
            title: const Text(AppStrings.wifiOnly, style: TextStyle(color: AppColors.textPrimary)),
            subtitle: const Text('Only download music when connected to Wi-Fi', style: TextStyle(color: AppColors.textSecondary)),
            onChanged: (val) {
              setState(() {
                _wifiOnly = val;
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
                      onPressed: () {
                        Navigator.of(ctx).pop();
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(color: AppColors.surface),
          const Padding(
            padding: EdgeInsets.fromLTRB(Dimensions.space16, Dimensions.space16, Dimensions.space16, Dimensions.space8),
            child: Text(
              'Account',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
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
