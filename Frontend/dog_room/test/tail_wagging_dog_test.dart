import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dog_room/widgets/tail_wagging_dog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('꼬리만 움직이고 얼굴과 몸통 픽셀은 그대로 유지된다', (tester) async {
    final animation = AnimationController(vsync: tester);
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: key,
            child: TailWaggingDog(
              asset: 'assets/dog/baby_idle.png',
              animation: animation,
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/dog/baby_idle.png'),
        key.currentContext!,
      );
    });
    await tester.pump();

    Future<Uint8List> pixels(double value) async {
      animation.value = value;
      await tester.pump();
      return (await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        final bytes = Uint8List.fromList(data!.buffer.asUint8List());
        image.dispose();
        return bytes;
      }))!;
    }

    final left = await pixels(.125);
    final right = await pixels(.375);
    var tailChanges = 0;
    var bodyChanges = 0;
    for (var y = 0; y < 140; y++) {
      for (var x = 0; x < 140; x++) {
        final i = (y * 140 + x) * 4;
        final changed = List.generate(
          4,
          (channel) => left[i + channel] != right[i + channel],
        ).any((v) => v);
        if (!changed) continue;
        if (x >= 65 || y >= 96) {
          bodyChanges++;
        } else {
          tailChanges++;
        }
      }
    }
    expect(bodyChanges, 0);
    expect(tailChanges, greaterThan(0));
    await tester.pumpWidget(const SizedBox());
    animation.dispose();
  });
}
