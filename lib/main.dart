import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kiteconnectclient/services/navigation_service.dart';
import 'package:kiteconnectclient/utils/theme/app_theme.dart';
import 'package:kiteconnectclient/view/auth/login_view.dart';
import 'package:kiteconnectclient/view/home/home_view.dart';
import 'package:material_ui/material_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  const storage = FlutterSecureStorage();
  final accessToken = await storage.read(key: 'access_token');
  runApp(MyApp(doesAccessTokenExist: accessToken != null && accessToken.isNotEmpty));
}

class MyApp extends StatelessWidget {
  final bool doesAccessTokenExist;
  const MyApp({super.key, this.doesAccessTokenExist = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: doesAccessTokenExist ? const HomeView() : const LoginView(),
    );
  }
}
