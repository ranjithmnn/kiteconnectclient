import 'package:material_ui/material_ui.dart';

enum SnackBarType {
  success(icon: Icons.check_circle_outline_rounded),
  error(icon: Icons.error_outline_rounded),
  info(icon: Icons.info_outline_rounded),
  warning(icon: Icons.warning_amber_rounded);

  final IconData icon;

  const SnackBarType({required this.icon});

  (Color background, Color foreground) resolveColors(ColorScheme colorScheme) {
    return switch (this) {
      SnackBarType.success => (
        colorScheme.primaryContainer,
        colorScheme.onPrimaryContainer,
      ),
      SnackBarType.error => (
        colorScheme.errorContainer,
        colorScheme.onErrorContainer,
      ),
      SnackBarType.info => (
        colorScheme.inverseSurface,
        colorScheme.onInverseSurface,
      ),
      SnackBarType.warning => (
        colorScheme.tertiaryContainer,
        colorScheme.onTertiaryContainer,
      ),
    };
  }
}

abstract final class AppSnackBar {
  static void show(
    BuildContext context, {
    required String message,
    SnackBarType type = SnackBarType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final colorScheme = ColorScheme.of(context);
    final textTheme = TextTheme.of(context);
    final (backgroundColor, foregroundColor) = type.resolveColors(colorScheme);
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: duration,
          behavior: SnackBarBehavior.fixed,
          backgroundColor: backgroundColor,
          content: Row(
            children: [
              Icon(type.icon, color: foregroundColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: textTheme.bodyMedium?.copyWith(
                    color: foregroundColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
