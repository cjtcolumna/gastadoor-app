import 'package:flutter/material.dart';

/// Gently fades its child in and out, so grey placeholder shapes look like
/// "loading". People who turned off animations on their phone get a
/// still version.
class SkeletonPulse extends StatefulWidget {
  const SkeletonPulse({super.key, required this.child});

  final Widget child;

  @override
  State<SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<SkeletonPulse>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.45,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return FadeTransition(opacity: _controller, child: widget.child);
  }
}

/// A rounded grey block standing in for text or a picture.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height = 14, this.radius = 8});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// A card of placeholder rows shaped like the app's list rows:
/// a circle, a title line, a shorter line under it, and an amount.
class SkeletonListCard extends StatelessWidget {
  const SkeletonListCard({super.key, this.rows = 4});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: SkeletonPulse(
        child: Card(
          child: Column(
            children: [
              for (var i = 0; i < rows; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      const SkeletonBox(width: 40, height: 40, radius: 20),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Vary the widths a little so it looks natural.
                            FractionallySizedBox(
                              widthFactor: i.isEven ? 0.6 : 0.45,
                              child: const SkeletonBox(),
                            ),
                            const SizedBox(height: 8),
                            const FractionallySizedBox(
                              widthFactor: 0.35,
                              child: SkeletonBox(height: 10),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      const SkeletonBox(width: 64),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A full-screen loading placeholder: a few grey cards in a list.
class SkeletonPage extends StatelessWidget {
  const SkeletonPage({super.key, this.cards = 2, this.padding});

  final int cards;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: padding ?? const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        for (var i = 0; i < cards; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          SkeletonListCard(rows: i == 0 ? 4 : 3),
        ],
      ],
    );
  }
}
