import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../app/theme/app_colors.dart';
import '../../auth/domain/auth_state.dart';
import '../../media/data/storage_repository.dart';
import '../../media/presentation/app_image_view.dart';
import '../../media/presentation/in_app_media_picker.dart';
import '../../notifications/data/notifications_repository.dart';
import '../../tracking/data/location_repository.dart';
import '../data/chat_repository.dart';
import '../domain/message_model.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) => ChatRepository());
final storageRepositoryProvider = Provider<StorageRepository>((ref) => StorageRepository());

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(authStateProvider).user;
    if (user == null || user.coupleId == null) return;

    _textController.clear();
    final convId = 'conv_${user.coupleId}';

    try {
      await ref.read(chatRepositoryProvider).sendTextMessage(
            conversationId: convId,
            senderUid: user.uid,
            text: text,
          );

      // Trigger notification
      await ref.read(notificationsRepositoryProvider).sendNotification(
            coupleId: user.coupleId!,
            senderUid: user.uid,
            senderName: user.displayName,
            title: '💬 Pesan dari ${user.displayName}',
            body: text,
            type: 'chat',
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengirim pesan: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleMediaSelected(File file, String? caption, String type) async {
    final user = ref.read(authStateProvider).user;
    if (user == null || user.coupleId == null) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      // Direct Firestore upload without Firebase Storage bucket!
      final url = await ref.read(storageRepositoryProvider).uploadCouplePhoto(
            coupleId: user.coupleId!,
            file: file,
            caption: caption,
            type: type,
            onProgress: (p) => setState(() => _uploadProgress = p),
          );

      final convId = 'conv_${user.coupleId}';

      if (type == 'pap') {
        await ref.read(chatRepositoryProvider).sendPapMessage(
              conversationId: convId,
              senderUid: user.uid,
              mediaUrl: url,
              caption: caption,
            );

        await ref.read(notificationsRepositoryProvider).sendNotification(
              coupleId: user.coupleId!,
              senderUid: user.uid,
              senderName: user.displayName,
              title: '📸 ${user.displayName} mengirim PAP baru!',
              body: caption?.isNotEmpty == true ? caption! : 'Buka untuk melihat fotonya.',
              type: 'pap',
            );
      } else {
        await ref.read(chatRepositoryProvider).sendImageMessage(
              conversationId: convId,
              senderUid: user.uid,
              mediaUrl: url,
              caption: caption,
            );

        await ref.read(notificationsRepositoryProvider).sendNotification(
              coupleId: user.coupleId!,
              senderUid: user.uid,
              senderName: user.displayName,
              title: '🖼️ ${user.displayName} mengirim foto',
              body: caption?.isNotEmpty == true ? caption! : 'Foto kenangan baru.',
              type: 'chat',
            );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengirim foto/PAP: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _shareCurrentLocation() async {
    final user = ref.read(authStateProvider).user;
    if (user == null || user.coupleId == null) return;

    try {
      final loc = await ref.read(locationRepositoryProvider).updateLocation(
            coupleId: user.coupleId!,
            uid: user.uid,
            displayName: user.displayName,
            photoUrl: user.photoUrl,
            placeLabel: 'Lokasi saat ini 📍',
          );

      if (loc != null) {
        final convId = 'conv_${user.coupleId}';
        await ref.read(chatRepositoryProvider).sendLocationMessage(
              conversationId: convId,
              senderUid: user.uid,
              latitude: loc.latitude,
              longitude: loc.longitude,
              placeLabel: loc.placeLabel,
            );

        await ref.read(notificationsRepositoryProvider).sendNotification(
              coupleId: user.coupleId!,
              senderUid: user.uid,
              senderName: user.displayName,
              title: '📍 ${user.displayName} membagikan lokasi',
              body: 'Ketuk untuk melihat di Radar & Tracking.',
              type: 'location',
            );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal berbagi lokasi: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
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

    final convId = 'conv_${user.coupleId}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Our Conversation'),
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        elevation: 0.5,
        actions: [
          IconButton(
            tooltip: 'Radar & Tracking',
            icon: const Icon(Icons.radar_rounded, color: AppColors.primary),
            onPressed: () => context.go('/tracking'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isUploading)
            LinearProgressIndicator(
              value: _uploadProgress > 0 ? _uploadProgress : null,
              color: AppColors.primary,
              backgroundColor: AppColors.primaryLight,
            ),
          // Messages Stream
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: ref.watch(chatRepositoryProvider).watchMessages(convId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.favorite_border_rounded,
                          size: 48,
                          color: AppColors.primary.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'belum ada pesan.',
                          style: TextStyle(
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'kirim pesan manis atau kirim PAP sekarang.',
                          style: TextStyle(
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderUid == user.uid;

                    if (!isMe && !msg.isReadBy(user.uid)) {
                      ref.read(chatRepositoryProvider).markRead(
                            conversationId: convId,
                            messageId: msg.id,
                            readerUid: user.uid,
                          );
                    }

                    return _buildMessageBubble(msg, isMe, isDark);
                  },
                );
              },
            ),
          ),
          // Composer
          _buildComposer(isDark),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel msg, bool isMe, bool isDark) {
    final timeStr = DateFormat('HH:mm').format(msg.createdAt);

    if (msg.type == 'pap') {
      return _buildPapBubble(msg, isMe, isDark, timeStr);
    } else if (msg.type == 'location') {
      return _buildLocationBubble(msg, isMe, isDark, timeStr);
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMe
              ? AppColors.primary
              : (isDark ? AppColors.surfaceSubtleDark : AppColors.surfaceSubtleLight),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMe ? 20 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (msg.type == 'image' && msg.mediaUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AppImageView(
                  imageUrl: msg.mediaUrl!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 6),
            ],
            if (msg.text != null && msg.text!.isNotEmpty)
              Text(
                msg.text!,
                style: TextStyle(
                  color: isMe ? Colors.white : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                  fontSize: 15,
                  height: 1.3,
                ),
              ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 11,
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.8)
                        : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    msg.readBy.length > 1 ? Icons.done_all_rounded : Icons.done_rounded,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Aesthetic Polaroid-style PAP message bubble
  Widget _buildPapBubble(MessageModel msg, bool isMe, bool isDark, String timeStr) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // PAP Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.camera_alt_rounded, size: 12, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'PAP KILAT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Photo
            if (msg.mediaUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AppImageView(
                  imageUrl: msg.mediaUrl!,
                  height: 230,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            if (msg.caption != null && msg.caption!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                msg.caption!,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Location share message bubble
  Widget _buildLocationBubble(MessageModel msg, bool isMe, bool isDark, String timeStr) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe
              ? AppColors.primary
              : (isDark ? AppColors.surfaceSubtleDark : AppColors.surfaceSubtleLight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 6),
                Text(
                  'Lokasi Terkini',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isMe ? Colors.white : AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              msg.placeLabel ?? 'Sedang di lokasi ini 📍',
              style: TextStyle(
                fontSize: 14,
                color: isMe ? Colors.white : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                style: FilledButton.styleFrom(
                  backgroundColor: isMe ? Colors.white24 : AppColors.primaryLight,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                onPressed: () => context.go('/tracking'),
                child: Text(
                  'Lihat di Radar 🧭',
                  style: TextStyle(
                    color: isMe ? Colors.white : AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposer(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Prominent PAP Button (WhatsApp style in-app camera)
            InkWell(
              onTap: () => InAppMediaPicker.openPapCamera(
                context: context,
                onMediaSelected: _handleMediaSelected,
              ),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.camera_alt_rounded, color: AppColors.primary, size: 18),
                    SizedBox(width: 4),
                    Text(
                      'PAP',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.photo_library_rounded, color: AppColors.primary, size: 22),
              tooltip: 'Galeri Built-in',
              onPressed: () => InAppMediaPicker.openGalleryPicker(
                context: context,
                onMediaSelected: _handleMediaSelected,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary, size: 24),
              tooltip: 'Menu Lainnya',
              onPressed: () => InAppMediaPicker.show(
                context: context,
                onMediaSelected: _handleMediaSelected,
                onShareLocation: _shareCurrentLocation,
              ),
            ),
            Expanded(
              child: TextField(
                controller: _textController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Ketik pesan...',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.camera_alt_outlined, color: AppColors.primary, size: 20),
                    tooltip: 'Kamera Built-in',
                    onPressed: () => InAppMediaPicker.openCamera(
                      context: context,
                      onMediaSelected: _handleMediaSelected,
                    ),
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.send_rounded, color: AppColors.primary),
              onPressed: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}
