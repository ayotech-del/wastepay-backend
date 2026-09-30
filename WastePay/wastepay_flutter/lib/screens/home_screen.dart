import '../core/config.dart';
// WastePay Nigeria — Home / Dashboard Screen (fully connected)
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'wallet_screen.dart';
import 'bin_locator_screen.dart';
import 'profile_screen.dart';
import 'operations_screen.dart';

// ── HOME SCREEN ───────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  WalletBalance? _balance;
  List<WalletTransaction> _txns = [];
  String? _userName;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.getBalance(),
        ApiService.getTransactions(limit: 10),
        ApiService.getStoredName(),
      ]);
      setState(() {
        _balance  = results[0] as WalletBalance;
        _txns     = results[1] as List<WalletTransaction>;
        _userName = results[2] as String?;
        _loading  = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _DashboardPage(balance: _balance, txns: _txns, userName: _userName, loading: _loading, onRefresh: _load),
      const DepositScreen(),
      const BinLocatorScreen(),
      const WalletScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      floatingActionButton: _tab == 0 ? FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OperationsScreen())),
        icon: const Icon(Icons.receipt_long), label: const Text('Bills & pickup')) : null,
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        height: 64,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.recycling_outlined), selectedIcon: Icon(Icons.recycling), label: 'Deposit'),
          NavigationDestination(icon: Icon(Icons.location_on_outlined), selectedIcon: Icon(Icons.location_on), label: 'Find Bins'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Wallet'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

// ── DASHBOARD PAGE ────────────────────────────────────────────────────────────
class _DashboardPage extends StatelessWidget {
  final WalletBalance? balance;
  final List<WalletTransaction> txns;
  final String? userName;
  final bool loading;
  final VoidCallback onRefresh;

  const _DashboardPage({required this.balance, required this.txns, required this.userName,
      required this.loading, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator(color: WPColors.green500))
            : RefreshIndicator(
                onRefresh: () async => onRefresh(),
                color: WPColors.green500,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _Header(name: userName),
                    const SizedBox(height: 20),
                    _BalanceCard(balance: balance),
                    const SizedBox(height: 20),
                    _QuickActions(),
                    const SizedBox(height: 24),
                    const _SectionTitle('Recent Activity'),
                    const SizedBox(height: 10),
                    if (txns.isEmpty)
                      const Center(child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text('No transactions yet.\nStart by depositing recyclables! ♻',
                            textAlign: TextAlign.center, style: TextStyle(color: WPColors.textMuted, fontSize: 13)),
                      ))
                    else
                      ...txns.take(5).map((t) => _TxnTile(txn: t)),
                    const SizedBox(height: 80),
                  ]),
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Switch to deposit tab
          final homeState = context.findAncestorStateOfType<_HomeScreenState>();
          homeState?.setState(() => homeState._tab = 1);
        },
        backgroundColor: WPColors.green500,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Scan Bin', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String? name;
  const _Header({this.name});
  @override Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Good morning,', style: TextStyle(fontSize: 13, color: WPColors.textMuted)),
        Text(name ?? 'Welcome!',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: WPColors.green900)),
      ]),
      GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
        child: Container(width: 42, height: 42,
            decoration: BoxDecoration(color: WPColors.green50, shape: BoxShape.circle,
                border: Border.all(color: WPColors.green200)),
            child: const Icon(Icons.person_outline, color: WPColors.green700, size: 22)),
      ),
    ],
  );
}

class _BalanceCard extends StatelessWidget {
  final WalletBalance? balance;
  const _BalanceCard({this.balance});

