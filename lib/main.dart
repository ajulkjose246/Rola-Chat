import 'package:flutter/material.dart';
import 'package:rolachat/pages/login/auth_wrapper.dart';
import 'package:rolachat/pages/login/login_screen.dart';
import 'package:rolachat/pages/navbar.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      routes: ({
        '/': (context) => const Navbar(),
        '/login': (context) => const LoginScreen(),
        '/auth': (context) => const AuthWrapper(),
      }),
      initialRoute: '/auth',
    );
  }
}
