import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/dimensions.dart';

class AppSnackBar {
  AppSnackBar._();

  /// Shows a floating undo snackbar positioned safely above the mini-player and bottom navigation.
  /// - Auto-closes after 4 seconds
  /// - Only one snackbar at a time (clears existing)
  /// - Small swipe-to-dismiss
  /// - Tappable Undo button
  /// - Calls onDismissed if not undone
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showUndo({
    required BuildContext context,
    required String message,
    required VoidCallback onUndo,
    VoidCallback? onDismissed,
    Duration duration = const Duration(seconds: 4),
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    bool wasUndone = false;

    final controller = messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: AppColors.surface,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: Dimensions.miniPlayerHeight + 16,
        ),
        duration: duration,
        dismissDirection: DismissDirection.horizontal,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
          side: const BorderSide(color: AppColors.elevated, width: 1),
        ),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: AppColors.cyanAccent,
          onPressed: () {
            wasUndone = true;
            onUndo();
          },
        ),
      ),
    );

    controller.closed.then((reason) {
      if (!wasUndone && reason != SnackBarClosedReason.action) {
        onDismissed?.call();
      }
    });

    return controller;
  }

  /// Shows a general info/success floating snackbar safely above mini-player
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showInfo({
    required BuildContext context,
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    return messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
          ),
        ),
        backgroundColor: AppColors.surface,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: Dimensions.miniPlayerHeight + 16,
        ),
        duration: duration,
        dismissDirection: DismissDirection.horizontal,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
          side: const BorderSide(color: AppColors.elevated, width: 1),
        ),
      ),
    );
  }
}
