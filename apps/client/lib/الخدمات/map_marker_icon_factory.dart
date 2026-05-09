import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapMarkerIconFactory {
  const MapMarkerIconFactory._();

  static Future<BitmapDescriptor> create({
    required IconData icon,
    required Color color,
    Color iconColor = Colors.white,
    double size = 112,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final rect = Rect.fromLTWH(0, 0, size, size);
    final center = Offset(size / 2, size * 0.42);
    final circleRadius = size * 0.31;

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(
        center.translate(0, size * 0.04), circleRadius, shadowPaint);

    final pinPath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: circleRadius))
      ..moveTo(size * 0.5, size * 0.98)
      ..quadraticBezierTo(size * 0.31, size * 0.70, size * 0.36, size * 0.55)
      ..lineTo(size * 0.64, size * 0.55)
      ..quadraticBezierTo(size * 0.69, size * 0.70, size * 0.5, size * 0.98)
      ..close();

    final pinPaint = Paint()..color = color;
    canvas.drawPath(pinPath, pinPaint);

    final highlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.045
      ..color = Colors.white.withValues(alpha: 0.85);
    canvas.drawCircle(center, circleRadius * 0.78, highlightPaint);

    final iconPainter = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          color: iconColor,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: size * 0.34,
        ),
      )
      ..layout();
    iconPainter.paint(
      canvas,
      center - Offset(iconPainter.width / 2, iconPainter.height / 2),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(rect.width.ceil(), rect.height.ceil());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final data = bytes?.buffer.asUint8List() ?? Uint8List(0);
    return BitmapDescriptor.bytes(data, width: size / 2, height: size / 2);
  }
}
