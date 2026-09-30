import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'screens/auth_screen.dart';
import 'screens/role_home_screen.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WastePayApp());
}

class WastePayApp extends StatelessWidget {
  const WastePayApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WastePay Nigeria',
      theme: WastePayTheme.light,
      darkTheme: WastePayTheme.dark,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    final loggedIn = await ApiService.isLoggedIn();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => loggedIn ? const RoleHomeScreen() : const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WPColors.green900,
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 90, height: 90,
              decoration: BoxDecoration(color: WPColors.green700, shape: BoxShape.circle,
                  border: Border.all(color: WPColors.gold, width: 2)),
              child: const Center(child: Text('♻', style: TextStyle(fontSize: 44)))),
          const SizedBox(height: 20),
          const Text('WastePay', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700)),
          const Text('Nigeria', style: TextStyle(color: WPColors.goldLight, fontSize: 18, letterSpacing: 4)),
          const SizedBox(height: 48),
          const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: WPColors.green200, strokeWidth: 2)),
          const SizedBox(height: 12),
          const Text('Turning waste into wealth', style: TextStyle(color: WPColors.green200, fontSize: 12)),
        ]),
      ),
    );
  }
}
