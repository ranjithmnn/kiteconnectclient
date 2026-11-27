import 'package:kiteconnectclient/utils/widgets/expressive_shapes/expressive_shapes.dart';
import 'package:material_ui/material_ui.dart'
    hide MaterialShapes, MaterialShapeBorder, RoundedPolygon, CornerRounding;
import 'package:motor/motor.dart';

import 'expressive_dialog_button.dart';
import 'expressive_dialog_view.dart';

/// Shows an expressive alert dialog with Material 3 Expressive spring physics:
/// expressive spatial fast bounce on popup and crisp standard spatial/effects
/// springs on dismissal.
///
/// Colors and typography come from the ambient [Theme]. Returns the tapped
/// [ExpressiveDialogButton] when dismissed via an action button, or `null`
/// when dismissed via the barrier or system back navigation.
Future<ExpressiveDialogButton?> showExpressiveDialog({
  required BuildContext context,
  required String title,
  required String message,
  required List<ExpressiveDialogButton> buttons,
  IconData? icon,
  RoundedPolygon? iconShape,
  bool barrierDismissible = true,
  bool useRootNavigator = true,
}) {
  final ColorScheme cs = Theme.of(context).colorScheme;
  final String barrierLabel =
      MaterialLocalizations.of(context).modalBarrierDismissLabel;

  return Navigator.of(context, rootNavigator: useRootNavigator).push(
    _ExpressiveDialogRoute(
      title: title,
      message: message,
      buttons: buttons,
      icon: icon,
      iconShape: iconShape,
      barrierDismissible: barrierDismissible,
      barrierLabel: barrierLabel,
      barrierColor: cs.scrim.withValues(alpha: 0.42),
    ),
  );
}

class _ExpressiveDialogRoute extends PopupRoute<ExpressiveDialogButton> {
  _ExpressiveDialogRoute({
    required this.title,
    required this.message,
    required this.buttons,
    required this.icon,
    required this.iconShape,
    required this.barrierDismissible,
    required this.barrierLabel,
    required this.barrierColor,
  });

  final String title;
  final String message;
  final List<ExpressiveDialogButton> buttons;
  final IconData? icon;
  final RoundedPolygon? iconShape;

  @override
  final bool barrierDismissible;

  @override
  final String barrierLabel;

  @override
  final Color barrierColor;

  // Matches the expressiveSpatialFast entry settle window (~310ms) and
  // standardSpatialFast exit settle window (~160ms).
  @override
  Duration get transitionDuration => const Duration(milliseconds: 350);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 220);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _ExpressiveDialogAnimator(
      routeAnimation: animation,
      title: title,
      message: message,
      buttons: buttons,
      icon: icon,
      iconShape: iconShape,
    );
  }
}

/// Drives the dialog's popup and remove animations with M3 Expressive springs:
/// - Popup: [MaterialSpringMotion.expressiveSpatialFast] on scale (0.86 → 1.0)
///   and vertical lift (+24px → 0), paired with
///   [MaterialSpringMotion.expressiveEffectsDefault] on opacity (0 → 1).
/// - Remove: [MaterialSpringMotion.standardSpatialFast] on scale (1.0 → 0.90)
///   and drop (0 → +16px), paired with
///   [MaterialSpringMotion.standardEffectsFast] on opacity (1 → 0).
class _ExpressiveDialogAnimator extends StatefulWidget {
  const _ExpressiveDialogAnimator({
    required this.routeAnimation,
    required this.title,
    required this.message,
    required this.buttons,
    required this.icon,
    required this.iconShape,
  });

  final Animation<double> routeAnimation;
  final String title;
  final String message;
  final List<ExpressiveDialogButton> buttons;
  final IconData? icon;
  final RoundedPolygon? iconShape;

  @override
  State<_ExpressiveDialogAnimator> createState() =>
      _ExpressiveDialogAnimatorState();
}

class _ExpressiveDialogAnimatorState extends State<_ExpressiveDialogAnimator> {
  static const double _enterScale = 0.86;
  static const double _exitScale = 0.90;
  static const double _enterOffsetY = 24.0;
  static const double _exitOffsetY = 16.0;

  bool _visible = false;
  bool _removing = false;

  @override
  void initState() {
    super.initState();
    widget.routeAnimation.addStatusListener(_onRouteStatusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_removing) {
        setState(() => _visible = true);
      }
    });
  }

  @override
  void dispose() {
    widget.routeAnimation.removeStatusListener(_onRouteStatusChanged);
    super.dispose();
  }

  void _onRouteStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.reverse ||
        status == AnimationStatus.dismissed) {
      if (!_removing && mounted) {
        setState(() {
          _removing = true;
          _visible = false;
        });
      }
    }
  }

  void _handleButtonPressed(ExpressiveDialogButton button) {
    if (_removing) return;

    if (button.dismissOnPressed) {
      setState(() {
        _removing = true;
        _visible = false;
      });
      Navigator.of(context).pop(button);
      button.onPressed?.call();
    } else {
      button.onPressed?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final double hiddenScale = _removing ? _exitScale : _enterScale;
    final double hiddenOffsetY = _removing ? _exitOffsetY : _enterOffsetY;

    return SafeArea(
      child: Center(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleMotionBuilder(
            motion: _visible
                ? const MaterialSpringMotion.expressiveSpatialFast()
                : const MaterialSpringMotion.standardSpatialFast(),
            value: _visible ? 1.0 : 0.0,
            builder: (context, spatial, child) {
              final double scale = hiddenScale + (1.0 - hiddenScale) * spatial;
              final double offsetY = hiddenOffsetY * (1.0 - spatial);
              return Transform.translate(
                offset: Offset(0, offsetY),
                child: Transform.scale(
                  scale: scale.clamp(0.0, 1.25),
                  child: child,
                ),
              );
            },
            child: SingleMotionBuilder(
              motion: _visible
                  ? const MaterialSpringMotion.expressiveEffectsDefault()
                  : const MaterialSpringMotion.standardEffectsFast(),
              value: _visible ? 1.0 : 0.0,
              builder: (context, opacity, child) => Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: child,
              ),
              child: ExpressiveDialog(
                title: widget.title,
                message: widget.message,
                buttons: widget.buttons,
                icon: widget.icon,
                iconShape: widget.iconShape,
                onButtonPressed: _handleButtonPressed,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

