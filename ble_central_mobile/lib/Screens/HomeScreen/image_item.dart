import 'dart:typed_data';

import 'package:flutter/material.dart';

class ImageItem extends StatelessWidget {
  const ImageItem({
    super.key,
    required Uint8List? imageData,
  }) : _imageData = imageData;

  final Uint8List? _imageData;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      width: 150,
      decoration: BoxDecoration(
        image: _imageData != null
            ? DecorationImage(
                image: MemoryImage(_imageData),
                fit: BoxFit.cover,
              )
            : null,
        color: Colors.grey,
      ),
    );
  }
}
