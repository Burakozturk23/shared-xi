import 'package:flutter/material.dart';

/// Linkball UI foundation tokens.
/// Keep game screens on these values instead of introducing one-off styling.
class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

class AppRadii {
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
  static const double pill = 999;
}

class AppMotion {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration normal = Duration(milliseconds: 190);
  static const Duration slow = Duration(milliseconds: 280);
}

class AppSizes {
  static const double minTouchTarget = 48;
  static const double compactAvatar = 48;
  static const double cardAvatar = 72;
  static const double clubBadge = 60;
}

class AppShadows {
  static const List<BoxShadow> soft = [
    BoxShadow(
      color: Color(0x33000000),
      blurRadius: 18,
      offset: Offset(0, 8),
    ),
  ];
}
