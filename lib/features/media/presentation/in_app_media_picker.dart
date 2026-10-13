import 'dart:io';
import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import 'builtin_camera_screen.dart';
import 'builtin_media_picker_sheet.dart';

class InAppMediaPicker {
  /// Opens full in-app media picker bottom sheet (WhatsApp style)
  static Future<void> show({
    required BuildContext context,
    required Function(File file, String? caption, String type) onMediaSelected,
    VoidCallback? onShareLocation,
  }) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Kirim ke Doi',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Options Grid
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildOption(
                      icon: Icons.camera_alt_rounded,
                      label: 'PAP Kilat',
                      badge: 'Instant',
                      color: AppColors.primary,
                      onTap: () async {
                        Navigator.pop(ctx);
                        await openPapCamera(
                          context: context,
                          onMediaSelected: onMediaSelected,
                        );
                      },
                    ),
                    _buildOption(
                      icon: Icons.photo_library_rounded,
                      label: 'Galeri Us Only',
                      badge: 'Built-in',
                      color: const Color(0xFF6C63FF),
                      onTap: () async {
                        Navigator.pop(ctx);
                        await openGalleryPicker(
                          context: context,
                          onMediaSelected: onMediaSelected,
                        );
                      },
                    ),
                    if (onShareLocation != null)
                      _buildOption(
                        icon: Icons.location_on_rounded,
                        label: 'Bagi Lokasi',
                        badge: 'Live',
                        color: const Color(0xFF2EC4B6),
                        onTap: () {
                          Navigator.pop(ctx);
                          onShareLocation();
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _buildOption({
    required IconData icon,
    required String label,
    required String badge,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 96,
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Opens Built-in in-app Camera directly for PAP with aesthetic WhatsApp-style editor
  static Future<void> openPapCamera({
    required BuildContext context,
    required Function(File file, String? caption, String type) onMediaSelected,
  }) async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BuiltinCameraScreen(
          isPapMode: true,
          onMediaSelected: onMediaSelected,
        ),
      ),
    );
  }

  /// Opens Built-in in-app Camera in standard photo mode
  static Future<void> openCamera({
    required BuildContext context,
    required Function(File file, String? caption, String type) onMediaSelected,
  }) async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BuiltinCameraScreen(
          isPapMode: false,
          onMediaSelected: onMediaSelected,
        ),
      ),
    );
  }

  /// Opens Built-in Gallery Picker (scanning local media) directly inside the app
  static Future<void> openGalleryPicker({
    required BuildContext context,
    required Function(File file, String? caption, String type) onMediaSelected,
    bool isPap = false,
  }) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BuiltinMediaPickerSheet(
        isPap: isPap,
        onMediaPicked: (file) {
          Navigator.pop(ctx);
          onMediaSelected(file, null, isPap ? 'pap' : 'image');
        },
        onMediaWithEditorSelected: onMediaSelected,
      ),
    );
  }

  /// Opens Built-in Gallery specifically for picking a single File (e.g. avatar or memory) without caption
  static Future<void> pickSingleImage({
    required BuildContext context,
    required Function(File file) onFilePicked,
  }) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BuiltinMediaPickerSheet(
        isPap: false,
        onMediaPicked: (file) {
          Navigator.pop(ctx);
          onFilePicked(file);
        },
      ),
    );
  }
}
