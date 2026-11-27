import 'package:flutter/services.dart';
import 'package:kiteconnectclient/utils/widgets/expressive_shapes/expressive_shapes.dart';
import 'package:material_ui/material_ui.dart'
    hide MaterialShapes, MaterialShapeBorder, RoundedPolygon, CornerRounding;
import 'package:motor/motor.dart';

import 'expressive_dialog_button.dart';

/// Material 3 Expressive alert dialog surface.
///
/// Colors and text styles come strictly from the ambient [Theme]:
/// [ColorScheme.surfaceContainerHigh] container, [TextTheme.headlineSmall]
/// title, [TextTheme.bodyMedium] message, and stadium-shaped action pills
/// colored by [ExpressiveDialogButtonRole].
///
/// Button layout adapts to the count:
/// - 1 button: single full-width pill.
/// - 2 buttons: side-by-side equal-width horizontal row.
/// - 3 or more buttons: stacked full-width vertical column.
class ExpressiveDialog extends StatelessWidget {
  const ExpressiveDialog({
    super.key,
    required this.title,
    required this.message,
    required this.buttons,
    this.icon,
    this.iconShape,
    this.onButtonPressed,
  });

  final String title;
  final String message;
  final List<ExpressiveDialogButton> buttons;

  /// Optional header icon placed inside an expressive Material shape badge.
  final IconData? icon;

  /// Optional custom shape for the icon badge. Defaults to
  /// [MaterialShapes.cookie9Sided].
  final RoundedPolygon? iconShape;

  /// Hook used by [showExpressiveDialog] to coordinate animated dismissal
  /// before invoking [ExpressiveDialogButton.onPressed].
  final ValueChanged<ExpressiveDialogButton>? onButtonPressed;

  void _handleTap(ExpressiveDialogButton button) {
    if (button.role.isDestructive) {
      HapticFeedback.mediumImpact();
    }
    if (onButtonPressed != null) {
      onButtonPressed!(button);
    } else {
      button.onPressed?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;
    final bool centered = icon != null;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 280, maxWidth: 360),
      child: Material(
        color: cs.surfaceContainerHigh,
        elevation: 6,
        shadowColor: cs.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                _ExpressiveIconBadge(
                  icon: icon!,
                  shape: iconShape ?? MaterialShapes.cookie9Sided,
                ),
                const SizedBox(height: 16),
              ],
              Text(
                title,
                textAlign: centered ? TextAlign.center : TextAlign.start,
                style: tt.headlineSmall?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
              if (message.isNotEmpty) ...[
                const SizedBox(height: 10),
                Flexible(
                  child: SingleChildScrollView(
                    child: Text(
                      message,
                      textAlign: centered ? TextAlign.center : TextAlign.start,
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ),
                ),
              ],
              if (buttons.isNotEmpty) ...[
                const SizedBox(height: 24),
                _ButtonLayout(
                  buttons: buttons,
                  onTap: _handleTap,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpressiveIconBadge extends StatelessWidget {
  const _ExpressiveIconBadge({
    required this.icon,
    required this.shape,
  });

  final IconData icon;
  final RoundedPolygon shape;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Container(
      width: 52,
      height: 52,
      decoration: ShapeDecoration(
        color: cs.primaryContainer,
        shape: MaterialShapeBorder(shape: shape),
      ),
      child: Icon(icon, size: 24, color: cs.onPrimaryContainer),
    );
  }
}

/// Renders 1 button full-width, 2 buttons horizontally in a [Row], and
/// 3 or more buttons stacked vertically in a [Column].
class _ButtonLayout extends StatelessWidget {
  const _ButtonLayout({
    required this.buttons,
    required this.onTap,
  });

  final List<ExpressiveDialogButton> buttons;
  final ValueChanged<ExpressiveDialogButton> onTap;

  @override
  Widget build(BuildContext context) {
    if (buttons.length == 1) {
      return SizedBox(
        width: double.infinity,
        child: _DialogActionPill(
          button: buttons.first,
          onTap: () => onTap(buttons.first),
        ),
      );
    }

    if (buttons.length == 2) {
      return Row(
        children: [
          Expanded(
            child: _DialogActionPill(
              button: buttons[0],
              onTap: () => onTap(buttons[0]),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _DialogActionPill(
              button: buttons[1],
              onTap: () => onTap(buttons[1]),
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < buttons.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _DialogActionPill(
            button: buttons[i],
            onTap: () => onTap(buttons[i]),
          ),
        ],
      ],
    );
  }
}

/// Tactile stadium pill button with a subtle expressive spring press response
/// matching the fast spring language of the expressive widget suite.
class _DialogActionPill extends StatefulWidget {
  const _DialogActionPill({
    required this.button,
    required this.onTap,
  });

  final ExpressiveDialogButton button;
  final VoidCallback onTap;

  @override
  State<_DialogActionPill> createState() => _DialogActionPillState();
}

class _DialogActionPillState extends State<_DialogActionPill> {
  bool _pressed = false;

  (Color background, Color foreground) _colors(ColorScheme cs) {
    return switch (widget.button.role) {
      ExpressiveDialogButtonRole.primary => (cs.primary, cs.onPrimary),
      ExpressiveDialogButtonRole.secondary => (
        cs.secondaryContainer,
        cs.onSecondaryContainer,
      ),
      ExpressiveDialogButtonRole.text => (Colors.transparent, cs.primary),
      ExpressiveDialogButtonRole.destructive => (cs.error, cs.onError),
      ExpressiveDialogButtonRole.destructiveTonal => (
        cs.errorContainer,
        cs.onErrorContainer,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;
    final (Color bg, Color fg) = _colors(cs);
    final IconData? icon = widget.button.icon;

    return SingleMotionBuilder(
      motion: const MaterialSpringMotion.expressiveSpatialFast(),
      value: _pressed ? 0.96 : 1.0,
      builder: (context, scale, child) => Transform.scale(
        scale: scale,
        child: child,
      ),
      child: Material(
        color: bg,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (highlighted) {
            if (_pressed != highlighted) {
              setState(() => _pressed = highlighted);
            }
          },
          splashColor: fg.withValues(alpha: 0.12),
          highlightColor: fg.withValues(alpha: 0.08),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 46),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: fg),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      widget.button.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.labelLarge?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

