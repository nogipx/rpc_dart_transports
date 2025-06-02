import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/chat_service.dart';
import 'screens/welcome_screen.dart';
import 'screens/chat_screen.dart';

void main() {
  runApp(const ChatApp());
}

class ChatApp extends StatelessWidget {
  const ChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ChatService(),
      child: MaterialApp(
        title: 'RPC Dart Chat',
        debugShowCheckedModeBanner: false,

        // Современная тема Material Design 3
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.light),
          appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
          cardTheme: CardTheme(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
          ),
        ),

        // Темная тема
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
          appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
          cardTheme: CardTheme(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
          ),
        ),

        themeMode: ThemeMode.system,
        home: const ChatRouter(),
      ),
    );
  }
}

/// Роутер для навигации между экранами
class ChatRouter extends StatelessWidget {
  const ChatRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatService>(
      builder: (context, chatService, child) {
        // Если подключен - показываем чат
        if (chatService.isConnected) {
          return const ChatScreen();
        }

        // Иначе - экран приветствия
        return const WelcomeScreen();
      },
    );
  }
}
