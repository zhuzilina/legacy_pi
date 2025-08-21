import 'package:flutter/material.dart';
import 'pages/home_page.dart';

void main() {
  runApp(const RedCultureApp());
}

class RedCultureApp extends StatelessWidget {
  const RedCultureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '红色文化学习',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.red,
        primaryColor: Colors.red[700],
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red[700]!,
          brightness: Brightness.light,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.red[700],
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.red[700],
          foregroundColor: Colors.white,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
