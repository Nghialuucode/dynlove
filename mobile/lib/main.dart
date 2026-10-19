import 'package:flutter/material.dart';
import 'api.dart';
import 'socket_service.dart';
import 'screens/login.dart';
import 'screens/home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF6B9D)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFFF0F5),
      ),
      home: Api.isLoggedIn ? const HomeScreen() : const LoginScreen(),
    );
  }
}
