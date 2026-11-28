import 'package:material_ui/material_ui.dart';

/// Controls how destination text labels are displayed inside [ExpressiveNavBar].
enum ExpressiveNavLabelBehavior {
  /// Expands only the selected destination horizontally to show icon + label,
  /// keeping unselected destinations as compact icons.
  onlySelected,

  /// Shows icon + label on all destinations.
  always,

  /// Shows icons only (compact toolbar style).
  never,
}

/// Configuration for a single destination inside [ExpressiveNavBar].
@immutable
class ExpressiveNavItem {
  const ExpressiveNavItem({
    required this.icon,
    required this.label,
    this.selectedIcon,
    this.badgeCount,
    this.showBadge = false,
    this.semanticLabel,
  });

  /// Icon displayed when this destination is unselected.
  final IconData icon;

  /// Optional filled/active icon displayed when this destination is selected.
  /// Defaults to [icon] when omitted.
  final IconData? selectedIcon;

  /// Short text label for this destination.
  final String label;

  /// Optional numeric count rendered in an expressive shape badge on the icon.
  final int? badgeCount;

  /// Whether to show a small expressive dot badge when [badgeCount] is null.
  final bool showBadge;

  /// Optional accessibility label overriding [label].
  final String? semanticLabel;
}

/// Configuration for the detached M3 Expressive squircle action button
/// paired next to the floating navigation pill.
@immutable
class ExpressiveNavAction {
  const ExpressiveNavAction({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.backgroundColor,
    this.foregroundColor,
  });

  /// Icon displayed inside the squircle action button.
  final IconData icon;

  /// Callback invoked when the action button is tapped.
  final VoidCallback onPressed;

  /// Optional accessibility / tooltip label.
  final String? tooltip;

  /// Optional override for the squircle container color.
  final Color? backgroundColor;

  /// Optional override for the squircle icon color.
  final Color? foregroundColor;
}
