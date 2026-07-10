import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'views/home_page.dart';

void _cleanLegacyTempFiles() async {
  try {
    final tempDir = await getTemporaryDirectory();
    if (await tempDir.exists()) {
      await for (final entity in tempDir.list(recursive: false, followLinks: false)) {
        if (entity is File && (entity.path.contains('/dump_') || entity.path.endsWith('.m4a'))) {
          await entity.delete();
          debugPrint('🧹 Cleared legacy temp audio dump: ${entity.path}');
        }
      }
    }
  } catch (_) {}
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _cleanLegacyTempFiles();
  runApp(const BrainVentApp());
}

class BrainVentApp extends StatelessWidget {
  const BrainVentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BrainVent',
      debugShowCheckedModeBanner: false,
      
      // 🔮 深度暗黑治愈系主题配色 (对应 Web 端的 globals.css 设计系统)
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B0C10),
        primaryColor: Colors.purpleAccent,
        colorScheme: const ColorScheme.dark(
          primary: Colors.purpleAccent,
          secondary: Colors.pinkAccent,
          background: Color(0xFF0B0C10),
          surface: Color(0xFF1E1E2F),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFFC5C6C7), fontFamily: 'sans-serif'),
          bodyMedium: TextStyle(color: Color(0xFFC5C6C7), fontFamily: 'sans-serif'),
        ),
        tabBarTheme: const TabBarThemeData(
          labelColor: Colors.purpleAccent,
          unselectedLabelColor: Colors.grey,
          indicatorSize: TabBarIndicatorSize.tab,
        ),
      ),
      home: const HomePage(),
    );
  }
}
