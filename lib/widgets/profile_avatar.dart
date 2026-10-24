import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    this.imageBytes,
    this.imageUrl,
    this.onTap,
    this.isRequired = false,
    this.compact = false,
  });

  final Uint8List? imageBytes;
  final String? imageUrl;
  final VoidCallback? onTap;
  final bool isRequired;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Semantics(
          button: onTap != null,
          label: imageBytes == null && (imageUrl?.isEmpty ?? true)
              ? 'Add profile photo'
              : 'Change profile photo',
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: compact ? 28 : 45,
                  backgroundColor: const Color(0xFFF0F0F0),
                  backgroundImage: imageBytes != null
                      ? MemoryImage(imageBytes!)
                      : imageUrl != null && imageUrl!.isNotEmpty
                      ? NetworkImage(imageUrl!)
                      : null,
                  child: imageBytes == null && (imageUrl?.isEmpty ?? true)
                      ? Icon(
                          Icons.person,
                          color: Color(0xFFAAAAAA),
                          size: compact ? 34 : 58,
                        )
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 4,
                  child: Container(
                    width: compact ? 23 : 32,
                    height: compact ? 23 : 32,
                    decoration: BoxDecoration(
                      color: kBrown,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: Icon(
                      Icons.edit_square,
                      color: Colors.white,
                      size: compact ? 12 : 17,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isRequired &&
            imageBytes == null &&
            (imageUrl?.isEmpty ?? true)) ...[
          const SizedBox(height: 6),
          const Text(
            'Add a clear professional photo',
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ],
    );
  }
}
