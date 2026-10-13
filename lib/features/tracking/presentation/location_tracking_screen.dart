import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../app/theme/app_colors.dart';
import '../../auth/domain/auth_state.dart';
import '../../chat/presentation/chat_screen.dart';
import '../../media/presentation/app_image_view.dart';
import '../../notifications/data/notifications_repository.dart';
import '../data/location_repository.dart';
import '../domain/location_model.dart';

class LocationTrackingScreen extends ConsumerStatefulWidget {
  const LocationTrackingScreen({super.key});

  @override
  ConsumerState<LocationTrackingScreen> createState() => _LocationTrackingScreenState();
}

class _LocationTrackingScreenState extends ConsumerState<LocationTrackingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _radarController;
  String _selectedStatus = 'Di Rumah 🏡';

  final List<String> _statusOptions = [
    'Di Rumah 🏡',
    'Di Kampus/Kantor 🏢',
    'Sedang di Jalan 🚗',
    'Lagi Santai ☕',
    'Lagi Belanja 🛍️',
    'Lagi Bareng Kamu 💕',
  ];

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  Future<void> _toggleLiveSharing(bool enable) async {
    final user = ref.read(authStateProvider).user;
    if (user == null || user.coupleId == null) return;

    final repo = ref.read(locationRepositoryProvider);
    setState(() {});

    try {
      if (enable) {
        await repo.startLiveSharing(
          coupleId: user.coupleId!,
          uid: user.uid,
          displayName: user.displayName,
          photoUrl: user.photoUrl,
          placeLabel: _selectedStatus,
        );

        try {
          await ref.read(notificationsRepositoryProvider).sendNotification(
                coupleId: user.coupleId!,
                senderUid: user.uid,
                senderName: user.displayName,
                title: '📍 ${user.displayName} menyalakan Live Location!',
                body: 'Kamu sekarang bisa melihat pergerakannya secara langsung di Radar.',
                type: 'location',
              );
        } catch (_) {}

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🟢 Live Location Aktif! Posisi otomatis terkirim.'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        await repo.stopLiveSharing(
          coupleId: user.coupleId!,
          uid: user.uid,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚪ Live Location Dimatikan.'),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error toggling live location: $e');
    }
    if (mounted) setState(() {});
  }

  Future<void> _shareToChat(LocationModel myLoc) async {
    final user = ref.read(authStateProvider).user;
    if (user == null || user.coupleId == null) return;

    try {
      final convId = 'conv_${user.coupleId}';
      await ref.read(chatRepositoryProvider).sendLocationMessage(
            conversationId: convId,
            senderUid: user.uid,
            latitude: myLoc.latitude,
            longitude: myLoc.longitude,
            placeLabel: myLoc.placeLabel ?? _selectedStatus,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lokasi dibagikan ke Chat! 💬')),
        );
        context.go('/chat');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengirim ke chat: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _pingPartnerForLocation() async {
    final user = ref.read(authStateProvider).user;
    if (user == null || user.coupleId == null) return;

    await ref.read(notificationsRepositoryProvider).sendNotification(
          coupleId: user.coupleId!,
          senderUid: user.uid,
          senderName: user.displayName,
          title: '📍 Nyalakan Live Location dong!',
          body: '${user.displayName} ingin saling tracking denganmu.',
          type: 'location',
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permintaan live location dikirim ke pasangan! 🔔')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).user;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (user == null || user.coupleId == null) {
      return const Scaffold(
        body: Center(child: Text('Silakan hubungkan pasangan terlebih dahulu.')),
      );
    }

    final coupleId = user.coupleId!;
    final repo = ref.watch(locationRepositoryProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Couple Radar & Live Tracking'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Ping Doi',
            icon: const Icon(Icons.notifications_active_outlined),
            onPressed: _pingPartnerForLocation,
          ),
        ],
      ),
      body: StreamBuilder<Map<String, LocationModel>>(
        stream: repo.watchCoupleLocations(coupleId),
        builder: (context, snapshot) {
          final locs = snapshot.data ?? {};
          final myLoc = locs[user.uid];
          final partnerEntry = locs.entries.where((e) => e.key != user.uid);
          final partnerLoc = partnerEntry.isNotEmpty ? partnerEntry.first.value : null;

          final isMyLiveActive = (myLoc?.isLive == true) || repo.isLiveSharing;
          final isPartnerLive = partnerLoc?.isLive ?? false;

          return SingleChildScrollView(
            child: Column(
              children: [
                // MASTER LIVE LOCATION SWITCH CARD
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isMyLiveActive
                            ? [
                                const Color(0xFF1B4931),
                                isDark ? AppColors.surfaceDark : const Color(0xFFE8F7EE)
                              ]
                            : [
                                isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                                isDark ? AppColors.surfaceSubtleDark : AppColors.surfaceSubtleLight
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isMyLiveActive
                            ? AppColors.success
                            : (isDark ? AppColors.dividerDark : AppColors.dividerLight),
                        width: isMyLiveActive ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isMyLiveActive ? AppColors.success : Colors.black)
                              .withValues(alpha: isMyLiveActive ? 0.2 : 0.05),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isMyLiveActive
                                ? AppColors.success.withValues(alpha: 0.2)
                                : (isDark ? Colors.white12 : Colors.black12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isMyLiveActive ? Icons.sensors_rounded : Icons.sensors_off_rounded,
                            color: isMyLiveActive ? AppColors.success : Colors.grey,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Live Location Sharing',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  if (isMyLiveActive)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.success,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Text(
                                        'LIVE',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                isMyLiveActive
                                    ? 'Posisi terkirim otomatis secara realtime'
                                    : 'Nyalakan untuk saling tracking otomatis',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: isMyLiveActive,
                          activeTrackColor: AppColors.success,
                          onChanged: (val) => _toggleLiveSharing(val),
                        ),
                      ],
                    ),
                  ),
                ),

                // Visual Couple Radar Canvas
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Container(
                    height: 290,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Radar Background Animation
                        AnimatedBuilder(
                          animation: _radarController,
                          builder: (context, _) {
                            return CustomPaint(
                              size: const Size(double.infinity, 290),
                              painter: CoupleRadarPainter(
                                progress: _radarController.value,
                                isDark: isDark,
                              ),
                            );
                          },
                        ),
                        // User Avatar Pin
                        Positioned(
                          left: 45,
                          bottom: 50,
                          child: _buildPin(
                            name: 'Kamu',
                            photoUrl: user.photoUrl,
                            isMe: true,
                            isLive: isMyLiveActive,
                            label: myLoc?.placeLabel ?? 'Di sini',
                          ),
                        ),
                        // Partner Avatar Pin
                        Positioned(
                          right: 45,
                          top: 45,
                          child: _buildPin(
                            name: partnerLoc?.displayName ?? 'Doi',
                            photoUrl: partnerLoc?.photoUrl,
                            isMe: false,
                            isLive: isPartnerLive,
                            label: partnerLoc?.placeLabel ?? 'Mencari...',
                          ),
                        ),
                        // Distance Center Pill
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.favorite_rounded, color: Colors.white, size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  (myLoc != null && partnerLoc != null)
                                      ? myLoc.formattedDistanceTo(partnerLoc)
                                      : 'Radar Aktif ✨',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Partner Status Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              AppAvatar(
                                photoUrl: partnerLoc?.photoUrl,
                                name: partnerLoc?.displayName ?? 'D',
                                radius: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          partnerLoc?.displayName ?? 'Pasangan',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        if (isPartnerLive)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.success,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: const Text(
                                              'LIVE',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    Text(
                                      isPartnerLive
                                          ? '🟢 Sedang berbagi live lokasi'
                                          : (partnerLoc != null
                                              ? 'Terakhir diperbarui ${DateFormat('HH:mm').format(partnerLoc.updatedAt)}'
                                              : 'Belum memperbarui lokasi'),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isPartnerLive
                                            ? AppColors.success
                                            : (isDark
                                                ? AppColors.textSecondaryDark
                                                : AppColors.textSecondaryLight),
                                        fontWeight: isPartnerLive ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.battery_charging_full_rounded,
                                        size: 14, color: AppColors.success),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${partnerLoc?.batteryLevel ?? 88}%',
                                      style: const TextStyle(
                                        color: AppColors.success,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.surfaceSubtleDark : AppColors.surfaceSubtleLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.pin_drop_rounded, size: 18, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    partnerLoc?.placeLabel ?? 'Sedang santai di rumah 🏡',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Status Activity Selector
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status Aktivitas Kamu',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _statusOptions.map((status) {
                          final isSelected = _selectedStatus == status;
                          return ChoiceChip(
                            label: Text(status),
                            selected: isSelected,
                            selectedColor: AppColors.primaryLight,
                            labelStyle: TextStyle(
                              color: isSelected ? AppColors.primary : null,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                            onSelected: (val) {
                              if (val) {
                                setState(() => _selectedStatus = status);
                                if (isMyLiveActive) {
                                  repo.updateLocation(
                                    coupleId: coupleId,
                                    uid: user.uid,
                                    displayName: user.displayName,
                                    photoUrl: user.photoUrl,
                                    placeLabel: status,
                                    isLive: true,
                                  );
                                }
                              }
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),

                      // Quick Action: Share to chat
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () {
                            if (myLoc != null) {
                              _shareToChat(myLoc);
                            } else {
                              repo
                                  .updateLocation(
                                coupleId: coupleId,
                                uid: user.uid,
                                displayName: user.displayName,
                                photoUrl: user.photoUrl,
                                placeLabel: _selectedStatus,
                              )
                                  .then((updated) {
                                if (updated != null) _shareToChat(updated);
                              });
                            }
                          },
                          icon: const Icon(Icons.share_location_rounded, size: 18),
                          label: const Text('Bagi Lokasi Saat Ini ke Chat'),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPin({
    required String name,
    required String? photoUrl,
    required bool isMe,
    required bool isLive,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            if (isLive)
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isMe ? const Color(0xFF2EC4B6) : AppColors.primary)
                      .withValues(alpha: 0.25),
                ),
              ),
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isLive ? AppColors.success : (isMe ? Colors.white : AppColors.primary),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isMe ? Colors.black : AppColors.primary).withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipOval(
                child: photoUrl != null && photoUrl.isNotEmpty
                    ? AppImageView(imageUrl: photoUrl, fit: BoxFit.cover)
                    : Container(
                        color: isMe ? AppColors.surfaceSubtleDark : AppColors.primaryLight,
                        child: Center(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: TextStyle(
                              color: isMe ? Colors.white : AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isLive
                      ? AppColors.success
                      : (isMe ? const Color(0xFF2EC4B6) : AppColors.primary),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isLive ? Icons.sensors_rounded : Icons.favorite,
                  size: 10,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            isLive ? '🟢 $label' : label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class CoupleRadarPainter extends CustomPainter {
  final double progress;
  final bool isDark;

  CoupleRadarPainter({required this.progress, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) * 0.45;

    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : AppColors.primary).withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int i = 1; i <= 3; i++) {
      final r = maxRadius * (i / 3.0);
      canvas.drawCircle(center, r, gridPaint);
    }

    canvas.drawLine(
      Offset(center.dx - maxRadius, center.dy),
      Offset(center.dx + maxRadius, center.dy),
      gridPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - maxRadius),
      Offset(center.dx, center.dy + maxRadius),
      gridPaint,
    );

    final waveRadius = maxRadius * progress;
    final wavePaint = Paint()
      ..color = AppColors.primary.withValues(alpha: (1.0 - progress) * 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, waveRadius, wavePaint);
  }

  @override
  bool shouldRepaint(covariant CoupleRadarPainter oldDelegate) => true;
}
