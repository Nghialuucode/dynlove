import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api.dart';
import 'socket_service.dart';
import 'screens/login.dart';
import 'screens/home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  try {
    await Api.load();
    if (Api.isLoggedIn) SocketService.connect();
  } catch (e) {
    debugPrint('Init error: $e');
  }
  runApp(const DynLoveApp());
}

class DynLoveApp extends StatelessWidget {
  const DynLoveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DynLove',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF5277),
          primary: const Color(0xFFFF5277),
          secondary: const Color(0xFFFF85A2),
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFFFF5F7),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          scrolledUnderElevation: 0,
          titleTextStyle: TextStyle(
            color: Color(0xFF2D3142),
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
          iconTheme: IconThemeData(color: Color(0xFF2D3142)),
        ),
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          color: Colors.white,
        ),
      ),
      home: Api.isLoggedIn ? const HomeScreen() : const LoginScreen(),
    );
  }
}
