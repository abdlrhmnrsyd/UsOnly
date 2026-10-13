import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../app/theme/app_colors.dart';
import '../../auth/domain/auth_state.dart';
import '../data/notifications_repository.dart';
import '../domain/notification_model.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).user;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (user == null || user.coupleId == null) {
      return const Scaffold(
        body: Center(child: Text('Belum terhubung dengan pasangan.')),
      );
    }

    final coupleId = user.coupleId!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aktivitas & Notifikasi'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Tandai sudah dibaca',
            icon: const Icon(Icons.done_all_rounded),
            onPressed: () {
              ref
                  .read(notificationsRepositoryProvider)
                  .markAllAsRead(coupleId, user.uid);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Quick Interaction Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: _buildQuickActionButton(
                    icon: Icons.favorite_rounded,
                    label: 'Kangen Kamu',
                    color: AppColors.primary,
                    onTap: () async {
                      await ref
                          .read(notificationsRepositoryProvider)
                          .sendNotification(
                            coupleId: coupleId,
                            senderUid: user.uid,
                            senderName: user.displayName,
                            title: '❤️ ${user.displayName} lagi kangen!',
                            body: 'Doi baru saja mengirimkan pelukan virtual untukmu.',
                            type: 'miss_you',
                          );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Sinyal kangen terkirim ke doi! 💕')),
                        );
                      }
                    },
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildQuickActionButton(
                    icon: Icons.camera_alt_rounded,
                    label: 'Minta PAP',
                    color: const Color(0xFF6C63FF),
                    onTap: () async {
                      await ref
                          .read(notificationsRepositoryProvider)
                          .sendNotification(
                            coupleId: coupleId,
                            senderUid: user.uid,
                            senderName: user.displayName,
                            title: '📸 Minta PAP dong!',
                            body: '${user.displayName} ingin lihat foto kamu sekarang.',
                            type: 'pap',
                          );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Permintaan PAP terkirim ke doi! 📸')),
                        );
                      }
                    },
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildQuickActionButton(
                    icon: Icons.location_on_rounded,
                    label: 'Minta Lokasi',
                    color: const Color(0xFF2EC4B6),
                    onTap: () async {
                      await ref
                          .read(notificationsRepositoryProvider)
                          .sendNotification(
                            coupleId: coupleId,
                            senderUid: user.uid,
                            senderName: user.displayName,
                            title: '📍 Lagi di mana nih?',
                            body: '${user.displayName} menanyakan lokasi terkini kamu.',
                            type: 'location',
                          );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Permintaan lokasi terkirim ke doi! 📍')),
                        );
                      }
                    },
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          // Notifications List
          Expanded(
            child: StreamBuilder<List<NotificationModel>>(
              stream: ref
                  .watch(notificationsRepositoryProvider)
                  .watchNotifications(coupleId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final notifs = snapshot.data ?? [];
                if (notifs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_none_rounded,
                          size: 56,
                          color: AppColors.primary.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Belum ada notifikasi.',
                          style: TextStyle(
                            fontSize: 16,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Kirim sinyal kangen atau minta PAP ke doi!',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: notifs.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = notifs[index];
                    final isFromMe = item.senderUid == user.uid;

                    return Card(
                      elevation: item.isRead ? 0 : 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: item.isRead
                              ? (isDark ? AppColors.dividerDark : AppColors.dividerLight)
                              : AppColors.primary.withValues(alpha: 0.4),
                          width: item.isRead ? 1 : 1.5,
                        ),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getColorForType(item.type).withValues(alpha: 0.15),
                          child: Icon(
                            _getIconForType(item.type),
                            color: _getColorForType(item.type),
                            size: 20,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                style: TextStyle(
                                  fontWeight: item.isRead ? FontWeight.w600 : FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            if (!item.isRead && !isFromMe)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            Text(
                              item.body,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('dd MMM • HH:mm').format(item.createdAt),
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? AppColors.textSecondaryDark.withValues(alpha: 0.7)
                                    : AppColors.textSecondaryLight.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          if (!item.isRead && !isFromMe) {
                            ref
                                .read(notificationsRepositoryProvider)
                                .markAsRead(coupleId, item.id);
                          }
                          if (item.type == 'location') {
                            context.go('/tracking');
                          } else {
                            context.go('/chat');
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'pap':
        return Icons.camera_alt_rounded;
      case 'location':
        return Icons.location_on_rounded;
      case 'miss_you':
        return Icons.favorite_rounded;
      default:
        return Icons.mark_chat_unread_rounded;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'pap':
        return AppColors.primary;
      case 'location':
        return const Color(0xFF2EC4B6);
      case 'miss_you':
        return AppColors.heart;
      default:
        return const Color(0xFF6C63FF);
    }
  }
}
