import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Django'dan gelen harita ve içerik görselleri için önbellekli gösterim.
class CachedRemoteImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final String? semanticLabel;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const CachedRemoteImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.semanticLabel,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    Widget image = CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      filterQuality: FilterQuality.high,
      fadeInDuration: const Duration(milliseconds: 180),
      placeholder: (_, __) => const _ImageShimmer(),
      errorWidget: (_, __, ___) => const _ImagePlaceholder(),
    );
    if (semanticLabel != null) {
      image = Semantics(label: semanticLabel, image: true, child: image);
    }
    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }
}

class _ImageShimmer extends StatefulWidget {
  const _ImageShimmer();

  @override
  State<_ImageShimmer> createState() => _ImageShimmerState();
}

class _ImageShimmerState extends State<_ImageShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-1.6 + _controller.value * 2.4, 0),
            end: Alignment(-0.6 + _controller.value * 2.4, 0),
            colors: const [
              Color(0xFFE7E9ED),
              Color(0xFFF7F8FA),
              Color(0xFFE7E9ED),
            ],
          ),
        ),
        child: const Center(
          child: Icon(Icons.image_outlined, color: Color(0x665A6578)),
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFF2F4F7),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined, color: Color(0x995A6578)),
            SizedBox(height: 6),
            Text(
              'Görsel yüklenemedi',
              style: TextStyle(color: Color(0xFF5A6578), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
