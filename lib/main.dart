import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:kiteconnectclient/utils/theme/app_theme.dart';
import 'package:kiteconnectclient/view/auth/login_view.dart';
import 'package:material_ui/material_ui.dart';

void main() async {
  await dotenv.load();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const LoginView(),
    );
  }
}
