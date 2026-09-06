import 'package:flutter/material.dart';

import 'api/api_client.dart';
import 'auth/login_screen.dart';
import 'models/support_models.dart';
import 'support/inbox_screen.dart';

class AroFiSupportApp extends StatefulWidget {
  const AroFiSupportApp({super.key, required this.api});
  final ApiClient api;

  @override
  State<AroFiSupportApp> createState() => _AroFiSupportAppState();
}

class _AroFiSupportAppState extends State<AroFiSupportApp> {
  SupportUser? _user;
  bool _loading = true;
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final user = await widget.api.getMe();
      if (!mounted) return;
      setState(() => _user = user);
    } catch (_) {
      // The login screen will surface account/network errors on submit.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onAuthenticated(SupportUser user) => setState(() => _user = user);

  Future<void> _logout() async {
    await widget.api.logout();
    if (mounted) setState(() => _user = null);
  }

  void _cycleTheme() {
    setState(() {
      _themeMode = switch (_themeMode) {
        ThemeMode.system => ThemeMode.light,
        ThemeMode.light => ThemeMode.dark,
        ThemeMode.dark => ThemeMode.system,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF22A53A);
    final light = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(seedColor: green, brightness: Brightness.light),
      scaffoldBackgroundColor: const Color(0xFFF5F7F9),
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          side: BorderSide(color: Color(0xFFE1E6EA)),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      ),
    );
    final dark = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(seedColor: green, brightness: Brightness.dark),
      scaffoldBackgroundColor: const Color(0xFF0B0805),
      cardTheme: const CardThemeData(
        color: Color(0xFF202020),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          side: BorderSide(color: Color(0xFF303030)),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFF202020),
        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      ),
    );

    return MaterialApp(
      title: 'AroFi Support',
      debugShowCheckedModeBanner: false,
      theme: light,
      darkTheme: dark,
      themeMode: _themeMode,
      home: _loading
          ? const _BootScreen()
          : _user == null
              ? LoginScreen(api: widget.api, onAuthenticated: _onAuthenticated)
              : InboxScreen(
                  api: widget.api,
                  user: _user!,
                  themeMode: _themeMode,
                  onCycleTheme: _cycleTheme,
                  onLogout: _logout,
                ),
    );
  }
}

class _BootScreen extends StatelessWidget {
  const _BootScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
}
