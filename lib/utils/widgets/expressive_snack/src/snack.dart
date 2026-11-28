import 'package:material_ui/material_ui.dart';

import 'snack_view.dart';

/// Semantic variant for an expressive snackbar, controlling its color palette
/// and haptic feedback pattern.
enum ExpressiveSnackType {
  success,
  error,
  warning,
  info,
}

/// One shown snack and the key that reaches its live view.
class Snack {
  Snack({
    required this.message,
    required this.type,
    required this.icon,
    required this.duration,
  });

  final GlobalKey<SnackViewState> key = GlobalKey();
  final String message;
  final ExpressiveSnackType type;
  final IconData? icon;
  final Duration duration;
}
