import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';

class GingaCachedImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final String? category; // Opcional, para estilizar el degradado

  const GingaCachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = 0.0,
    this.placeholder,
    this.errorWidget,
    this.category,
  });

  String _getCategoryBlurHash(String? category) {
    final catNorm = (category ?? '').trim().toLowerCase();
    if (catNorm.contains('ataque')) {
      return 'L6PZ|Ye.dCp000]y%gBx_NixRj%m'; // Green
    } else if (catNorm.contains('defensa')) {
      return 'L5H2EC=y00?G00ngObxo00Ry_~%L'; // Blue
    } else if (catNorm.contains('esquiva')) {
      return 'LJH2aH_2_3xZ~q?b-;of9F%M%Mxa'; // Purple
    } else if (catNorm.contains('floreo')) {
      return 'LNH2yG_3_3%M~q_2Mx-;4m%M%M%M'; // Orange
    } else if (catNorm.contains('fundamento') || catNorm.contains('ginga')) {
      return 'L48z4E004m_w_wt7t7_w00D%_1xa'; // Teal
    } else if (catNorm.contains('membresia') || catNorm.contains('tienda') || catNorm.contains('producto')) {
      return 'LKN]~^%hDh-p.gDUxaMj00%MIpkW'; // Gold/Amber
    } else if (catNorm.contains('ropa')) {
      return 'L6PZ|Ye.dCp000]y%gBx_NixRj%m'; // Green / Capoeira
    } else if (catNorm.contains('instrumentos')) {
      return 'LKN]~^%hDh-p.gDUxaMj00%MIpkW'; // Gold / Warm wood
    }
    return 'LEHV6nWB2yk8pyo0adR*.7kCMdnj'; // Default Gray
  }

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return _buildErrorWidget(context);
    }

    if (imageUrl.startsWith('assets/')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.asset(
          imageUrl,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _buildErrorWidget(context),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => placeholder ?? BlurHash(
          hash: _getCategoryBlurHash(category),
          imageFit: fit,
        ),
        errorWidget: (context, url, error) => errorWidget ?? _buildErrorWidget(context),
        fadeInDuration: const Duration(milliseconds: 300),
        fadeOutDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  Widget _buildErrorWidget(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: BlurHash(
            hash: _getCategoryBlurHash(category),
            imageFit: fit,
          ),
        ),
        Positioned.fill(
          child: Container(
            color: Colors.white.withOpacity(0.4),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _getCategoryIcon(category),
                    color: Colors.black54,
                    size: 24,
                  ),
                  if (category != null && category!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      category!.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }


  IconData _getCategoryIcon(String? category) {
    final catNorm = (category ?? '').trim().toLowerCase();
    if (catNorm.contains('ataque')) {
      return Icons.bolt;
    } else if (catNorm.contains('defensa')) {
      return Icons.shield_outlined;
    } else if (catNorm.contains('esquiva')) {
      return Icons.double_arrow_rounded;
    } else if (catNorm.contains('floreo')) {
      return Icons.auto_awesome;
    } else if (catNorm.contains('fundamento') || catNorm.contains('ginga')) {
      return Icons.menu_book_rounded;
    } else if (catNorm.contains('producto') || catNorm.contains('tienda') || catNorm.contains('membresia')) {
      return Icons.shopping_bag_outlined;
    } else if (catNorm.contains('evento') || catNorm.contains('taller')) {
      return Icons.sports_martial_arts;
    }
    return Icons.image_not_supported_outlined;
  }
}

