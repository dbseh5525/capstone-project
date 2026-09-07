import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A single meal: lower the head, nibble with planted paws, then look up.
class FeedingDog extends StatefulWidget {
  const FeedingDog({
    super.key,
    required this.animation,
    required this.idleAsset,
    this.eatingAsset,
  });

  final Animation<double> animation;
  final String idleAsset;
  final String? eatingAsset;

  @override
  State<FeedingDog> createState() => _FeedingDogState();
}

class _FeedingDogState extends State<FeedingDog> {
  final Map<String, ImageInfo> _images = {};
  final Map<ImageStream, ImageStreamListener> _listeners = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_listeners.isNotEmpty) return;
    for (final asset in {widget.idleAsset, ?widget.eatingAsset}) {
      final stream = AssetImage(
        asset,
      ).resolve(createLocalImageConfiguration(context));
      final listener = ImageStreamListener((info, synchronousCall) {
        if (!mounted) {
          info.dispose();
          return;
        }
        setState(() {
          _images.remove(asset)?.dispose();
          _images[asset] = info;
        });
      });
      _listeners[stream] = listener;
      stream.addListener(listener);
    }
  }

  @override
  void dispose() {
    for (final entry in _listeners.entries) {
      entry.key.removeListener(entry.value);
    }
    for (final info in _images.values) {
      info.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final idle = _images[widget.idleAsset]?.image;
    return SizedBox(
      width: 140,
      height: 140,
      child: idle == null
          ? Image.asset(widget.idleAsset)
          : CustomPaint(
              painter: _FeedingPainter(
                animation: widget.animation,
                idle: idle,
                eating: _images[widget.eatingAsset]?.image,
              ),
            ),
    );
  }
}

class _FeedingPainter extends CustomPainter {
  _FeedingPainter({required this.animation, required this.idle, this.eating})
    : super(repaint: animation);

  final Animation<double> animation;
  final ui.Image idle;
  final ui.Image? eating;

  double _smooth(double value) {
    final t = value.clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final progress = animation.value;
    final lowering = _smooth(progress / .18);
    final lifting = _smooth((progress - .80) / .20);
    final bend = lowering * (1 - lifting);
    final chewing =
        _smooth((progress - .18) / .06) * (1 - _smooth((progress - .74) / .06));
    final nibble = math.sin((progress - .18) * math.pi * 24) * chewing;
    // Briefly blend the original poses without stretching the head or neck.
    final mix = eating == null ? 0.0 : _smooth((bend - .70) / .25);
    canvas.save();
    canvas.scale(size.width / 140, size.height / 140);
    if (mix < 1) {
      _drawPose(
        canvas,
        idle,
        const Rect.fromLTWH(0, 0, 140, 140),
        1 - mix,
        nibble,
        false,
      );
    }
    if (mix > 0) {
      // Match the new cutout's body width and paw baseline to the idle sprite.
      _drawPose(
        canvas,
        eating!,
        const Rect.fromLTWH(30, 54, 88, 59),
        mix,
        nibble * 1.3,
        true,
      );
    }
    canvas.restore();
  }

  void _drawPose(
    Canvas canvas,
    ui.Image image,
    Rect rect,
    double opacity,
    double headOffset,
    bool lowered,
  ) {
    const cells = 24;
    final positions = <Offset>[];
    final texture = <Offset>[];
    final indices = <int>[];
    for (var row = 0; row <= cells; row++) {
      final y = row / cells;
      for (var column = 0; column <= cells; column++) {
        final x = column / cells;
        // Smooth head-only deformation. Tail, torso and paw baseline stay put.
        final head =
            _smooth((x - .43) / .20) *
            (1 - _smooth((y - (lowered ? .83 : .69)) / .12));
        positions.add(
          Offset(
            rect.left + x * rect.width,
            rect.top + y * rect.height + headOffset * head,
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
    canvas.saveLayer(
      null,
      Paint()..color = Colors.white.withValues(alpha: opacity),
    );
    canvas.drawVertices(vertices, BlendMode.srcOver, paint);
    canvas.restore();
    vertices.dispose();
  }

  @override
  bool shouldRepaint(_FeedingPainter oldDelegate) =>
      idle != oldDelegate.idle ||
      eating != oldDelegate.eating ||
      animation != oldDelegate.animation;
}
