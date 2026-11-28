import 'dart:async';

import 'package:kiteconnectclient/utils/haptics/mico_haptics.dart';
import 'package:kiteconnectclient/utils/widgets/expressive_shapes/expressive_shapes.dart';
import 'package:material_ui/material_ui.dart'
    hide MaterialShapes, MaterialShapeBorder, RoundedPolygon, CornerRounding;
import 'package:motor/motor.dart';

import 'expressive_nav_item.dart';

/// A Material 3 Expressive floating bottom toolbar & navigation bar:
/// a compact floating stadium capsule paired with an optional detached
/// rounded-square (squircle) primary action button.
///
/// Features:
/// - Compact content-hugging stadium pill (`StadiumBorder`) + `62×62` squircle
///   action button aligned to the same height (`8dp` gap).
/// - Spring-driven horizontal label expansion (`expressiveSpatialFast`) for the
///   selected destination, tactile press springs, and expressive shape badges.
/// - Theme-derived M3 Expressive dark & light surface/accent tokens.
class ExpressiveNavBar extends StatefulWidget {
  const ExpressiveNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.action,
    this.labelBehavior = ExpressiveNavLabelBehavior.onlySelected,
    this.backgroundColor,
    this.indicatorColor,
    this.selectedForegroundColor,
    this.unselectedForegroundColor,
    this.margin = const EdgeInsets.fromLTRB(16, 0, 16, 12),
    this.enableHaptics = true,
  }) : assert(items.length >= 2, 'ExpressiveNavBar requires at least 2 items'),
       assert(
         currentIndex >= 0 && currentIndex < items.length,
         'currentIndex must be within the bounds of items',
       );

  /// Navigation destinations rendered inside the floating stadium capsule.
  final List<ExpressiveNavItem> items;

  /// Currently active destination index.
  final int currentIndex;

  /// Invoked when a destination is tapped.
  final ValueChanged<int> onTap;

  /// Optional detached M3 Expressive squircle button placed beside the pill.
  final ExpressiveNavAction? action;

  /// Controls whether labels appear on the selected destination, all, or none.
  final ExpressiveNavLabelBehavior labelBehavior;

  /// Optional override for the floating stadium container color.
  final Color? backgroundColor;

  /// Optional override for the active destination chip color.
  final Color? indicatorColor;

  /// Optional override for the active icon and label color.
  final Color? selectedForegroundColor;

  /// Optional override for unselected destination icons.
  final Color? unselectedForegroundColor;

  /// Outer margin around the floating bar (outside bottom safe area).
  final EdgeInsetsGeometry margin;

  /// Whether taps trigger [MicroHaptics.microTick].
  final bool enableHaptics;

  @override
  State<ExpressiveNavBar> createState() => _ExpressiveNavBarState();
}

class _ExpressiveNavBarState extends State<ExpressiveNavBar> {
  static const double _barHeight = 62.0;
  static const double _barPadding = 7.0;
  static const double _actionGap = 10.0;
  static const double _enterOffsetY = 32.0;

