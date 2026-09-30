import 'operations_screen.dart';
import 'government_screen.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/theme.dart';
import '../core/config.dart';
import '../services/api_service.dart';
import 'auth_screen.dart';
import 'lga_selector_screen.dart';
import 'contractor/verified_routes_screen.dart';
import 'customer_onboarding_screen.dart';
import 'customer_payment_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _name, _kycTier;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final name = await ApiService.getStoredName();
    final kyc  = await ApiService.getStoredKYC();
    setState(() { _name = name; _kycTier = kyc; });
  }

  String get _tierLabel => _kycTier == 'tier_2' ? 'Tier 2 — NIN Verified' : _kycTier == 'tier_3' ? 'Tier 3 — Full KYC' : 'Tier 1 — Basic';
  String get _tierLimit => _kycTier == 'tier_2' ? '₦200,000/day' : _kycTier == 'tier_3' ? '₦5,000,000/day' : '₦20,000/day';

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(context: context,
      builder: (_) => AlertDialog(title: const Text('Sign out?'),
        content: const Text('You will need to sign in again to access your account.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign out')),
        ]));
    if (confirm == true) {
      await ApiService.logout();
      if (mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile'), automaticallyImplyLeading: false),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // Avatar
        Center(child: Column(children: [
          Container(width: 72, height: 72, decoration: const BoxDecoration(color: WPColors.green500, shape: BoxShape.circle),
              child: Center(child: Text((_name ?? 'U').substring(0, 1).toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700)))),
          const SizedBox(height: 10),
          Text(_name ?? 'Loading...', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: WPColors.green50, borderRadius: BorderRadius.circular(20)),
            child: Text(_tierLabel, style: const TextStyle(color: WPColors.green700, fontSize: 12, fontWeight: FontWeight.w500))),
        ])),
        const SizedBox(height: 20),

        // KYC
        _ST('KYC & Limits'),
        _IT(Icons.verified_user_outlined, 'Verification level', _tierLabel),
        _IT(Icons.account_balance_wallet_outlined, 'Daily limit', _tierLimit),
        const SizedBox(height: 16),

        // Customer section
        _ST('Customer Services'),
        _MT(Icons.payments_outlined, 'Pay Waste Levy',
            subtitle: 'Filter by State, LGA, BIN, Contractor',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OperationsScreen()))),
        _MT(Icons.home_outlined, 'Set Up My Account',
            subtitle: 'Register your household BIN number',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OperationsScreen()))),
        _MT(Icons.recycling_outlined, 'Find Smart Bins',
            subtitle: 'Nearby bins to earn Eco Credits',
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Use the Find Bins tab below')))),
        const SizedBox(height: 16),

        // Government section — clearly labelled
        _ST('Government Portal'),
        Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(8), border: Border.all(color: WPColors.gold)),
          child: const Row(children: [
            Icon(Icons.lock_outlined, color: WPColors.gold, size: 14),
            SizedBox(width: 8),
            Expanded(child: Text('Government access only. Unauthorised access is prohibited.',
                style: TextStyle(fontSize: 11, color: WPColors.navy))),
          ])),
        _MT(Icons.account_balance_outlined, 'State Dashboard',
            subtitle: 'LGA oversight, billing & company registry',
            onTap: () => _confirmGovAccess(context)),
        const SizedBox(height: 16),

        // Contractor section — clearly labelled
        _ST('Contractor Portal'),
        Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(8), border: Border.all(color: WPColors.green200)),
          child: const Row(children: [
            Icon(Icons.local_shipping_outlined, color: WPColors.green700, size: 14),
            SizedBox(width: 8),
            Expanded(child: Text('For registered waste contractors only. Login with your contractor credentials.',
                style: TextStyle(fontSize: 11, color: WPColors.green900))),
          ])),
        _MT(Icons.local_shipping_outlined, 'Contractor Driver App',
            subtitle: 'Route map, bin collection, earnings',
            onTap: () => _confirmContractorAccess(context)),
        const SizedBox(height: 16),

        // Account
        _ST('Account'),
        _MT(Icons.notifications_outlined, 'Notifications', onTap: () {}),
        _MT(Icons.security_outlined, 'Security & Privacy', onTap: () {}),
        _MT(Icons.help_outline, 'Help & Support', onTap: () {}),
        _MT(Icons.info_outline, 'About WastePay', onTap: () => showAboutDialog(
            context: context, applicationName: 'WastePay Nigeria', applicationVersion: '2.0.0')),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          icon: const Icon(Icons.logout, size: 18, color: WPColors.terracotta),
          label: const Text('Sign out', style: TextStyle(color: WPColors.terracotta)),
          onPressed: _logout,
          style: OutlinedButton.styleFrom(side: const BorderSide(color: WPColors.terracotta), minimumSize: const Size.fromHeight(48))),
        const SizedBox(height: 20),
        const Center(child: Text('WastePay Nigeria v2.0.0\nTurning waste into wealth',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: WPColors.textMuted))),
        const SizedBox(height: 20),
      ]),
    );
  }

  void _confirmGovAccess(BuildContext context) {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Row(children: [Icon(Icons.lock_outlined, color: WPColors.gold, size: 20), SizedBox(width: 8), Text('Government Access')]),
      content: const Text('This area is for authorised government officials only.\n\nAre you a registered LGA or State Government official?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const GovernmentScreen()));
        }, child: const Text('Yes, I am authorised')),
      ]));
  }

  void _confirmContractorAccess(BuildContext context) {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Row(children: [Icon(Icons.local_shipping_outlined, color: WPColors.green500, size: 20), SizedBox(width: 8), Text('Contractor Access')]),
      content: const Text('This portal is for registered WastePay contractors only.\n\nAre you a registered waste contractor with a WastePay Truck ID?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const VerifiedRoutesScreen()));
        }, child: const Text('Yes, I am a contractor')),
      ]));
  }
}

class _ST extends StatelessWidget {
  final String t; const _ST(this.t);
  @override Widget build(BuildContext c) => Padding(padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: WPColors.textMuted, letterSpacing: 0.5)));
}

class _IT extends StatelessWidget {
  final IconData icon; final String label, value;
  const _IT(this.icon, this.label, this.value);
  @override Widget build(BuildContext c) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFEEEEEE))),
    child: Row(children: [
      Icon(icon, size: 18, color: WPColors.green500), const SizedBox(width: 12),
      Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: WPColors.textSecondary))),
      Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
    ]));
}

class _MT extends StatelessWidget {
  final IconData icon; final String label; final String? subtitle; final VoidCallback onTap;
  const _MT(this.icon, this.label, {this.subtitle, required this.onTap});
  @override Widget build(BuildContext c) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFEEEEEE))),
    child: ListTile(
      leading: Icon(icon, color: WPColors.green500, size: 20),
      title: Text(label, style: const TextStyle(fontSize: 13)),
      subtitle: subtitle != null ? Text(subtitle!, style: const TextStyle(fontSize: 11, color: WPColors.textMuted)) : null,
      trailing: const Icon(Icons.chevron_right, color: WPColors.textMuted, size: 18),
      onTap: onTap, dense: true));
}
