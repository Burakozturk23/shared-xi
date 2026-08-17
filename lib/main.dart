import 'package:flutter/material.dart';
import 'screens/welcome_page.dart';
import 'theme/app_theme.dart';
import 'repositories/repository.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Kulüp + oyuncu verisini yükle (zorunlu)
  await Repository.instance.initialize();
  await AuthService.ensureSignedIn();
  

  runApp(const SharedXIApp()); // kendi widget adın neyse o
}

class SharedXIApp extends StatelessWidget {
  const SharedXIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Shared XI',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppTheme.backgroundColor,
        colorScheme: ColorScheme.dark(
          primary: AppTheme.primaryColor,
          secondary: AppTheme.secondaryColor,
          surface: AppTheme.cardColor,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: AppTheme.backgroundColor,
          foregroundColor: AppTheme.textColor,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 55),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppTheme.cardColor,
          hintStyle: const TextStyle(color: AppTheme.hintColor),
          labelStyle: const TextStyle(color: AppTheme.hintColor),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppTheme.borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: AppTheme.primaryColor,
              width: 2,
            ),
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: AppTheme.textColor),
        ),
      ),
      home: const WelcomePage(),
    );
  }
}