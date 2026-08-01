import 'package:flutter/widgets.dart';

/// Central breakpoints so every page agrees on what "mobile" / "tablet" /
/// "desktop" means, instead of each widget inventing its own thresholds.
class Breakpoints {
  const Breakpoints._();

  static const double mobile = 600;
  static const double tablet = 1024;
  static const double desktop = 1440;
}

enum ScreenSize { mobile, tablet, desktop, wide }

ScreenSize screenSizeOf(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width < Breakpoints.mobile) return ScreenSize.mobile;
  if (width < Breakpoints.tablet) return ScreenSize.tablet;
  if (width < Breakpoints.desktop) return ScreenSize.desktop;
  return ScreenSize.wide;
}

bool isMobile(BuildContext context) => screenSizeOf(context) == ScreenSize.mobile;

/// Centers content and caps its width on large screens so text lines and
/// card grids stay readable instead of stretching edge-to-edge on a 27"
/// monitor.
class MaxWidthBox extends StatelessWidget {
  const MaxWidthBox({super.key, required this.child, this.maxWidth = 1200, this.padding});

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 24),
          child: child,
        ),
      ),
    );
  }
}

/// Returns the number of grid columns appropriate for the current width —
/// used by the Research / Projects / Publications / Gallery grids.
int gridColumnsFor(BuildContext context) {
  switch (screenSizeOf(context)) {
    case ScreenSize.mobile:
      return 1;
    case ScreenSize.tablet:
      return 2;
    case ScreenSize.desktop:
    case ScreenSize.wide:
      return 3;
  }
}
