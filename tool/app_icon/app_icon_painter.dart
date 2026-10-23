import 'package:flutter/material.dart';

/// Draws the GastaDoor app icon: a piggy-bank house with a coin slot on
/// the roof, a door, a chimney with smoke, a snout, legs, and a curly tail.
///
/// All measurements are on a 1024 x 1024 grid and scale to any size.
/// Used by `render_app_icon_test.dart` to make the icon and splash images.
class AppIconPainter extends CustomPainter {
  const AppIconPainter({this.withBackground = true, this.scale = 1.0});

  /// Paint the green gradient square. Off = see-through background (for
  /// the splash screen and the Android "adaptive" foreground layer).
  final bool withBackground;

  /// 1.0 = the house fills the icon; smaller leaves more space around it.
  final double scale;

  static const green1 = Color(0xFF256B4D);
  static const green2 = Color(0xFF3A9B6F);
  static const greenDeep = Color(0xFF1B5A3F);
  static const snoutColor = Color(0xFFCDEBDA);
  static const gold = Color(0xFFF2B23A);

  static Paint gradient(Size s) => Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [green1, green2],
    ).createShader(Offset.zero & s);

  @override
  void paint(Canvas c, Size s) {
    final k = s.width / 1024;
    // A separate layer, so "gap" lines can cut through to transparent.
    c.saveLayer(Offset.zero & s, Paint());
    if (withBackground) c.drawRect(Offset.zero & s, gradient(s));

    // Put the middle of the house (feet to smoke) in the middle.
    c.translate(512 * k, 512 * k);
    c.scale(scale);
    c.translate(-549 * k, -520 * k);

    // Gaps (e.g. between roof and walls) are painted with the background,
    // or erased when there is no background.
    final gap = withBackground
        ? gradient(s)
        : (Paint()..blendMode = BlendMode.clear);
    _house(c, k, gap);
    c.restore();
  }

  void _house(Canvas c, double k, Paint gap) {
    Offset p(double x, double y) => Offset(x * k, y * k);
    final white = Paint()..color = Colors.white;
    final dark = Paint()..color = greenDeep;

    // Four stubby legs.
    for (final x in [330.0, 430.0, 594.0, 694.0]) {
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH((x - 34) * k, 770 * k, 68 * k, 92 * k),
          Radius.circular(22 * k),
        ),
        white,
      );
    }

    // Curly tail.
    final tail = Path()
      ..moveTo(784 * k, 640 * k)
      ..cubicTo(850 * k, 640 * k, 860 * k, 570 * k, 820 * k, 570 * k)
      ..cubicTo(790 * k, 570 * k, 792 * k, 616 * k, 826 * k, 612 * k)
      ..cubicTo(856 * k, 608 * k, 868 * k, 580 * k, 874 * k, 556 * k);
    c.drawPath(
      tail,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22 * k
        ..strokeCap = StrokeCap.round,
    );

    // Plump body (the walls).
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(250 * k, 470 * k, 774 * k, 812 * k),
        Radius.circular(120 * k),
      ),
      white,
    );

    // Chimney with a cap, and two puffs of smoke.
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(616 * k, 232 * k, 688 * k, 420 * k),
        Radius.circular(10 * k),
      ),
      white,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(600 * k, 214 * k, 704 * k, 252 * k),
        Radius.circular(10 * k),
      ),
      white,
    );
    for (final (x, y, r) in [(676.0, 168.0, 22.0), (716.0, 120.0, 30.0)]) {
      c.drawCircle(
        p(x, y),
        r * k,
        Paint()..color = Colors.white.withValues(alpha: 0.55),
      );
    }

    // Roof with rounded corners, plus a thin gap where it meets the walls
    // and chimney.
    final roof = Path()
      ..moveTo(p(512, 268).dx, p(512, 268).dy)
      ..lineTo(p(800, 482).dx, p(800, 482).dy)
      ..lineTo(p(224, 482).dx, p(224, 482).dy)
      ..close();
    c.drawPath(
      roof,
      Paint()
        ..shader = gap.shader
        ..blendMode = gap.blendMode
        ..style = PaintingStyle.stroke
        ..strokeWidth = 40 * k
        ..strokeJoin = StrokeJoin.round,
    );
    c.drawPath(roof, white);
    c.drawPath(
      roof,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 28 * k
        ..strokeJoin = StrokeJoin.round,
    );

    // Coin slot on the roof.
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(452 * k, 388 * k, 120 * k, 26 * k),
        Radius.circular(13 * k),
      ),
      dark,
    );

    // Arched door with a gold knob.
    final door = Rect.fromLTWH(452 * k, 600 * k, 120 * k, 212 * k);
    final rad = door.width / 2;
    c.drawPath(
      Path()
        ..moveTo(door.left, door.bottom)
        ..lineTo(door.left, door.top + rad)
        ..arcToPoint(
          Offset(door.right, door.top + rad),
          radius: Radius.circular(rad),
        )
        ..lineTo(door.right, door.bottom)
        ..close(),
      Paint()..color = green1,
    );
    c.drawCircle(p(546, 718), 10 * k, Paint()..color = gold);

    // Snout with nostrils, and an eye.
    c.drawOval(
      Rect.fromCenter(center: p(250, 640), width: 120 * k, height: 96 * k),
      Paint()..color = snoutColor,
    );
    for (final dx in [-20.0, 20.0]) {
      c.drawOval(
        Rect.fromCenter(center: p(250 + dx, 640), width: 16 * k, height: 26 * k),
        dark,
      );
    }
    c.drawCircle(p(352, 580), 14 * k, dark);
  }

  @override
  bool shouldRepaint(AppIconPainter old) =>
      old.withBackground != withBackground || old.scale != scale;
}
