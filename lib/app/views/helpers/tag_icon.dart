import 'dart:io';
import 'package:flutter/material.dart';
import 'package:test_app/app/models/tag.dart';
import 'package:test_app/app/views/helpers/tag_icon_mapper.dart';

class TagIcon extends StatelessWidget {
  final Tag tag;
  final double radius;

  const TagIcon({super.key, required this.tag, this.radius = 20.0});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: HSLColor.fromColor(tag.color)
          .withLightness(
            (HSLColor.fromColor(tag.color).lightness * 0.8).clamp(0.0, 1.0),
          )
          .toColor()
          .withOpacity(0.2),

      backgroundImage: tag.imagePath != null
          ? FileImage(File(tag.imagePath!))
          : null,

      child: Builder(
        builder: (context) {
          if (tag.imagePath != null) {
            return const SizedBox.shrink();
          }

          if (tag.iconName != null) {
            return Icon(
              getIconForTag(tag.iconName!),
              color: tag.color,
              size: radius,
            );
          }

          return Text(
            tag.name.isNotEmpty ? tag.name[0].toUpperCase() : '?',
            style: TextStyle(
              color: tag.color,
              fontWeight: FontWeight.bold,
              fontSize: radius,
            ),
          );
        },
      ),
    );
  }
}
