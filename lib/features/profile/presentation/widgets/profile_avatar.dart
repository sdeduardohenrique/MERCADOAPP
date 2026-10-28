import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Avatar circular com fallback para iniciais.
///
/// Usado no card do Perfil e na modal de edição, garantindo o mesmo visual
/// quando o usuário ainda não enviou foto.
class ProfileAvatar extends StatelessWidget {
  final String initials;
  final String? imageUrl;
  final double size;
  final Color backgroundColor;
  final Color textColor;
  final Color borderColor;
  final double? fontSize;

  const ProfileAvatar({
    super.key,
    required this.initials,
    this.imageUrl,
    this.size = 62,
    this.backgroundColor = const Color(0x33FFFFFF),
    this.textColor = Colors.white,
    this.borderColor = const Color(0x66FFFFFF),
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: backgroundColor,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: textColor,
          fontSize: fontSize ?? size * 0.34,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    final url = imageUrl?.trim();

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
      ),
      child: url == null || url.isEmpty
          ? fallback
          : CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (_, __) => fallback,
              errorWidget: (_, __, ___) => fallback,
              fadeInDuration: const Duration(milliseconds: 180),
            ),
    );
  }
}
