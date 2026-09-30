import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'auth_screen.dart';
import 'home_screen.dart';
import 'operations_screen.dart';
import 'bin_locator_screen.dart';
import 'government_screen.dart';
import 'company_dashboard_screen.dart';
import 'role_access_screen.dart';
import 'contractor/verified_routes_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await ApiService.request('/users/me');
      if (mounted) {
        setState(() {
          _profile = Map<String, dynamic>.from(profile);
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  bool _can(String permission) =>
      (_profile?['permissions'] as List? ?? []).contains(permission);
  void _open(Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  Future<void> _logout() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  Widget _menu(IconData icon, String title, Widget page, {String? subtitle}) =>
      Card(
          child: ListTile(
              leading: Icon(icon),
              title: Text(title),
              subtitle: subtitle == null ? null : Text(subtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(page)));
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('My Profile'), actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh))
        ]),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          if (_profile == null && _error == null)
            const LinearProgressIndicator(),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          if (_profile != null) ...[
            Text('${_profile!['full_name']}',
                style: Theme.of(context).textTheme.titleLarge),
            Text('${_profile!['phone']}'),
            SelectableText('User ID: ${_profile!['id']}'),
            Text('Access: ${(_profile!['roles'] as List).join(', ')}'),
          ],
          const SizedBox(height: 20),
          if (_can('government.view'))
            _menu(Icons.account_balance, 'State Dashboard',
                const GovernmentScreen(),
                subtitle: 'Government operations in your assigned areas'),
          if (_can('government.operations'))
            _menu(Icons.app_registration, 'Contractor registration',
                const GovernmentScreen(registerContractor: true)),
          if (_can('company.view'))
            _menu(Icons.business, 'My contractor company',
                const CompanyDashboardScreen()),
          if (_can('driver.work'))
            _menu(Icons.local_shipping, 'Contractor Driver App',
                const VerifiedRoutesScreen(),
                subtitle: 'Your assigned collection routes'),
          if (_can('access.manage'))
            _menu(Icons.admin_panel_settings, 'Manage user roles',
                const RoleAccessScreen()),
          const Divider(),
          _menu(Icons.home, 'My consumer dashboard', const HomeScreen()),
          _menu(Icons.payments, 'My bills & pickups', const OperationsScreen()),
          _menu(Icons.recycling, 'Find Smart Bins', const BinLocatorScreen()),
          const SizedBox(height: 20),
          OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text('Sign out')),
        ]),
      );
}
