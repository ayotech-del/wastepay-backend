import '../core/config.dart';
// WastePay Nigeria — Home / Dashboard Screen (fully connected)
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/api_service.dart';
import '../models/models.dart' show DepositResult;
import 'contractor_bills_screen.dart';
import 'bin_locator_screen.dart';
import 'profile_screen.dart';
import 'operations_screen.dart';
import 'bin_lookup_screen.dart';

// ── HOME SCREEN ───────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  String? _userName;
  bool _loading = true;

  void _selectTab(int index) => setState(() => _tab = index);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final name = await ApiService.getStoredName();
      if (!mounted) return;
      setState(() {
        _userName = name;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _DashboardPage(userName: _userName, loading: _loading, onRefresh: _load),
      const DepositScreen(),
      const BinLocatorScreen(),
      const ContractorBillsScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      floatingActionButton: _tab == 0
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const OperationsScreen())),
              icon: const Icon(Icons.receipt_long),
              label: const Text('Bills & pickup'))
          : null,
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        height: 64,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.recycling_outlined),
              selectedIcon: Icon(Icons.recycling),
              label: 'Deposit'),
          NavigationDestination(
              icon: Icon(Icons.location_on_outlined),
              selectedIcon: Icon(Icons.location_on),
              label: 'Find Bins'),
          NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'Contractor'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile'),
        ],
      ),
    );
  }
}

// ── DASHBOARD PAGE ────────────────────────────────────────────────────────────
class _DashboardPage extends StatelessWidget {
  final String? userName;
  final bool loading;
  final VoidCallback onRefresh;

  const _DashboardPage(
      {required this.userName, required this.loading, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: loading
            ? const Center(
                child: CircularProgressIndicator(color: WPColors.green500))
            : RefreshIndicator(
                onRefresh: () async => onRefresh(),
                color: WPColors.green500,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Header(name: userName),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                            onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const ContractorBillsScreen())),
                            icon: const Icon(Icons.business),
                            label:
                                const Text('Select contractor & view bills')),
                        const SizedBox(height: 20),
                        _QuickActions(),
                        const SizedBox(height: 24),
                        const Text(
                            'Choose your contractor to view bills and collection services. Your payment details are entered securely at checkout.'),
                        const SizedBox(height: 80),
                      ]),
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Switch to deposit tab
          final homeState = context.findAncestorStateOfType<_HomeScreenState>();
          homeState?._selectTab(1);
        },
        backgroundColor: WPColors.green500,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Scan Bin',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String? name;
  const _Header({this.name});
  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Good morning,',
                style: TextStyle(fontSize: 13, color: WPColors.textMuted)),
            Text(name ?? 'Welcome!',
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: WPColors.green900)),
          ]),
          GestureDetector(
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
            child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                    color: WPColors.green50,
                    shape: BoxShape.circle,
                    border: Border.all(color: WPColors.green200)),
                child: const Icon(Icons.person_outline,
                    color: WPColors.green700, size: 22)),
          ),
        ],
      );
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final actions = [
      (
        Icons.qr_code,
        'Scan Bin',
        WPColors.green500,
        () {
          final s = context.findAncestorStateOfType<_HomeScreenState>();
          s?._selectTab(1);
        }
      ),
      (
        Icons.location_on,
        'Find Bins',
        WPColors.navy,
        () {
          final s = context.findAncestorStateOfType<_HomeScreenState>();
          s?._selectTab(2);
        }
      ),
      (
        Icons.electric_bolt,
        'Contractor',
        WPColors.gold,
        () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ContractorBillsScreen()))
      ),
      (
        Icons.leaderboard,
        'Rewards',
        WPColors.terracotta,
        () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Leaderboard coming soon!')))
      ),
    ];
    return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: actions
            .map((a) =>
                _ActionBtn(icon: a.$1, label: a.$2, color: a.$3, onTap: a.$4))
            .toList());
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Column(children: [
          Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withValues(alpha: 0.2))),
              child: Icon(icon, color: color, size: 26)),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  color: WPColors.textSecondary,
                  fontWeight: FontWeight.w500)),
        ]),
      );
}

class DepositScreen extends StatefulWidget {
  const DepositScreen({super.key});
  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  String _selectedType = 'plastic';
  final _weightCtrl = TextEditingController();
  final _binCtrl = TextEditingController();
  final _qrCtrl = TextEditingController();
  bool _submitting = false;
  DepositResult? _result;
  Map<String, double> _rates = AppConfig.creditRates;

  static const _types = [
    ('plastic', '♻️', 'Plastic'),
    ('paper', '📄', 'Paper'),
    ('glass', '🫙', 'Glass'),
    ('metal', '🔩', 'Metal'),
    ('organic', '🍃', 'Organic'),
    ('electronics', '📱', 'E-Waste'),
  ];

