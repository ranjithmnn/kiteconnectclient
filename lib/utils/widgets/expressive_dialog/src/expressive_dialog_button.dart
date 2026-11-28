import 'package:material_ui/material_ui.dart';

/// Semantic role for an [ExpressiveDialogButton], mapping directly to the
/// ambient [ColorScheme] tokens.
enum ExpressiveDialogButtonRole {
  /// High-emphasis filled pill using [ColorScheme.primary] /
  /// [ColorScheme.onPrimary].
  primary,

  /// Neutral tonal pill using [ColorScheme.secondaryContainer] /
  /// [ColorScheme.onSecondaryContainer]. Ideal for cancel or secondary choices.
  secondary,

  /// Low-emphasis transparent pill with [ColorScheme.primary] label.
  text,

  /// High-emphasis destructive pill using [ColorScheme.error] /
  /// [ColorScheme.onError] for irreversible or dangerous actions.
  destructive,

  /// Softer destructive tonal pill using [ColorScheme.errorContainer] /
  /// [ColorScheme.onErrorContainer].
  destructiveTonal;

  /// Whether this role represents a destructive action.
  bool get isDestructive =>
      this == ExpressiveDialogButtonRole.destructive ||
      this == ExpressiveDialogButtonRole.destructiveTonal;
}

/// Configuration for one action pill inside an expressive alert dialog.
@immutable
class ExpressiveDialogButton {
  const ExpressiveDialogButton({
    required this.label,
    this.onPressed,
    this.role = ExpressiveDialogButtonRole.secondary,
    this.icon,
    this.dismissOnPressed = true,
    this.enableHaptics = true,
  });

  /// Visible text on the action pill.
  final String label;

  /// Callback invoked when the button is tapped.
  final VoidCallback? onPressed;

  /// Visual and semantic emphasis, including destructive variants.
  final ExpressiveDialogButtonRole role;

  /// Optional leading icon rendered inside the pill.
  final IconData? icon;

  /// Whether tapping this button automatically plays the dialog's exit
  /// animation and dismisses it. Defaults to `true`.
  final bool dismissOnPressed;

  /// Whether tapping this button triggers role-aware [MicroHaptics] feedback.
  /// Defaults to `true`.
  final bool enableHaptics;
}

