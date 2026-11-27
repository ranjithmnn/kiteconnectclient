import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kiteconnectclient/services/navigation_service.dart';
import 'package:kiteconnectclient/utils/theme/material_themes.dart';
import 'package:kiteconnectclient/view/auth/login_view.dart';
import 'package:kiteconnectclient/view/home/bloc/home_bloc.dart';
import 'package:kiteconnectclient/view/home/home_view.dart';
import 'package:material_ui/material_ui.dart';

Future<void> main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  await dotenv.load();
  const storage = FlutterSecureStorage();
  final accessToken = await storage.read(key: 'access_token');
  final homeBloc = HomeBloc();

  var hasToken = accessToken != null && accessToken.isNotEmpty;
  if (hasToken) {
    homeBloc.add(const HomeProfileRequested());
    await homeBloc.stream.firstWhere(
      (state) => state is HomeLoaded || state is HomeError,
    );
  }
  FlutterNativeSplash.remove();

  runApp(
    BlocProvider<HomeBloc>.value(
      value: homeBloc,
      child: MyApp(hasValidSession: hasToken),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool hasValidSession;
  const MyApp({super.key, this.hasValidSession = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      theme: MaterialThemes.light,
      darkTheme: MaterialThemes.dark,
      themeMode: .system,
      home: hasValidSession ? const HomeView() : const LoginView(),
    );
  }
}
