import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/domain/user_model.dart';
import '../../chat/domain/message_model.dart';
import '../../chat/presentation/chat_screen.dart';
import '../../media/presentation/app_image_view.dart';
import '../../media/presentation/in_app_media_picker.dart';
import '../../notifications/data/notifications_repository.dart';
import '../../tracking/data/location_repository.dart';
import '../../tracking/domain/location_model.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).user;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (user == null || user.coupleId == null) {
      return const Scaffold(
        body: Center(child: Text('Memuat ruang pasangan...')),
      );
    }

    final coupleId = user.coupleId!;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('coupleSpaces').doc(coupleId).snapshots(),
          builder: (context, snapshot) {
            final coupleData = (snapshot.hasError || !snapshot.hasData) ? null : snapshot.data?.data();
            DateTime? pairedDate;
            if (coupleData != null && coupleData['pairedAt'] != null) {
              pairedDate = (coupleData['pairedAt'] as Timestamp).toDate();
            }

            final daysTogether = pairedDate != null
                ? DateTime.now().difference(pairedDate).inDays + 1
                : 1;

            final memberUids = List<String>.from(coupleData?['memberUids'] as List? ?? []);
            final partnerUid = memberUids.firstWhere((id) => id != user.uid, orElse: () => '');

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: partnerUid.isNotEmpty
                  ? FirebaseFirestore.instance.collection('users').doc(partnerUid).snapshots()
                  : null,
              builder: (context, partnerSnap) {
                UserModel? partner;
                if (partnerSnap.hasData && !partnerSnap.hasError && partnerSnap.data!.exists) {
                  partner = UserModel.fromFirestore(partnerSnap.data!);
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with Notifications Bell
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'us only',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Text(
                                'just us, always.',
                                style: TextStyle(
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              // Notification Bell with stream counter
                              StreamBuilder(
                                stream: ref
                                    .watch(notificationsRepositoryProvider)
                                    .watchNotifications(coupleId),
                                builder: (context, notifSnap) {
                                  final notifs = notifSnap.data ?? [];
                                  final unread = notifs.where((n) => !n.isRead && n.senderUid != user.uid).length;

                                  return Stack(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.notifications_outlined, size: 26),
                                        onPressed: () => context.go('/notifications'),
                                      ),
                                      if (unread > 0)
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: AppColors.primary,
                                              shape: BoxShape.circle,
                                            ),
                                            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                            child: Text(
                                              '$unread',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.favorite_rounded, size: 14, color: AppColors.primary),
                                    SizedBox(width: 4),
                                    Text(
                                      'Connected',
                                      style: TextStyle(
                                        color: AppColors.primaryDark,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Couple Hero Banner
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? [AppColors.surfaceDark, AppColors.surfaceSubtleDark]
                                : [AppColors.primaryLight, AppColors.surfaceLight],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.15),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.06),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Avatars together
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AppAvatar(
                                  photoUrl: user.photoUrl,
                                  name: user.displayName,
                                  radius: 34,
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 14.0),
                                  child: Icon(Icons.favorite_rounded, color: AppColors.primary, size: 28),
                                ),
                                AppAvatar(
                                  photoUrl: partner?.photoUrl,
                                  name: partner?.displayName ?? 'Partner',
                                  radius: 34,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '${user.displayName} & ${partner?.displayName ?? 'Partner'}',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$daysTogether hari bersama',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // PAP Box / Locket Widget
                      _buildPapWidget(context, ref, user, partner, isDark),
                      const SizedBox(height: 18),

                      // Live Radar & Tracking Quick Card
                      _buildTrackingQuickCard(context, ref, user, coupleId, isDark),
                      const SizedBox(height: 22),

                      // Quick Actions
                      Text(
                        'Aksi Cepat',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionCard(
                              context: context,
                              icon: Icons.chat_bubble_rounded,
                              label: 'Buka Chat',
                              onTap: () => context.go('/chat'),
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildActionCard(
                              context: context,
                              icon: Icons.radar_rounded,
                              label: 'Couple Radar',
                              onTap: () => context.go('/tracking'),
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildActionCard(
                              context: context,
                              icon: Icons.photo_library_rounded,
                              label: 'Kenangan',
                              onTap: () => context.go('/memories'),
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),

                      // Recent conversation snippet
                      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('conversations')
                            .doc('conv_$coupleId')
                            .snapshots(),
                        builder: (context, convSnap) {
                          final conv = convSnap.data?.data();
                          final lastMsg = conv?['lastMessage'] as String?;

                          return Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                              leading: const CircleAvatar(
                                backgroundColor: AppColors.primaryLight,
                                child: Icon(Icons.mark_chat_read_rounded, color: AppColors.primary),
                              ),
                              title: const Text('Pesan Terakhir', style: TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                lastMsg ?? 'Belum ada pesan.',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () => context.go('/chat'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// Live PAP widget on Home screen
  Widget _buildPapWidget(
    BuildContext context,
    WidgetRef ref,
    UserModel user,
    UserModel? partner,
    bool isDark,
  ) {
    final convId = 'conv_${user.coupleId}';

    return StreamBuilder<List<MessageModel>>(
      stream: ref.watch(chatRepositoryProvider).watchMessages(convId, limit: 15),
      builder: (context, snapshot) {
        final messages = snapshot.data ?? [];
        final papMessages = messages.where((m) => m.type == 'pap').toList();
        final latestPap = papMessages.isNotEmpty ? papMessages.first : null;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.camera_alt_rounded, color: AppColors.primary, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'PAP Terbaru Doi',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.add_a_photo_rounded, size: 16),
                    label: const Text('Kirim PAP'),
                    onPressed: () {
                      InAppMediaPicker.openPapCamera(
                        context: context,
                        onMediaSelected: (file, caption, type) async {
                          final url = await ref
                              .read(storageRepositoryProvider)
                              .uploadCouplePhoto(
                                coupleId: user.coupleId!,
                                file: file,
                                caption: caption,
                                type: 'pap',
                              );
                          await ref.read(chatRepositoryProvider).sendPapMessage(
                                conversationId: convId,
                                senderUid: user.uid,
                                mediaUrl: url,
                                caption: caption,
                              );
                          await ref
                              .read(notificationsRepositoryProvider)
                              .sendNotification(
                                coupleId: user.coupleId!,
                                senderUid: user.uid,
                                senderName: user.displayName,
                                title: '📸 PAP Baru dari ${user.displayName}!',
                                body: caption ?? 'Lihat fotonya sekarang 💕',
                                type: 'pap',
                              );
                        },
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (latestPap != null && latestPap.mediaUrl != null)
                GestureDetector(
                  onTap: () => context.go('/chat'),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AppImageView(
                          imageUrl: latestPap.mediaUrl!,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        bottom: 10,
                        left: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            latestPap.caption ?? 'PAP dari doi 💕',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  height: 110,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceSubtleDark : AppColors.surfaceSubtleLight,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.photo_camera_back_outlined, color: AppColors.primary, size: 28),
                        const SizedBox(height: 6),
                        const Text(
                          'Belum ada PAP hari ini',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Ketuk "Kirim PAP" untuk kirim foto ke doi!',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Live Radar & Tracking status card on Home screen with 1-tap Live Switch
  Widget _buildTrackingQuickCard(
    BuildContext context,
    WidgetRef ref,
    UserModel user,
    String coupleId,
    bool isDark,
  ) {
    final locationRepo = ref.watch(locationRepositoryProvider);

    return StreamBuilder<Map<String, LocationModel>>(
      stream: locationRepo.watchCoupleLocations(coupleId),
      builder: (context, snapshot) {
        final locs = snapshot.data ?? {};
        final myLoc = locs[user.uid];
        final partnerEntry = locs.entries.where((e) => e.key != user.uid);
        final partnerLoc = partnerEntry.isNotEmpty ? partnerEntry.first.value : null;

        final isLiveActive = (myLoc?.isLive == true) || locationRepo.isLiveSharing;

        String subtitleText;
        if (isLiveActive) {
          if (myLoc != null && partnerLoc != null) {
            subtitleText = '🟢 Live Tracking Aktif • ${myLoc.formattedDistanceTo(partnerLoc)}';
          } else {
            subtitleText = '🟢 Live Tracking Aktif • Posisi terkirim otomatis';
          }
        } else {
          subtitleText = partnerLoc != null
              ? 'Doi: ${partnerLoc.placeLabel ?? 'Terpantau'} (Ketuk switch untuk live)'
              : 'Nyalakan switch untuk live tracking otomatis';
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isLiveActive
                  ? [
                      const Color(0xFF163E2B),
                      isDark ? AppColors.surfaceDark : const Color(0xFFE8F7EE)
                    ]
                  : (isDark
                      ? [const Color(0xFF1E2838), AppColors.surfaceDark]
                      : [const Color(0xFFE8F7F5), AppColors.surfaceLight]),
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isLiveActive ? AppColors.success : const Color(0xFF2EC4B6).withValues(alpha: 0.3),
              width: isLiveActive ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              InkWell(
                onTap: () => context.go('/tracking'),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isLiveActive
                        ? AppColors.success.withValues(alpha: 0.2)
                        : const Color(0xFF2EC4B6).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isLiveActive ? Icons.sensors_rounded : Icons.radar_rounded,
                    color: isLiveActive ? AppColors.success : const Color(0xFF2EC4B6),
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => context.go('/tracking'),
                  borderRadius: BorderRadius.circular(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Live Location Sharing',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(width: 6),
                          if (isLiveActive)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.success,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'LIVE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitleText,
                        style: TextStyle(
                          color: isLiveActive ? AppColors.success : const Color(0xFF2EC4B6),
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Direct 1-tap Live Switch
              Switch.adaptive(
                value: isLiveActive,
                activeTrackColor: AppColors.success,
                onChanged: (enable) async {
                  if (enable) {
                    await locationRepo.startLiveSharing(
                      coupleId: coupleId,
                      uid: user.uid,
                      displayName: user.displayName,
                      photoUrl: user.photoUrl,
                    );
                    await ref.read(notificationsRepositoryProvider).sendNotification(
                          coupleId: coupleId,
                          senderUid: user.uid,
                          senderName: user.displayName,
                          title: '📍 ${user.displayName} menyalakan Live Location!',
                          body: 'Posisi doi sekarang terpantau langsung di Radar.',
                          type: 'location',
                        );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('🟢 Live Location Aktif! Posisi otomatis terkirim secara realtime.'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  } else {
                    await locationRepo.stopLiveSharing(
                      coupleId: coupleId,
                      uid: user.uid,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('⚪ Live Location Dimatikan.'),
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 26),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
