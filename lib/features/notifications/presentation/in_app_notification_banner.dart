import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../auth/domain/auth_state.dart';
import '../data/notifications_repository.dart';
import '../domain/notification_model.dart';

class InAppNotificationBanner extends ConsumerStatefulWidget {
  final Widget child;

  const InAppNotificationBanner({super.key, required this.child});

  @override
  ConsumerState<InAppNotificationBanner> createState() => _InAppNotificationBannerState();
}

class _InAppNotificationBannerState extends ConsumerState<InAppNotificationBanner>
    with SingleTickerProviderStateMixin {
  StreamSubscription<List<NotificationModel>>? _sub;
  NotificationModel? _activeNotification;
  late AnimationController _animController;
  late Animation<Offset> _offsetAnim;
  final Set<String> _seenNotifIds = {};
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _offsetAnim = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInBack,
    ));
  }

  @override
  void dispose() {
    _sub?.cancel();
    _dismissTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _listenToNotifications(String coupleId, String currentUid) {
    _sub?.cancel();
    _sub = ref
        .read(notificationsRepositoryProvider)
        .watchNotifications(coupleId)
        .listen((notifs) {
      if (notifs.isEmpty) return;
      final latest = notifs.first;

      // Only show banner for new notifications from partner
      if (latest.senderUid != currentUid && !_seenNotifIds.contains(latest.id)) {
        _seenNotifIds.add(latest.id);

        // Check if created recently (within last 30 seconds)
        if (DateTime.now().difference(latest.createdAt).inSeconds < 30) {
          _showBanner(latest);
        }
      }
    }, onError: (e) {
      debugPrint('In-app notification banner stream notice: $e');
    });
  }

  void _showBanner(NotificationModel notif) {
    _dismissTimer?.cancel();
    setState(() {
      _activeNotification = notif;
    });
    _animController.forward();

    _dismissTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        _animController.reverse().then((_) {
          if (mounted) setState(() => _activeNotification = null);
        });
      }
    });
  }

  void _handleBannerTap() {
    if (_activeNotification == null) return;
    final type = _activeNotification!.type;
    _animController.reverse().then((_) {
      if (mounted) setState(() => _activeNotification = null);
    });

    if (type == 'location') {
      context.go('/tracking');
    } else {
      context.go('/chat');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).user;
    if (user != null && user.coupleId != null && _sub == null) {
      _listenToNotifications(user.coupleId!, user.uid);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        widget.child,
        if (_activeNotification != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: SlideTransition(
                position: _offsetAnim,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Material(
                    elevation: 10,
                    borderRadius: BorderRadius.circular(24),
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _handleBannerTap,
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? [AppColors.surfaceDark, AppColors.surfaceSubtleDark]
                                : [AppColors.surfaceLight, AppColors.primaryLight],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _getIconForType(_activeNotification!.type),
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _activeNotification!.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _activeNotification!.body,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? AppColors.textSecondaryDark
                                          : AppColors.textSecondaryLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
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
}
