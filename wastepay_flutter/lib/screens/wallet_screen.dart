// WastePay — Wallet Screen
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});
  @override State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  WalletBalance? _balance;
  List<WalletTransaction> _txns = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final bal  = await ApiService.getBalance();
      final txns = await ApiService.getTransactions(limit: 30);
      setState(() { _balance = bal; _txns = txns; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WPColors.green900,
      body: Column(children: [
        // Dark header
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(children: [
              Row(children: [
                const BackButton(color: Colors.white),
                const SizedBox(width: 4),
                const Text('My Wallet', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _load),
              ]),
              const SizedBox(height: 20),
              if (_balance != null) ...[
                const Text('Eco Credit Balance', style: TextStyle(color: WPColors.green200, fontSize: 13)),
                const SizedBox(height: 6),
                Text('₦${_balance!.ecoCredits.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w700, letterSpacing: -1)),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  _StatPill('₦${_balance!.totalEarned.toStringAsFixed(0)}', 'earned'),
                  _StatPill('₦${_balance!.totalRedeemed.toStringAsFixed(0)}', 'redeemed'),
                  _StatPill('${_balance!.kgDeposited.toStringAsFixed(1)}kg', 'recycled'),
                ]),
              ] else if (_loading)
                const CircularProgressIndicator(color: WPColors.green200),
              const SizedBox(height: 20),
              // Action buttons
              Row(children: [
                Expanded(child: _ActionBtn(icon: Icons.electric_bolt, label: 'Pay Bill',
                    onTap: () => _showRedeemSheet(context))),
                const SizedBox(width: 12),
                Expanded(child: _ActionBtn(icon: Icons.account_balance_outlined, label: 'Withdraw',
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Tier 3 KYC required for withdrawals'))))),
              ]),
            ]),
          ),
        ),

        // White card body
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(top: 20),
            decoration: const BoxDecoration(
              color: WPColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(children: [
              // Tabs
              Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                decoration: BoxDecoration(color: WPColors.green50, borderRadius: BorderRadius.circular(10)),
                child: TabBar(
                  controller: _tabs,
                  indicator: BoxDecoration(color: WPColors.green500, borderRadius: BorderRadius.circular(8)),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: WPColors.textSecondary,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  tabs: const [Tab(text: 'All Transactions'), Tab(text: 'Credits Earned')],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: WPColors.green500))
                    : TabBarView(controller: _tabs, children: [
                        _TxnList(txns: _txns),
                        _TxnList(txns: _txns.where((t) => t.isCredit).toList()),
                      ]),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  void _showRedeemSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _RedeemSheet(balance: _balance?.ecoCredits ?? 0, onSuccess: _load),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String value, label;
  const _StatPill(this.value, this.label);
  @override Widget build(BuildContext context) => Column(children: [
    Text(value, style: const TextStyle(color: WPColors.goldLight, fontWeight: FontWeight.w700, fontSize: 15)),
    Text(label,  style: const TextStyle(color: WPColors.green200, fontSize: 11)),
  ]);
}

class _ActionBtn extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.onTap});
  @override Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: WPColors.green700.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: WPColors.goldLight, size: 18),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
      ]),
    ),
  );
}

class _TxnList extends StatelessWidget {
  final List<WalletTransaction> txns;
  const _TxnList({required this.txns});
  @override Widget build(BuildContext context) {
    if (txns.isEmpty) return const Center(child: Text('No transactions yet', style: TextStyle(color: WPColors.textMuted)));
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: txns.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final t = txns[i];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFEEEEEE)),
          ),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: (t.isCredit ? WPColors.green500 : WPColors.terracotta).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(t.isCredit ? Icons.recycling : Icons.payment,
                  color: t.isCredit ? WPColors.green500 : WPColors.terracotta, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.description ?? t.type, style: const TextStyle(fontSize: 13, color: WPColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(t.createdAt.split('T').first, style: const TextStyle(fontSize: 11, color: WPColors.textMuted)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${t.isCredit ? '+' : '-'}₦${t.amount.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                      color: t.isCredit ? WPColors.green500 : WPColors.terracotta)),
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: WPColors.green50, borderRadius: BorderRadius.circular(4)),
                  child: Text(t.status, style: const TextStyle(fontSize: 10, color: WPColors.green700))),
            ]),
          ]),
        );
      },
    );
  }
}

class _RedeemSheet extends StatefulWidget {
  final double balance;
  final VoidCallback onSuccess;
  const _RedeemSheet({required this.balance, required this.onSuccess});
  @override State<_RedeemSheet> createState() => _RedeemSheetState();
}

class _RedeemSheetState extends State<_RedeemSheet> {
  final _amountCtrl  = TextEditingController();
  final _refCtrl     = TextEditingController();
  String _biller = 'PHCN';
  bool _loading = false;
  String? _error, _success;

  final _billers = ['PHCN', 'DSTV', 'MTN-AIRTIME', 'GLO-AIRTIME', 'AIRTEL-AIRTIME'];

  Future<void> _redeem() async {
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) { setState(() => _error = 'Enter a valid amount'); return; }
    if (amount > widget.balance) { setState(() => _error = 'Insufficient credits (₦${widget.balance.toStringAsFixed(2)} available)'); return; }
    if (_refCtrl.text.isEmpty) { setState(() => _error = 'Enter your account/meter number'); return; }
    setState(() { _loading = true; _error = null; });
    final r = await ApiService.redeemCredits(amount: amount, billerCode: _biller, customerRef: _refCtrl.text.trim());
    setState(() { _loading = false; });
    if (r.success) {
      setState(() => _success = '✅ ₦${amount.toStringAsFixed(2)} payment initiated! Ref: ${r.reference}');
      widget.onSuccess();
    } else {
      setState(() => _error = r.error);
    }
  }

  @override Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Pay with Eco Credits', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      Text('Available: ₦${widget.balance.toStringAsFixed(2)}', style: const TextStyle(color: WPColors.green500, fontSize: 13)),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        initialValue: _biller, items: _billers.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
        onChanged: (v) => setState(() => _biller = v!),
        decoration: const InputDecoration(labelText: 'Biller', prefixIcon: Icon(Icons.receipt_long_outlined, size: 20)),
      ),
      const SizedBox(height: 12),
      TextField(controller: _refCtrl,
          decoration: const InputDecoration(labelText: 'Meter / account number', prefixIcon: Icon(Icons.tag, size: 20))),
      const SizedBox(height: 12),
      TextField(controller: _amountCtrl, keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Amount (₦)', prefixText: '₦ ', prefixIcon: Icon(Icons.money, size: 20))),
      if (_error   != null) ...[const SizedBox(height: 10), Text(_error!, style: const TextStyle(color: WPColors.terracotta, fontSize: 13))],
      if (_success != null) ...[const SizedBox(height: 10), Text(_success!, style: const TextStyle(color: WPColors.green500, fontSize: 13))],
      const SizedBox(height: 20),
      ElevatedButton(
        onPressed: _loading || _success != null ? null : _redeem,
        child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Pay Now'),
      ),
      const SizedBox(height: 20),
    ]),
  );
}
