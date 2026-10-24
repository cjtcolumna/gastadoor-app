import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../domain/account.dart';
import '../domain/pocket_goal.dart';
import 'pocket_visuals.dart';

/// The biggest a bubble gets, so they don't look huge on wide screens.
const _maxBubble = 116.0;
const _ringWidth = 7.0;

/// One sub-account as a round bubble: its icon in the middle, and a ring
/// around it that fills up as you save toward the goal. Under it: the
/// name, the balance, and "35% of ₱20,000" (or "No goal").
class PocketBubble extends StatelessWidget {
  const PocketBubble({
    super.key,
    required this.pocket,
    required this.balanceCents,
    this.onTap,
  });

  final Account pocket;
  final int balanceCents;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final goal = pocket.goalCents;
    final reached = goalReached(balanceCents, goal);
    final progressText = goalText(balanceCents, goal);

    return Semantics(
      button: true,
      label: '${pocket.name}, ${Money.format(balanceCents)}, $progressText',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final size = math.min(constraints.maxWidth, _maxBubble);
                  return _Ring(
                    size: size,
                    progress: goalProgress(balanceCents, goal),
                    hasGoal: goal != null,
                    reached: reached,
                    icon: pocketIconFor(pocket.icon),
                  );
                },
              ),
              const SizedBox(height: 10),
              Text(
                pocket.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              // Shrinks a little instead of splitting the number in two.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  Money.format(balanceCents),
                  maxLines: 1,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: balanceCents < 0 ? colors.expense : null,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                progressText,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: reached
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: reached ? FontWeight.w700 : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The circle: a ring that fills clockwise from the top, the icon on a
/// soft green disc, and a check mark badge when the goal is reached.
class _Ring extends StatelessWidget {
  const _Ring({
    required this.size,
    required this.progress,
    required this.hasGoal,
    required this.reached,
    required this.icon,
  });

  final double size;
  final double progress;
  final bool hasGoal;
  final bool reached;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final green = theme.colorScheme.primary;
    final soft = context.appColors.incomeSoft;
    // Fill the ring smoothly when the page opens, unless the phone has
    // animations turned off.
    final still = MediaQuery.disableAnimationsOf(context);
    // The disc sits inside the ring with a small gap.
    final disc = size - 2 * (_ringWidth + 6);

    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: still ? Duration.zero : const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => CustomPaint(
              size: Size.square(size),
              painter: GoalRingPainter(
                progress: value,
                hasGoal: hasGoal,
                fillColor: green,
                trackColor: hasGoal ? soft : theme.colorScheme.outlineVariant,
              ),
            ),
          ),
          Container(
            width: disc,
            height: disc,
            decoration: BoxDecoration(color: soft, shape: BoxShape.circle),
            child: Icon(icon, color: green, size: disc * 0.45),
          ),
          if (reached)
            Positioned(
              right: size * 0.04,
              bottom: size * 0.04,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: green,
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.cardColor, width: 2),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Draws the ring. With a goal: a soft green track plus a darker arc for
/// the part saved. Without a goal: just a thin grey outline.
class GoalRingPainter extends CustomPainter {
  const GoalRingPainter({
    required this.progress,
    required this.hasGoal,
    required this.fillColor,
    required this.trackColor,
  });

  /// 0.0 = nothing saved yet, 1.0 = goal reached.
  final double progress;
  final bool hasGoal;
  final Color fillColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final width = hasGoal ? _ringWidth : 2.0;
    // Keep the stroke inside the box (strokes are centered on the line).
    final rect = Rect.fromLTWH(
      0,
      0,
      size.width,
      size.height,
    ).deflate(_ringWidth / 2);

    canvas.drawOval(
      rect,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = width,
    );

    if (!hasGoal || progress <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2, // start at 12 o'clock
      2 * math.pi * progress.clamp(0, 1), // go clockwise
      false,
      Paint()
        ..color = fillColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = _ringWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(GoalRingPainter old) =>
      old.progress != progress ||
      old.hasGoal != hasGoal ||
      old.fillColor != fillColor ||
      old.trackColor != trackColor;
}

/// The last bubble: a dashed circle with a +, for adding a sub-account.
class AddPocketBubble extends StatelessWidget {
  const AddPocketBubble({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final green = theme.colorScheme.primary;

    return Semantics(
      button: true,
      label: 'Add sub-account',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final size = math.min(constraints.maxWidth, _maxBubble);
                  return CustomPaint(
                    size: Size.square(size),
                    painter: _DashedCirclePainter(green.withValues(alpha: 0.6)),
                    child: SizedBox.square(
                      dimension: size,
                      child: Icon(
                        Icons.add_rounded,
                        color: green,
                        size: size * 0.3,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              Text(
                'Add sub-account',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: green,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height).deflate(2);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    // 24 short dashes around the circle.
    const dashes = 24;
    const step = 2 * math.pi / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect, i * step, step * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter old) => old.color != color;
}
