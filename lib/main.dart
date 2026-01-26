import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'routes/app_routes.dart';
import 'ecg_quality/ecg_quality_model.dart';

late EcgQualityModel ecgQualityModel;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  ecgQualityModel = EcgQualityModel();
  try {
    await ecgQualityModel.load(); // load AI model once
  } catch (e) {
    debugPrint('ECG Quality model load failed: $e');
  }

  runApp(const SmartHeartCareApp());
}

class SmartHeartCareApp extends StatelessWidget {
  const SmartHeartCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Lock orientation to portrait
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    return MaterialApp(
      title: 'SmartHeart Care',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          primary: Colors.blue.shade800, // Darker blue for contrast
          surface: Colors.white,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,

        // 1. Large Text Global Settings
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 18, color: Colors.black87),
          bodyLarge: TextStyle(fontSize: 20, color: Colors.black87),
          titleMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          titleLarge: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),

        // 2. Big Buttons
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            minimumSize: const Size(double.infinity, 60), // Tall buttons
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        // 3. Clear Inputs
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFFF5F5F5), // Light grey background
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          labelStyle: TextStyle(fontSize: 18, color: Colors.black54),
          floatingLabelStyle: TextStyle(fontSize: 20, color: Colors.blue),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Colors.grey, width: 1.5),
          ),
        ),
      ),
      initialRoute: AppRoutes.login,
      routes: AppRoutes.routes,
    );
  }
}
