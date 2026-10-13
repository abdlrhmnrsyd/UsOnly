import 'dart:convert';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';

class AppImageView extends StatelessWidget {
  final String? imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  const AppImageView({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    Widget child;

    if (imageUrl == null || imageUrl!.isEmpty) {
      child = _defaultPlaceholder();
    } else if (imageUrl!.startsWith('data:image') || _isLikelyBase64(imageUrl!)) {
      try {
        final rawBase64 = imageUrl!.contains(',')
            ? imageUrl!.split(',').last
            : imageUrl!;
        final Uint8List bytes = base64Decode(rawBase64.trim());
        child = Image.memory(
          bytes,
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (context, error, stackTrace) => errorWidget ?? _defaultError(),
        );
      } catch (e) {
        child = errorWidget ?? _defaultError();
      }
    } else {
      child = CachedNetworkImage(
        imageUrl: imageUrl!,
        fit: fit,
        width: width,
        height: height,
        placeholder: (context, url) =>
            placeholder ??
            Container(
              color: AppColors.primaryLight.withValues(alpha: 0.3),
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        errorWidget: (context, url, error) => errorWidget ?? _defaultError(),
      );
    }

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: child,
      );
    }

    return child;
  }

  bool _isLikelyBase64(String str) {
    if (str.startsWith('http://') || str.startsWith('https://')) return false;
    return str.length > 100 && !str.contains(' ');
  }

  Widget _defaultPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: AppColors.primaryLight.withValues(alpha: 0.3),
      child: const Icon(Icons.image_outlined, color: AppColors.primary),
    );
  }

  Widget _defaultError() {
    return Container(
      width: width,
      height: height,
      color: AppColors.primaryLight.withValues(alpha: 0.2),
      child: const Icon(Icons.broken_image_rounded, color: AppColors.primary),
    );
  }
}

class AppAvatar extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final double radius;
  final VoidCallback? onTap;

  const AppAvatar({
    super.key,
    required this.photoUrl,
    required this.name,
    this.radius = 24,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = GestureDetector(
      onTap: onTap,
      child: CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.primaryLight,
        child: ClipOval(
          child: photoUrl != null && photoUrl!.isNotEmpty
              ? AppImageView(
                  imageUrl: photoUrl,
                  width: radius * 2,
                  height: radius * 2,
                  fit: BoxFit.cover,
                  errorWidget: _fallbackLetter(),
                )
              : _fallbackLetter(),
        ),
      ),
    );

    return avatar;
  }

  Widget _fallbackLetter() {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: radius * 0.8,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
