import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'login_page.dart';
import 'dashboard_page.dart';
import 'chat_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Load stored user data
  final prefs = await SharedPreferences.getInstance();
  final username = prefs.getString('priv_username');
  final group = prefs.getString('priv_group');

  runApp(PrivChatApp(
    startRoute: username == null
        ? '/login'
        : (group == null ? '/dashboard' : '/chat'),
  ));
}

class PrivChatApp extends StatelessWidget {
  final String startRoute;
  const PrivChatApp({super.key, required this.startRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PrivChat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF071023),
        fontFamily: 'Inter',
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white70),
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C5CFF),
          brightness: Brightness.dark,
        ),
      ),
      initialRoute: startRoute,
      routes: {
        '/login': (context) => const LoginPage(),
        '/dashboard': (context) => const DashboardPage(),
        '/chat': (context) {
          final prefs = SharedPreferences.getInstance();
          return FutureBuilder<SharedPreferences>(
            future: prefs,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final groupId = snapshot.data!.getString('priv_group') ?? '';
              return ChatPage(groupId: groupId);
            },
          );
        },
      },
    );
  }
}
