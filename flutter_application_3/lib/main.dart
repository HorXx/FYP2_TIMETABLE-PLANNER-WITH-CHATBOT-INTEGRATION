import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'package:flutter/services.dart';
import 'providers/navigation_provider.dart';
import 'providers/task_provider.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'pages/timetable_page.dart';
import 'pages/chatbot_page.dart';
import 'pages/settings_page.dart';
import 'pages/add_edit_schedule_page.dart';
import 'pages/register_page.dart';
import 'widgets/phone_frame.dart';
import 'providers/category_provider.dart';
import 'dart:io' show Platform;

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    // 设置错误处理
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('Flutter Error: ${details.toString()}');
    };
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyCIM7mlNflL7AttBy2s30hhWYI8pBbmtuQ",
          authDomain: "fluttertimetable.firebaseapp.com",
          projectId: "fluttertimetable",
          storageBucket: "fluttertimetable.firebasestorage.app",
          messagingSenderId: "977655187417",
          appId: "1:977655187417:web:09ebb18c3b910db9537bc8",
          measurementId: "G-K31TMJHNGR",
        ),
      );
    } else {
      try {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: "AIzaSyDlFcRVosBbA2WYK8k63ivBzG8CKXpSuUk",
            authDomain: "fluttertimetable.firebaseapp.com",
            projectId: "fluttertimetable",
            storageBucket: "fluttertimetable.firebasestorage.app",
            messagingSenderId: "977655187417",
            appId: "1:977655187417:android:39b51984db96c72a537bc8",
            measurementId: "G-K31TMJHNGR",
          ),
        );
        debugPrint('Firebase initialized successfully');
      } catch (e) {
        debugPrint('Firebase initialization error: $e');
        rethrow;
      }
    }
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => NavigationProvider()),
          ChangeNotifierProvider(create: (_) => TaskProvider()),
          ChangeNotifierProvider(create: (_) => CategoryProvider()),
        ],
        child: MyApp(),
      ),
    );
  }, (error, stack) {
    debugPrint('Uncaught error: $error');
    debugPrint('Stack trace: $stack');
  });
}

class MyApp extends StatelessWidget {
  static const Color primaryColor = Color(0xFF1976D2);
  static const Color lightBlue = Color(0xFFE3F2FD);

  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Timetable Assistance',
      debugShowCheckedModeBanner: false, // 移除调试标签
      theme: ThemeData(
        primaryColor: primaryColor,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: AppBarTheme(
          backgroundColor: lightBlue,
          elevation: 0,
          iconTheme: IconThemeData(color: primaryColor),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: primaryColor,
        ),
        textTheme: TextTheme(
          titleLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          bodyLarge: TextStyle(fontSize: 16),
          bodyMedium: TextStyle(fontSize: 14),
        ),
        inputDecorationTheme: InputDecorationTheme(
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: primaryColor),
            borderRadius: BorderRadius.circular(12),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.all(primaryColor),
        ),
      ),
      home: Scaffold(
        backgroundColor: Colors.grey[200],
        body: (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) ? PhoneFrame(child: LoginPage()) : LoginPage(),
      ),
      routes: {
        '/home': (_) => Scaffold(
              backgroundColor: Colors.grey[200],
              body: (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) ? PhoneFrame(child: HomePage()) : HomePage(),
            ),
        '/timetable': (_) => Scaffold(
              backgroundColor: Colors.grey[200],
              body: (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) ? PhoneFrame(child: TimetablePage()) : TimetablePage(),
            ),
        '/chatbot': (_) => Scaffold(
              backgroundColor: Colors.grey[200],
              body: (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) ? PhoneFrame(child: ChatbotPage()) : ChatbotPage(),
            ),
        '/settings': (_) => Scaffold(
              backgroundColor: Colors.grey[200],
              body: (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) ? PhoneFrame(child: SettingsPage()) : SettingsPage(),
            ),
        '/add_edit': (_) => Scaffold(
              backgroundColor: Colors.grey[200],
              body: (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) ? PhoneFrame(child: EditTaskPage(initialDateTime: DateTime.now())) : EditTaskPage(initialDateTime: DateTime.now()),
            ),
        '/register': (_) => Scaffold(
              backgroundColor: Colors.grey[200],
              body: (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) ? PhoneFrame(child: RegisterPage()) : RegisterPage(),
            ),
        '/manage_category': (_) => Scaffold(
              backgroundColor: Colors.grey[200],
              body: (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) ? PhoneFrame(child: ManageCategoryPage()) : ManageCategoryPage(),
            ),
      },
    );
  }
}
