import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'auth_screen.dart';
import 'home_screen.dart';
import 'government_screen.dart';
import 'company_dashboard_screen.dart';
import 'contractor/verified_routes_screen.dart';

class RoleHomeScreen extends StatefulWidget {
  const RoleHomeScreen({super.key});
  @override
  State<RoleHomeScreen> createState() => _RoleHomeScreenState();
}

class _RoleHomeScreenState extends State<RoleHomeScreen> {
  Map<String, dynamic>? _profile;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final data = await ApiService.request('/users/me');
      if (mounted) setState(() => _profile = Map<String, dynamic>.from(data));
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _signIn() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (_profile != null) {
      final permissions = List<String>.from(_profile!['permissions'] ?? []);
      if (permissions.contains('government.view')) {
        return const GovernmentScreen();
      }
      if (permissions.contains('company.view')) {
        return const CompanyDashboardScreen();
      }
      if (permissions.contains('driver.work')) {
        return const VerifiedRoutesScreen();
      }
      return const HomeScreen();
    }
    return Scaffold(
        body: Center(
            child: _error == null
                ? const CircularProgressIndicator()
                : Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_error!),
                    TextButton(onPressed: _load, child: const Text('Retry')),
                    TextButton(
                        onPressed: _signIn, child: const Text('Sign in again')),
                  ])));
  }
}
