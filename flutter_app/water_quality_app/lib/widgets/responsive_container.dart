import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Centers content and caps its width on large screens (tablet/desktop/web)
/// so layouts don't stretch into unreadable single-column sprawl, while
/// remaining full-width and edge-to-edge on phones.
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsets? padding;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = 720,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ?? EdgeInsets.zero,
          child: child,
        ),
      ),
    );
  }
}

/// Returns the number of grid columns to use for reading tiles based on
/// available width — 2 on phones, more on tablets/desktop.
int readingGridColumns(double width) {
  if (width >= AppBreakpoints.medium) return 4;
  if (width >= AppBreakpoints.compact) return 3;
  return 2;
}

bool isCompactWidth(double width) => width < AppBreakpoints.compact;
