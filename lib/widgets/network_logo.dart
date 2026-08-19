import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Ağdan logo/görsel — disk cache ile (telefonda tekrar indirmez).
class NetworkLogo extends StatelessWidget {
  final String? url;
  final double width;
  final double height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? fallback;
  final bool circular;

  const NetworkLogo({
    super.key,
    required this.url,
    this.width = 40,
    this.height = 40,
    this.fit = BoxFit.contain,
    this.borderRadius,
    this.fallback,
    this.circular = false,
  });

  @override
  Widget build(BuildContext context) {
    final u = (url ?? '').trim();
    if (u.isEmpty) return _fallback();

    Widget image = CachedNetworkImage(
      imageUrl: u,
      width: width,
      height: height,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 150),
      fadeOutDuration: const Duration(milliseconds: 100),
      memCacheWidth: (width * 3).round().clamp(48, 512),
      memCacheHeight: (height * 3).round().clamp(48, 512),
      placeholder: (_, _) => SizedBox(
        width: width,
        height: height,
        child: Center(
          child: SizedBox(
            width: width * 0.35,
            height: width * 0.35,
            child: const CircularProgressIndicator(strokeWidth: 1.5),
          ),
        ),
      ),
      errorWidget: (_, _, _) => _fallback(),
    );

    if (circular) {
      return ClipOval(child: image);
    }
    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }

  Widget _fallback() {
    if (fallback != null) return fallback!;
    return SizedBox(
      width: width,
      height: height,
      child: Icon(
        Icons.shield,
        size: width * 0.55,
        color: AppTheme.hintColor,
      ),
    );
  }
}