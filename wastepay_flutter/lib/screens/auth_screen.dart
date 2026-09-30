// WastePay — Auth Screens (Login + Register)
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/api_service.dart';
import 'role_home_screen.dart';

// ── LOGIN SCREEN ─────────────────────────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  Future<void> _login() async {
    if (_phoneCtrl.text.isEmpty || _passwordCtrl.text.isEmpty) {
      setState(() => _error = 'Please fill in all fields');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final result = await ApiService.login(
      phone: _phoneCtrl.text.trim(),
      password: _passwordCtrl.text,
    );
    setState(() => _loading = false);
    if (!mounted) return;
    if (result.success) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const RoleHomeScreen()),
      );
    } else {
      setState(() => _error = result.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              // Logo
              Container(
                width: 64, height: 64,
                decoration: const BoxDecoration(color: WPColors.green900, shape: BoxShape.circle),
                child: const Center(child: Text('♻', style: TextStyle(fontSize: 30))),
              ),
              const SizedBox(height: 20),
              const Text('Welcome back', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: WPColors.green900)),
              const Text('Sign in to WastePay', style: TextStyle(fontSize: 15, color: WPColors.textSecondary)),
              const SizedBox(height: 36),

              // Phone
              const _Label('Phone number'),
              const SizedBox(height: 6),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  hintText: '+234 800 000 0000',
                  prefixIcon: Icon(Icons.phone_outlined, size: 20),
                ),
              ),
              const SizedBox(height: 16),

              // Password
              const _Label('Password'),
              const SizedBox(height: 6),
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscure,
                onSubmitted: (_) => _login(),
                decoration: InputDecoration(
                  hintText: '••••••••',
                  prefixIcon: const Icon(Icons.lock_outline, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                _ErrorBanner(_error!),
              ],

              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _loading ? null : _login,
                child: _loading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Sign in'),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account? ", style: TextStyle(color: WPColors.textSecondary)),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                    child: const Text('Register', style: TextStyle(color: WPColors.green500, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ── REGISTER SCREEN ───────────────────────────────────────────────────────────
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl     = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl  = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  Future<void> _register() async {
    if (_nameCtrl.text.isEmpty || _phoneCtrl.text.isEmpty || _passwordCtrl.text.isEmpty) {
      setState(() => _error = 'Please fill in all required fields');
      return;
    }
    if (_passwordCtrl.text != _confirmCtrl.text) {
      setState(() => _error = 'Passwords do not match');
      return;
    }
    if (_passwordCtrl.text.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final result = await ApiService.register(
      phone:    _phoneCtrl.text.trim(),
      fullName: _nameCtrl.text.trim(),
      password: _passwordCtrl.text,
      email:    _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
    );
    setState(() => _loading = false);
    if (!mounted) return;
    if (result.success) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RoleHomeScreen()),
        (_) => false,
      );
    } else {
      setState(() => _error = result.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account'), leading: const BackButton()),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Join WastePay', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: WPColors.green900)),
            const Text('Earn Eco Credits for recycling in Nigeria', style: TextStyle(fontSize: 14, color: WPColors.textSecondary)),
            const SizedBox(height: 28),

            const _Label('Full name *'),
            const SizedBox(height: 6),
            TextField(controller: _nameCtrl, textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(hintText: 'Example User', prefixIcon: Icon(Icons.person_outline, size: 20))),
            const SizedBox(height: 14),

            const _Label('Phone number *'),
            const SizedBox(height: 6),
            TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone,
                decoration: const InputDecoration(hintText: 'YOUR_PHONE_NUMBER', prefixIcon: Icon(Icons.phone_outlined, size: 20))),
            const SizedBox(height: 14),

            const _Label('Email (optional)'),
            const SizedBox(height: 6),
            TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(hintText: 'user@example.invalid', prefixIcon: Icon(Icons.email_outlined, size: 20))),
            const SizedBox(height: 14),

            const _Label('Password *'),
            const SizedBox(height: 6),
            TextField(
              controller: _passwordCtrl, obscureText: _obscure,
              decoration: InputDecoration(
                hintText: 'Min. 8 characters',
                prefixIcon: const Icon(Icons.lock_outline, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 14),

            const _Label('Confirm password *'),
            const SizedBox(height: 6),
            TextField(
              controller: _confirmCtrl, obscureText: _obscure,
              onSubmitted: (_) => _register(),
              decoration: const InputDecoration(hintText: 'Repeat password', prefixIcon: Icon(Icons.lock_outline, size: 20)),
            ),

            if (_error != null) ...[const SizedBox(height: 12), _ErrorBanner(_error!)],

            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: WPColors.green50, borderRadius: BorderRadius.circular(8)),
              child: const Row(children: [
                Icon(Icons.info_outline, size: 16, color: WPColors.green700),
                SizedBox(width: 8),
                Expanded(child: Text('You start at KYC Tier 1 (₦20K daily limit). Upgrade anytime with NIN/BVN.',
                    style: TextStyle(fontSize: 12, color: WPColors.green700))),
              ]),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _loading ? null : _register,
              child: _loading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Create account'),
            ),
            const SizedBox(height: 20),
            Center(child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: const Text('Already registered? Sign in', style: TextStyle(color: WPColors.green500, fontWeight: FontWeight.w500)),
            )),
          ],
        ),
      ),
    );
  }
}


// ── Shared widgets ────────────────────────────────────────────────────────────
class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: WPColors.textPrimary));
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner(this.message);
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(8)),
    child: Row(children: [
      const Icon(Icons.error_outline, size: 16, color: WPColors.terracotta),
      const SizedBox(width: 8),
      Expanded(child: Text(message, style: const TextStyle(fontSize: 13, color: WPColors.terracotta))),
    ]),
  );
}
