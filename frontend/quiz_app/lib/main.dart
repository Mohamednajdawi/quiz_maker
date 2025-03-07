import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/admin/admin_panel_screen.dart';
import 'screens/home_screen.dart';
import 'screens/url_quiz_screen.dart';
import 'screens/quiz_history_screen.dart';
import 'services/quiz_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Enable Firebase Auth persistence
  await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);

  // Enable Firestore persistence
  await QuizService.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quiz App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme(
          primary: Color(0xFF2D5AF0),      // Modern blue
          secondary: Color(0xFF5C88FF),     // Light blue
          surface: Color(0xFFF8FAFF),       // Cool white
          background: Color(0xFFF0F3FF),    // Soft cool background
          error: Color(0xFFE5446D),         // Modern red
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Color(0xFF1A1F36),     // Deep blue-grey
          onBackground: Color(0xFF1A1F36),   // Deep blue-grey
          onError: Colors.white,
          brightness: Brightness.light,
        ),
        fontFamily: 'Poppins',
        textTheme: TextTheme(
          displayLarge: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A1F36)),
          displayMedium: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A1F36)),
          displaySmall: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A1F36)),
          headlineMedium: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A1F36)),
          titleLarge: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1A1F36)),
          bodyLarge: TextStyle(color: Color(0xFF1A1F36)),
          bodyMedium: TextStyle(color: Color(0xFF1A1F36)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          color: Colors.white,
          shadowColor: Color(0xFF2D5AF0).withOpacity(0.1),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Color(0xFF2D5AF0), width: 2),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.dark(
          primary: Color(0xFF5C88FF),
          secondary: Color(0xFF2D5AF0),
          surface: Color(0xFF1F2433),
          background: Color(0xFF151821),
          error: Color(0xFFE5446D),
        ),
        fontFamily: 'Poppins',
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          color: Color(0xFF1F2433),
          shadowColor: Colors.black.withOpacity(0.2),
        ),
      ),
      themeMode: ThemeMode.system,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading indicator while initializing
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Handle errors
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      FirebaseAuth.instance.signOut();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const AuthScreen()),
                      );
                    },
                    child: const Text('Return to Login'),
                  ),
                ],
              ),
            ),
          );
        }

        // User is logged in
        if (snapshot.hasData) {
          // Check if the user is an admin
          if (snapshot.data!.email == 'admin@example.com') {
            return const AdminPanelScreen();
          }
          return const HomeScreen();
        }

        // User is not logged in
        return const AuthScreen();
      },
    );
  }
}