  double get _estimate =>
      (double.tryParse(_weightCtrl.text) ?? 0) * (_rates[_selectedType] ?? 100);

  @override
  void initState() {
    super.initState();
    ApiService.getCreditRates().then((r) {
      if (mounted) setState(() => _rates = r);
    });
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _binCtrl.dispose();
    _qrCtrl.dispose();
    super.dispose();
  }

  Future<void> _findBin() async {
    final bin = await Navigator.push<Map<String, dynamic>>(
        context, MaterialPageRoute(builder: (_) => const BinLookupScreen()));
    if (bin == null || !mounted) return;
    setState(() {
      _binCtrl.text = '${bin['id']}';
      _qrCtrl.text = '${bin['bin_code']}';
    });
  }

  Future<void> _submit() async {
    final w = double.tryParse(_weightCtrl.text);
    if (w == null || w <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid weight in kg')));
      return;
    }
    setState(() {
      _submitting = true;
      _result = null;
    });
    try {
      final bin = await ApiService.request(
          '/bins/lookup?identifier=${Uri.encodeQueryComponent(_binCtrl.text.trim())}');
      final enteredQr = _qrCtrl.text.trim();
      if (enteredQr.isNotEmpty && enteredQr != bin['bin_code']) {
        throw ApiException('QR code does not match the selected bin');
      }
      final result = await ApiService.submitDeposit(
          wasteType: _selectedType,
          weightKg: w,
          binId: '${bin['id']}',
          qrScanData: '${bin['bin_code']}');
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _result = result;
      });
      if (result.success) _weightCtrl.clear();
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _result = DepositResult.error('$e');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Submit Deposit'),
          automaticallyImplyLeading: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Select waste type',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: WPColors.textPrimary)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _types.map((t) {
              final selected = _selectedType == t.$1;
              return GestureDetector(
                onTap: () => setState(() {
                  _selectedType = t.$1;
                  _result = null;
                }),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? WPColors.green500 : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: selected
                            ? WPColors.green500
                            : const Color(0xFFDDDDDD)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(t.$2, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(t.$3,
                        style: TextStyle(
                            fontSize: 13,
                            color:
                                selected ? Colors.white : WPColors.textPrimary,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(width: 4),
                    Text('₦${(_rates[t.$1] ?? 0).toStringAsFixed(0)}/kg',
                        style: TextStyle(
                            fontSize: 10,
                            color: selected
                                ? Colors.white70
                                : WPColors.textMuted)),
                  ]),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
              onPressed: _submitting ? null : _findBin,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Find bin / Scan QR')),
          TextField(
              controller: _binCtrl,
              decoration: const InputDecoration(
                  labelText: 'Printed bin code or bin ID',
                  helperText: 'Use the code displayed at the collection bin')),
          TextField(
              controller: _qrCtrl,
              decoration: const InputDecoration(
                  labelText: 'Bin QR code',
                  helperText: 'Enter the code printed on the bin')),
          const SizedBox(height: 16),
          const Text('Weight (kg)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _weightCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
                hintText: 'e.g. 2.5',
                suffixText: 'kg',
                prefixIcon: Icon(Icons.scale_outlined, size: 20)),
          ),
          if (_weightCtrl.text.isNotEmpty &&
              double.tryParse(_weightCtrl.text) != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: WPColors.green50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: WPColors.green200)),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Estimated Eco Credits:',
                        style:
                            TextStyle(fontSize: 14, color: WPColors.green700)),
                    Text('₦${_estimate.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: WPColors.green900)),
                  ]),
            ),
          ],
          if (_result != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _result!.success
                    ? WPColors.green50
                    : const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: _result!.success
                        ? WPColors.green200
                        : const Color(0xFFFFCDD2)),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        _result!.success
                            ? 'Deposit submitted for verification'
                            : '❌ ${_result!.error}',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: _result!.success
                                ? WPColors.green900
                                : WPColors.terracotta)),
                    if (_result!.success) ...[
                      const SizedBox(height: 6),
                      const Text(
                          'Credits are awarded after trusted verification',
                          style: TextStyle(
                              color: WPColors.green700, fontSize: 13)),
                      const Text('No credits have been added yet',
                          style: TextStyle(
                              color: WPColors.textSecondary, fontSize: 12)),
                    ],
                  ]),
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Submit Deposit & Earn Credits'),
          ),
          const SizedBox(height: 30),
          // Rate table
          const Text('Current rates',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: WPColors.textSecondary)),
          const SizedBox(height: 8),
          ..._types.map((t) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Text(t.$2, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(t.$3,
                          style: const TextStyle(
                              fontSize: 13, color: WPColors.textSecondary))),
                  Text('₦${(_rates[t.$1] ?? 0).toStringAsFixed(0)}/kg',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: WPColors.green700)),
                ]),
              )),
        ]),
      ),
    );
  }
}