  @override Widget build(BuildContext context) {
    final credits  = balance?.ecoCredits ?? 0;
    final kg       = balance?.kgDeposited ?? 0;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WalletScreen())),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: WPColors.green900, borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Eco Credits Balance', style: TextStyle(color: WPColors.green200, fontSize: 13)),
          const SizedBox(height: 6),
          Text('₦${credits.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
          const SizedBox(height: 14),
          Row(children: [
            _StatPill('${kg.toStringAsFixed(1)}kg', 'recycled'),
            const SizedBox(width: 10),
            _StatPill('₦${(balance?.totalEarned ?? 0).toStringAsFixed(0)}', 'total earned'),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _CardBtn('Pay Bill', Icons.electric_bolt,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WalletScreen())))),
            const SizedBox(width: 10),
            Expanded(child: _CardBtn('Withdraw', Icons.account_balance,
                color: WPColors.gold,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WalletScreen())))),
          ]),
        ]),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String val, lbl;
  const _StatPill(this.val, this.lbl);
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(color: WPColors.green700.withOpacity(0.4), borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(val, style: const TextStyle(color: WPColors.goldLight, fontWeight: FontWeight.w600, fontSize: 13)),
      const SizedBox(width: 4),
      Text(lbl, style: const TextStyle(color: WPColors.green200, fontSize: 11)),
    ]),
  );
}

class _CardBtn extends StatelessWidget {
  final String label; final IconData icon; final VoidCallback onTap; final Color? color;
  const _CardBtn(this.label, this.icon, {required this.onTap, this.color});
  @override Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
          color: (color ?? Colors.white).withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: (color ?? Colors.white).withOpacity(0.3))),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: color ?? Colors.white, size: 15),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color ?? Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
      ]),
    ),
  );
}

class _QuickActions extends StatelessWidget {
  @override Widget build(BuildContext context) {
    final actions = [
      (Icons.qr_code, 'Scan Bin',   WPColors.green500, () { final s = context.findAncestorStateOfType<_HomeScreenState>(); s?.setState(() => s._tab = 1); }),
      (Icons.location_on, 'Find Bins', WPColors.navy,     () { final s = context.findAncestorStateOfType<_HomeScreenState>(); s?.setState(() => s._tab = 2); }),
      (Icons.electric_bolt, 'Pay Bill',  WPColors.gold,  () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WalletScreen()))),
      (Icons.leaderboard, 'Rewards',   WPColors.terracotta, () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Leaderboard coming soon!')))),
    ];
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: actions.map((a) => _ActionBtn(icon: a.$1, label: a.$2, color: a.$3, onTap: a.$4)).toList());
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.color, required this.onTap});
  @override Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(children: [
      Container(width: 58, height: 58,
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.2))),
          child: Icon(icon, color: color, size: 26)),
      const SizedBox(height: 6),
      Text(label, style: const TextStyle(fontSize: 11, color: WPColors.textSecondary, fontWeight: FontWeight.w500)),
    ]),
  );
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);
  @override Widget build(BuildContext context) =>
      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: WPColors.textPrimary));
}

class _TxnTile extends StatelessWidget {
  final WalletTransaction txn;
  const _TxnTile({required this.txn});
  @override Widget build(BuildContext context) {
    final isCredit = txn.isCredit;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFEEEEEE))),
      child: Row(children: [
        Container(width: 36, height: 36,
            decoration: BoxDecoration(color: (isCredit ? WPColors.green500 : WPColors.terracotta).withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(isCredit ? Icons.recycling : Icons.payment,
                color: isCredit ? WPColors.green500 : WPColors.terracotta, size: 17)),
        const SizedBox(width: 12),
        Expanded(child: Text(txn.description ?? txn.type,
            style: const TextStyle(fontSize: 13, color: WPColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis)),
        Text('${isCredit ? '+' : '-'}₦${txn.amount.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                color: isCredit ? WPColors.green500 : WPColors.terracotta)),
      ]),
    );
  }
}


