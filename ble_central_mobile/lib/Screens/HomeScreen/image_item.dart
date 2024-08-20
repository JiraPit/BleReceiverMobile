import 'dart:typed_data';

import 'package:flutter/material.dart';

class ImageItem extends StatelessWidget {
  const ImageItem({
    super.key,
    required this.imageData,
  });

  final Uint8List? imageData;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        image: imageData != null
            ? DecorationImage(
                image: MemoryImage(imageData!),
                fit: BoxFit.cover,
              )
            : null,
        color: Colors.grey,
      ),
    );
  }
}
