import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/auth_wrapper.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RecuerdaMed',
      home: const AuthWrapper(),
    );
  }
}