// ── DEPOSIT SCREEN ─────────────────────────────────────────────────────────────
class DepositScreen extends StatefulWidget {
  const DepositScreen({super.key});
  @override State<DepositScreen> createState() => _DepositScreenState();
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
    ('plastic',     '♻️', 'Plastic'),
    ('paper',       '📄', 'Paper'),
    ('glass',       '🫙', 'Glass'),
    ('metal',       '🔩', 'Metal'),
    ('organic',     '🍃', 'Organic'),
    ('electronics', '📱', 'E-Waste'),
  ];

  double get _estimate => (double.tryParse(_weightCtrl.text) ?? 0) * (_rates[_selectedType] ?? 100);

  @override
  void initState() {
    super.initState();
    ApiService.getCreditRates().then((r) { if (mounted) setState(() => _rates = r); });
  }

  Future<void> _submit() async {
    final w = double.tryParse(_weightCtrl.text);
    if (w == null || w <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid weight in kg')));
      return;
    }
    setState(() { _submitting = true; _result = null; });
    try {
      final result = await ApiService.submitDeposit(wasteType: _selectedType, weightKg: w, binId: _binCtrl.text.trim(), qrScanData: _qrCtrl.text.trim());
      if (!mounted) return;
      setState(() { _submitting = false; _result = result; });
      if (result.success) _weightCtrl.clear();
    } catch (e) {
      if (mounted) setState(() { _submitting = false; _result = DepositResult.error('$e'); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Submit Deposit'), automaticallyImplyLeading: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Select waste type', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: WPColors.textPrimary)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _types.map((t) {
              final selected = _selectedType == t.$1;
              return GestureDetector(
                onTap: () => setState(() { _selectedType = t.$1; _result = null; }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? WPColors.green500 : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: selected ? WPColors.green500 : const Color(0xFFDDDDDD)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(t.$2, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(t.$3, style: TextStyle(fontSize: 13, color: selected ? Colors.white : WPColors.textPrimary, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 4),
                    Text('₦${(_rates[t.$1] ?? 0).toStringAsFixed(0)}/kg',
                        style: TextStyle(fontSize: 10, color: selected ? Colors.white70 : WPColors.textMuted)),
                  ]),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          TextField(controller: _binCtrl, decoration: const InputDecoration(labelText: 'Bin ID', helperText: 'Use the ID displayed at the collection bin')),
          TextField(controller: _qrCtrl, decoration: const InputDecoration(labelText: 'Bin QR code', helperText: 'Enter the code printed on the bin')),
          const SizedBox(height: 16),
          const Text('Weight (kg)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _weightCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'e.g. 2.5', suffixText: 'kg',
                prefixIcon: Icon(Icons.scale_outlined, size: 20)),
          ),
          if (_weightCtrl.text.isNotEmpty && double.tryParse(_weightCtrl.text) != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: WPColors.green50, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: WPColors.green200)),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Estimated Eco Credits:', style: TextStyle(fontSize: 14, color: WPColors.green700)),
                Text('₦${_estimate.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: WPColors.green900)),
              ]),
            ),
          ],
          if (_result != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _result!.success ? WPColors.green50 : const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _result!.success ? WPColors.green200 : const Color(0xFFFFCDD2)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_result!.success ? 'Deposit submitted for verification' : '❌ ${_result!.error}',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14,
                        color: _result!.success ? WPColors.green900 : WPColors.terracotta)),
                if (_result!.success) ...[
                  const SizedBox(height: 6),
                  Text('Credits are awarded after trusted verification',
                      style: const TextStyle(color: WPColors.green700, fontSize: 13)),
                  Text('No credits have been added yet',
                      style: const TextStyle(color: WPColors.textSecondary, fontSize: 12)),
                ],
              ]),
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Submit Deposit & Earn Credits'),
          ),
          const SizedBox(height: 30),
          // Rate table
          const Text('Current rates', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: WPColors.textSecondary)),
          const SizedBox(height: 8),
          ..._types.map((t) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Text(t.$2, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Expanded(child: Text(t.$3, style: const TextStyle(fontSize: 13, color: WPColors.textSecondary))),
              Text('₦${(_rates[t.$1] ?? 0).toStringAsFixed(0)}/kg',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: WPColors.green700)),
            ]),
          )),
        ]),
      ),
    );
  }
}

