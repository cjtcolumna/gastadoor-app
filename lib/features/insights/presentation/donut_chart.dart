import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The space between two slices, in radians (about 2.3 degrees).
const _gap = 0.04;

/// How thick the ring is, compared with the chart's width.
const _thicknessRatio = 0.13;

/// A selected slice grows outward by this many pixels.
const _grow = 5.0;

/// Which slice a tap at [point] landed on, for a donut of [size] whose
/// slices are sized by [values] and start at 12 o'clock going clockwise.
///
/// Returns the slice's index, -1 for the hole in the middle, or null for
/// outside the ring.
int? donutSliceAt(Offset point, Size size, List<int> values) {
  final total = values.fold<int>(0, (sum, v) => sum + v);
  final offset = point - size.center(Offset.zero);
  final distance = offset.distance;
  final ringRadius = _ringRadius(size);
  final half = _thickness(size) / 2;
  // A few pixels of slack either side, so fingers don't have to be exact.
  if (distance < ringRadius - half - 6) return -1;
  if (distance > ringRadius + half + _grow + 6 || total == 0) return null;

  // Angle from 12 o'clock, clockwise, between 0 and 2π.
  var angle = math.atan2(offset.dy, offset.dx) + math.pi / 2;
  if (angle < 0) angle += 2 * math.pi;

  var start = 0.0;
  for (final (i, v) in values.indexed) {
    final sweep = 2 * math.pi * v / total;
    if (angle < start + sweep) return i;
    start += sweep;
  }
  return values.length - 1;
}

double _thickness(Size size) => size.shortestSide * _thicknessRatio;

/// The middle of the ring's stroke, leaving room for a slice to grow.
double _ringRadius(Size size) =>
    size.shortestSide / 2 - _thickness(size) / 2 - _grow;

/// A ring split into colored slices, with [center] in the hole.
/// Slices sweep in when it first appears (unless animations are off).
/// Tapping a slice calls [onSelect] with its index; tapping the hole
/// calls it with null.
class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.values,
    required this.colors,
    required this.trackColor,
    required this.center,
    this.selected,
    this.onSelect,
    this.semanticLabel,
  });

  /// Slice sizes (cents), in drawing order.
  final List<int> values;
  final List<Color> colors;

  /// The ring's color when there's nothing to show.
  final Color trackColor;
  final Widget center;
  final int? selected;
  final ValueChanged<int?>? onSelect;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size.square(constraints.maxWidth);
        final hole = (_ringRadius(size) - _thickness(size) / 2) * 2;
        return Semantics(
          label: semanticLabel,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: onSelect == null
                ? null
                : (details) {
                    final hit = donutSliceAt(
                      details.localPosition,
                      size,
                      values,
                    );
                    if (hit == null) return;
                    // Tapping the hole, or the same slice again, unselects.
                    onSelect!(hit == -1 || hit == selected ? null : hit);
                  },
            child: SizedBox.fromSize(
              size: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: still
                        ? Duration.zero
                        : const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (context, progress, _) => CustomPaint(
                      size: size,
                      painter: DonutPainter(
                        values: values,
                        colors: colors,
                        trackColor: trackColor,
                        selected: selected,
                        progress: progress,
                      ),
                    ),
                  ),
                  // Keep the text inside the hole.
                  SizedBox(width: hole * 0.78, child: center),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Draws the ring. A selected slice is thicker; the others fade back.
class DonutPainter extends CustomPainter {
  const DonutPainter({
    required this.values,
    required this.colors,
    required this.trackColor,
    this.selected,
    this.progress = 1,
  });

  final List<int> values;
  final List<Color> colors;
  final Color trackColor;
  final int? selected;

  /// 0..1: how much of the ring has swept in so far.
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final thickness = _thickness(size);
    final radius = _ringRadius(size);
    final center = size.center(Offset.zero);
    final total = values.fold<int>(0, (sum, v) => sum + v);

    if (total == 0) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = trackColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = thickness,
      );
      return;
    }

    final gap = values.length > 1 ? _gap : 0.0;
    final shown = 2 * math.pi * progress; // how far the sweep has got
    var start = 0.0;
    for (final (i, v) in values.indexed) {
      final sweep = 2 * math.pi * v / total;
      final from = start + gap / 2;
      final to = math.min(start + sweep - gap / 2, shown);
      start += sweep;
      if (to <= from) continue;

      final isSelected = i == selected;
      final faded = selected != null && !isSelected;
      final width = isSelected ? thickness + _grow * 2 : thickness;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        from - math.pi / 2, // 0 = 12 o'clock
        to - from,
        false,
        Paint()
          ..color = faded ? colors[i].withValues(alpha: 0.3) : colors[i]
          ..style = PaintingStyle.stroke
          ..strokeWidth = width,
      );
    }
  }

  @override
  bool shouldRepaint(DonutPainter old) =>
      old.progress != progress ||
      old.selected != selected ||
      old.trackColor != trackColor ||
      !_sameList(old.values, values) ||
      !_sameList(old.colors, colors);

  static bool _sameList<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
