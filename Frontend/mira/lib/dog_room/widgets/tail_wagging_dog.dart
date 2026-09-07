import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Warps only the tail of one sprite so the face, torso and paws stay still.
class TailWaggingDog extends StatefulWidget {
  const TailWaggingDog({
    super.key,
    required this.asset,
    required this.animation,
  });

  final String asset;
  final Animation<double> animation;

  @override
  State<TailWaggingDog> createState() => _TailWaggingDogState();
}

class _TailWaggingDogState extends State<TailWaggingDog> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ImageInfo? _image;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_stream != null) return;
    _stream = AssetImage(
      widget.asset,
    ).resolve(createLocalImageConfiguration(context));
    _listener = ImageStreamListener((info, _) {
      if (!mounted) {
        info.dispose();
        return;
      }
      setState(() {
        _image?.dispose();
        _image = info;
      });
    });
    _stream!.addListener(_listener!);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener!);
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 140,
    height: 140,
    child: _image == null
        ? Image.asset(widget.asset)
        : CustomPaint(painter: _TailPainter(_image!.image, widget.animation)),
  );
}

class _TailPainter extends CustomPainter {
  _TailPainter(this.image, this.animation) : super(repaint: animation);

  final ui.Image image;
  final Animation<double> animation;

  double _smooth(double value) {
    final t = value.clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  @override
  void paint(Canvas canvas, Size size) {
    const cells = 32;
    final positions = <Offset>[];
    final texture = <Offset>[];
    final indices = <int>[];
    final wag = math.sin(animation.value * math.pi * 4) * .22;
    for (var row = 0; row <= cells; row++) {
      final y = row / cells;
      for (var column = 0; column <= cells; column++) {
        final x = column / cells;
        // Feather the rotation into the tail root; no motion beyond this area.
        final weight =
            (1 - _smooth((x - .33) / .10)) *
            _smooth((y - .36) / .07) *
            (1 - _smooth((y - .60) / .06));
        final angle = wag * weight;
        final dx = x - .39;
        final dy = y - .61;
        positions.add(
          Offset(
            (.39 + dx * math.cos(angle) - dy * math.sin(angle)) * size.width,
            (.61 + dx * math.sin(angle) + dy * math.cos(angle)) * size.height,
          ),
        );
        texture.add(Offset(x * image.width, y * image.height));
        if (row < cells && column < cells) {
          final i = row * (cells + 1) + column;
          indices.addAll([
            i,
            i + 1,
            i + cells + 1,
            i + 1,
            i + cells + 2,
            i + cells + 1,
          ]);
        }
      }
    }
    final vertices = ui.Vertices(
      ui.VertexMode.triangles,
      positions,
      textureCoordinates: texture,
      indices: indices,
    );
    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..shader = ui.ImageShader(
        image,
        TileMode.clamp,
        TileMode.clamp,
        Float64List.fromList([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]),
      );
    canvas.drawVertices(vertices, BlendMode.srcOver, paint);
    vertices.dispose();
  }

  @override
  bool shouldRepaint(_TailPainter oldDelegate) =>
      image != oldDelegate.image || animation != oldDelegate.animation;
}
