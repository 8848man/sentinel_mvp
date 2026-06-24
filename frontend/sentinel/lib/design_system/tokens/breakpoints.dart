import 'package:flutter/material.dart';

/// Breakpoints per sdd/frontend/10_2_responsive_strategy.md (D1).
class AppBreakpoints {
  AppBreakpoints._();

  static const double mobileMax = 767;
  static const double tabletMax = 1199;

  /// Dashboard-only sub-breakpoint (10_3_responsive_dashboard.md): the board
  /// needs more floor width than other screens before it can show 3 columns.
  static const double dashboardBoardMin = 900;

  static bool isMobile(double width) => width <= mobileMax;
  static bool isTablet(double width) => width > mobileMax && width <= tabletMax;
  static bool isDesktop(double width) => width > tabletMax;
}

extension AppBreakpointsContext on BuildContext {
  double get screenWidth => MediaQuery.of(this).size.width;
  bool get isMobileWidth => AppBreakpoints.isMobile(screenWidth);
  bool get isTabletWidth => AppBreakpoints.isTablet(screenWidth);
  bool get isDesktopWidth => AppBreakpoints.isDesktop(screenWidth);
}
