import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/config.dart';
import 'core/theme.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('cs', null);
  runApp(const MfcApp());
}

class MfcApp extends StatelessWidget {
  const MfcApp({super.key});

  @override
  Widget build(BuildContext context) {
    final api = ApiClient();
    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: api),
        ChangeNotifierProvider(
          create: (_) => AuthService(api)..bootstrap(),
        ),
      ],
      child: MaterialApp(
        title: AppConfig.appName,
        theme: AppTheme.dark,
        debugShowCheckedModeBanner: false,
        home: const _AuthGate(),
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    if (auth.booting) return const SplashScreen();
    if (!auth.isLoggedIn) return const LoginScreen();
    return const MainShell();
  }
}
