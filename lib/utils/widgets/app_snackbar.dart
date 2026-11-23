import 'package:material_ui/material_ui.dart';

enum SnackBarType {
  success(icon: Icons.check_circle_outline_rounded, color: Color(0xFF16A34A)),
  error(icon: Icons.error_outline_rounded, color: Color(0xFFDC2626)),
  info(
    icon: Icons.info_outline_rounded,
    color: Color.fromARGB(255, 138, 142, 150),
  ),
  warning(icon: Icons.warning_amber_rounded, color: Color(0xFFD97706));

  final IconData icon;
  final Color color;

  const SnackBarType({required this.icon, required this.color});
}

abstract final class AppSnackBar {
  static void show(
    BuildContext context, {
    required String message,
    SnackBarType type = SnackBarType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: duration,
          behavior: SnackBarBehavior.fixed,
          backgroundColor: type.color,
          content: Row(
            children: [
              Icon(type.icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
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