  bool _entered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _entered = true);
      }
    });
  }

  void _handleItemTap(int index) {
    unawaited(MicroHaptics.microTick());
    widget.onTap(index);
  }

  void _handleActionTap() {
    final action = widget.action;
    if (action == null) return;
    if (widget.enableHaptics) {
      unawaited(MicroHaptics.microTick());
    }
    action.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;

    // Matches M3 Expressive FloatingToolbar tokens:
    // deep surfaceContainerLowest in dark mode, elevated surfaceContainerHigh in light mode.
    final Color pillSurface =
        widget.backgroundColor ??
        (isDark ? cs.surfaceContainerLowest : cs.surfaceContainerHigh);
    final Color activeChipColor =
        widget.indicatorColor ?? cs.secondaryContainer;
    final Color selectedFg =
        widget.selectedForegroundColor ?? cs.onSecondaryContainer;
    final Color unselectedFg =
        widget.unselectedForegroundColor ??
        (isDark ? cs.secondary : cs.onSurfaceVariant);

    return SafeArea(
      top: false,
      child: Padding(
        padding: widget.margin,
        child: Align(
          alignment: Alignment.bottomCenter,
          heightFactor: 1.0,
          child: SingleMotionBuilder(
            motion: const MaterialSpringMotion.expressiveSpatialFast(),
            value: _entered ? 1.0 : 0.0,
            builder: (context, spatial, child) {
              final double translateY = _enterOffsetY * (1.0 - spatial);
              final double scale = (0.90 + 0.10 * spatial).clamp(0.0, 1.15);
              return Transform.translate(
                offset: Offset(0, translateY),
                child: Transform.scale(
                  scale: scale,
                  alignment: Alignment.bottomCenter,
                  child: child,
                ),
              );
            },
            child: SingleMotionBuilder(
              motion: const MaterialSpringMotion.expressiveEffectsDefault(),
              value: _entered ? 1.0 : 0.0,
              builder: (context, opacity, child) => Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: child,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Material(
                      color: pillSurface,
                      elevation: 6,
                      shadowColor: cs.shadow.withValues(
                        alpha: isDark ? 0.50 : 0.24,
                      ),
                      shape: StadiumBorder(
                        side: BorderSide(
                          color: cs.outlineVariant.withValues(
                            alpha: isDark ? 0.18 : 0.35,
                          ),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: SizedBox(
                        height: _barHeight,
                        child: Padding(
                          padding: const EdgeInsets.all(_barPadding),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (
                                  int i = 0;
                                  i < widget.items.length;
                                  i++
                                ) ...[
                                  if (i > 0) const SizedBox(width: 4),
                                  _NavPillItem(
                                    item: widget.items[i],
                                    isSelected: i == widget.currentIndex,
                                    labelBehavior: widget.labelBehavior,
                                    activeChipColor: activeChipColor,
                                    selectedColor: selectedFg,
                                    unselectedColor: unselectedFg,
                                    onTap: () => _handleItemTap(i),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (widget.action != null) ...[
                    const SizedBox(width: _actionGap),
                    _ExpressiveSquircleAction(
                      action: widget.action!,
                      size: _barHeight,
                      onTap: _handleActionTap,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavPillItem extends StatefulWidget {
  const _NavPillItem({
    required this.item,
    required this.isSelected,
    required this.labelBehavior,
    required this.activeChipColor,
    required this.selectedColor,
    required this.unselectedColor,
    required this.onTap,
  });

  final ExpressiveNavItem item;
  final bool isSelected;
  final ExpressiveNavLabelBehavior labelBehavior;
  final Color activeChipColor;
  final Color selectedColor;
  final Color unselectedColor;
  final VoidCallback onTap;

  @override
  State<_NavPillItem> createState() => _NavPillItemState();
}

class _NavPillItemState extends State<_NavPillItem> {
  bool _pressed = false;

  bool get _wantsLabel => switch (widget.labelBehavior) {
    ExpressiveNavLabelBehavior.onlySelected => widget.isSelected,
    ExpressiveNavLabelBehavior.always => true,
    ExpressiveNavLabelBehavior.never => false,
  };

  @override
  Widget build(BuildContext context) {
    final TextTheme tt = Theme.of(context).textTheme;
    final TextScaler clampedScaler = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: 1.15);
    final IconData displayIcon = widget.isSelected
        ? (widget.item.selectedIcon ?? widget.item.icon)
        : widget.item.icon;

    return Semantics(
      button: true,
      selected: widget.isSelected,
      label: widget.item.semanticLabel ?? widget.item.label,
      child: SingleMotionBuilder(
        motion: const MaterialSpringMotion.expressiveSpatialFast(),
        value: _pressed ? 0.90 : 1.0,
        builder: (context, pressScale, child) => Transform.scale(
          scale: pressScale.clamp(0.80, 1.15),
          child: child,
        ),
        child: SingleMotionBuilder(
          motion: const MaterialSpringMotion.expressiveSpatialFast(),
          value: widget.isSelected ? 1.0 : 0.0,
          builder: (context, selection, _) {
            final double clampedSel = selection.clamp(0.0, 1.0);
            final Color fg = Color.lerp(
              widget.unselectedColor,
              widget.selectedColor,
              clampedSel,
            )!;
            final Color bg = widget.activeChipColor.withValues(
              alpha: clampedSel,
            );
            final double iconScale = (1.0 + 0.08 * selection).clamp(0.85, 1.2);
            final double labelFactor = switch (widget.labelBehavior) {
              ExpressiveNavLabelBehavior.onlySelected => clampedSel,
              ExpressiveNavLabelBehavior.always => 1.0,
              ExpressiveNavLabelBehavior.never => 0.0,
            };
            final double horizontalPad = 12.0 + 4.0 * labelFactor;

            return Material(
              color: bg,
              shape: const StadiumBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: widget.onTap,
                customBorder: const StadiumBorder(),
                onHighlightChanged: (highlighted) {
                  if (_pressed != highlighted) {
                    setState(() => _pressed = highlighted);
                  }
                },
                splashColor: widget.selectedColor.withValues(alpha: 0.12),
                highlightColor: widget.selectedColor.withValues(alpha: 0.08),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPad),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Transform.scale(
                          scale: iconScale,
                          child: _BadgedIcon(
                            icon: displayIcon,
                            color: fg,
                            badgeCount: widget.item.badgeCount,
                            showBadge: widget.item.showBadge,
                          ),
                        ),
                        if (_wantsLabel || labelFactor > 0.01)
                          ClipRect(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              widthFactor: labelFactor,
                              child: Opacity(
                                opacity: labelFactor,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Text(
                                    widget.item.label,
                                    maxLines: 1,
                                    softWrap: false,
                                    textScaler: clampedScaler,
                                    style: tt.labelLarge?.copyWith(
                                      color: fg,
                                      fontWeight: widget.isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      letterSpacing: 0.1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Detached M3 Expressive rounded-square (squircle) primary action button
/// aligned to the height of the floating stadium pill.
class _ExpressiveSquircleAction extends StatefulWidget {
  const _ExpressiveSquircleAction({
    required this.action,
    required this.size,
    required this.onTap,
  });

  final ExpressiveNavAction action;
  final double size;
  final VoidCallback onTap;

  @override
  State<_ExpressiveSquircleAction> createState() =>
      _ExpressiveSquircleActionState();
}

class _ExpressiveSquircleActionState extends State<_ExpressiveSquircleAction> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;

    // Soft pastel accent container + deep contrast icon (matches M3 Expressive FAB).
    final Color bg =
        widget.action.backgroundColor ??
        (isDark ? cs.primary : cs.primaryContainer);
    final Color fg =
        widget.action.foregroundColor ??
        (isDark ? cs.onPrimary : cs.onPrimaryContainer);

    Widget button = SingleMotionBuilder(
      motion: const MaterialSpringMotion.expressiveSpatialFast(),
      value: _pressed ? 1.0 : 0.0,
      builder: (context, press, _) {
        final double scale = (1.0 - 0.07 * press).clamp(0.85, 1.12);
        final double cornerRadius = (18.0 + 6.0 * press).clamp(12.0, 30.0);
        final ShapeBorder shape = RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cornerRadius),
        );

        return Transform.scale(
          scale: scale,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Material(
              color: bg,
              elevation: 6,
              shadowColor: cs.shadow.withValues(alpha: isDark ? 0.50 : 0.24),
              shape: shape,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: widget.onTap,
                customBorder: shape,
                onHighlightChanged: (highlighted) {
                  if (_pressed != highlighted) {
                    setState(() => _pressed = highlighted);
                  }
                },
                splashColor: fg.withValues(alpha: 0.14),
                highlightColor: fg.withValues(alpha: 0.08),
                child: Center(
                  child: Icon(widget.action.icon, size: 24, color: fg),
                ),
              ),
            ),
          ),
        );
      },
    );

    final String? tooltip = widget.action.tooltip;
    if (tooltip != null && tooltip.isNotEmpty) {
      button = Tooltip(message: tooltip, child: button);
    }
    return button;
  }
}

class _BadgedIcon extends StatelessWidget {
  const _BadgedIcon({
    required this.icon,
    required this.color,
    required this.badgeCount,
    required this.showBadge,
  });

  final IconData icon;
  final Color color;
  final int? badgeCount;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    final int? count = badgeCount;
    final bool hasCount = count != null && count > 0;
    if (!hasCount && !showBadge) {
      return Icon(icon, size: 22, color: color);
    }

    final ColorScheme cs = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, size: 22, color: color),
        if (hasCount)
          Positioned(
            right: count > 9 ? -10 : -7,
            top: -5,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              padding: EdgeInsets.symmetric(horizontal: count > 9 ? 4 : 2),
              alignment: Alignment.center,
              decoration: ShapeDecoration(
                color: cs.error,
                shape: count > 9
                    ? const StadiumBorder()
                    : MaterialShapeBorder(shape: MaterialShapes.cookie9Sided),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: tt.labelSmall?.copyWith(
                  color: cs.onError,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                ),
              ),
            ),
          )
        else
          Positioned(
            right: -3,
            top: -2,
            child: Container(
              width: 8,
              height: 8,
              decoration: ShapeDecoration(
                color: cs.error,
                shape: MaterialShapeBorder(shape: MaterialShapes.cookie9Sided),
              ),
            ),
          ),
      ],
    );
  }
}
