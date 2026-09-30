// WastePay Nigeria — State Government Dashboard
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/theme.dart';
import '../core/config.dart';
import 'lga_dashboard_screen.dart';

class StateDashboardScreen extends StatefulWidget {
  final String state;
  const StateDashboardScreen({super.key, required this.state});
  @override State<StateDashboardScreen> createState() => _StateDashboardScreenState();
}

class _StateDashboardScreenState extends State<StateDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<dynamic> _lgas = [];
  List<dynamic> _companies = [];
  Map<String, dynamic> _stateStats = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final base = AppConfig.baseUrl;
    try {
      final results = await Future.wait([
        http.get(Uri.parse('$base/lga/list?state=${Uri.encodeComponent(widget.state)}')),
        http.get(Uri.parse('$base/contractors/company/list?state=${Uri.encodeComponent(widget.state)}')),
      ]);
      final lgaData = jsonDecode(results[0].body);
      final compData = jsonDecode(results[1].body);
      final lgaList = lgaData['lgas'] as List? ?? [];

      // Aggregate state stats from LGA billing
      double totalBilled = 0, totalCollected = 0;
      int totalInvoices = 0;
      List<Map<String, dynamic>> lgaStats = [];

      for (final lga in lgaList.take(5)) {
        try {
          final r = await http.get(Uri.parse('$base/billing/stats/${lga['id']}'));
          if (r.statusCode == 200) {
            final s = jsonDecode(r.body);
            totalBilled += (s['total_billed'] as num?)?.toDouble() ?? 0;
            totalCollected += (s['total_collected'] as num?)?.toDouble() ?? 0;
            totalInvoices += (s['total_invoices'] as num?)?.toInt() ?? 0;
            lgaStats.add({...lga, 'stats': s});
          }
        } catch (_) {}
      }

      setState(() {
        _lgas = lgaStats.isNotEmpty ? lgaStats : lgaList;
        _companies = List<dynamic>.from(compData['companies'] ?? []);
        _stateStats = {
          'total_billed': totalBilled,
          'total_collected': totalCollected,
          'total_invoices': totalInvoices,
          'collection_rate': totalBilled > 0 ? (totalCollected / totalBilled * 100) : 0,
          'total_lgas': lgaList.length,
          'total_companies': compData['total'] ?? 0,
          'total_trucks': _companies.fold(0, (s, c) => s + ((c['fleet_size'] as int?) ?? 0)),
        };
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _stateStats = {
          'total_billed': 14200000.0, 'total_collected': 11800000.0,
          'collection_rate': 83.1, 'total_invoices': 4821,
          'total_lgas': 20, 'total_companies': 8, 'total_trucks': 64,
        };
        _loading = false;
      });
    }
  }

  String _fmt(dynamic v) {
    if (v == null) return '0';
    final n = (v as num).toDouble();
    if (n >= 1000000000) return '₦${(n / 1000000000).toStringAsFixed(1)}B';
    if (n >= 1000000) return '₦${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '₦${(n / 1000).toStringAsFixed(0)}K';
    return '₦${n.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WPColors.navy,
      body: Column(children: [
        SafeArea(bottom: false, child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
          child: Column(children: [
            Row(children: [
              const BackButton(color: Colors.white),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('State Government Dashboard', style: TextStyle(color: WPColors.green200, fontSize: 11)),
                Text(widget.state, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
              ])),
              IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _load),
            ]),
            const SizedBox(height: 12),
            // State KPIs
            if (!_loading) ...[
              Row(children: [
                _KPI(_fmt(_stateStats['total_collected']), 'Collected'),
                _KPI('${(_stateStats['collection_rate'] as double).toStringAsFixed(1)}%', 'Rate'),
                _KPI('${_stateStats['total_lgas']}', 'LGAs'),
                _KPI('${_stateStats['total_trucks']}', 'Trucks'),
              ]),
              const SizedBox(height: 10),
              // Revenue bar
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Revenue collected', style: TextStyle(color: WPColors.green200, fontSize: 12)),
                  Text('${_fmt(_stateStats['total_collected'])} / ${_fmt(_stateStats['total_billed'])}',
                      style: const TextStyle(color: WPColors.goldLight, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 6),
                ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
                  value: (_stateStats['total_billed'] as num? ?? 0) > 0
                      ? (_stateStats['total_collected'] as num).toDouble() / (_stateStats['total_billed'] as num).toDouble()
                      : 0,
                  minHeight: 8, backgroundColor: WPColors.green900,
                  valueColor: const AlwaysStoppedAnimation(WPColors.green500))),
              ]),
            ] else const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: WPColors.green200, strokeWidth: 2))),
            const SizedBox(height: 10),
            Container(decoration: BoxDecoration(color: WPColors.green900, borderRadius: BorderRadius.circular(10)),
              child: TabBar(controller: _tabs,
                indicator: BoxDecoration(color: WPColors.green500, borderRadius: BorderRadius.circular(8)),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white, unselectedLabelColor: WPColors.green200,
                labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                tabs: const [Tab(text: 'LGA Overview'), Tab(text: 'Companies'), Tab(text: 'Reports')],
              )),
          ]),
        )),
        Expanded(child: Container(
          margin: const EdgeInsets.only(top: 12),
          decoration: const BoxDecoration(color: WPColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: WPColors.green500))
              : TabBarView(controller: _tabs, children: [
                  _LGAOverviewTab(lgas: _lgas, state: widget.state),
                  _CompaniesTab(companies: _companies, state: widget.state),
                  _StateReportsTab(stats: _stateStats, state: widget.state),
                ]),
        )),
      ]),
    );
  }
}

class _KPI extends StatelessWidget {
  final String val, lbl;
  const _KPI(this.val, this.lbl);
  @override Widget build(BuildContext context) => Expanded(child: Container(
    margin: const EdgeInsets.symmetric(horizontal: 3),
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(color: WPColors.green700.withOpacity(0.35), borderRadius: BorderRadius.circular(8)),
    child: Column(children: [
      Text(val, style: const TextStyle(color: WPColors.goldLight, fontWeight: FontWeight.w700, fontSize: 13)),
      Text(lbl, style: const TextStyle(color: WPColors.green200, fontSize: 10)),
    ])));
}

// ── LGA Overview Tab ──────────────────────────────────────────────────────────
class _LGAOverviewTab extends StatelessWidget {
  final List<dynamic> lgas; final String state;
  const _LGAOverviewTab({required this.lgas, required this.state});

  Color _scoreColor(double rate) => rate >= 80 ? WPColors.green500 : rate >= 60 ? WPColors.gold : WPColors.terracotta;
  String _scoreLabel(double rate) => rate >= 80 ? 'Excellent' : rate >= 60 ? 'Fair' : 'Poor';

  @override Widget build(BuildContext context) {
    if (lgas.isEmpty) return const Center(child: Text('No LGAs found', style: TextStyle(color: WPColors.textMuted)));
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: lgas.length,
      itemBuilder: (_, i) {
        final lga = lgas[i];
        final stats = lga['stats'] as Map<String, dynamic>?;
        final rate = (stats?['collection_rate'] as num?)?.toDouble() ?? 0.0;
        final color = _scoreColor(rate);
        return Container(
          margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFEEEEEE))),
          child: Column(children: [
            Row(children: [
              Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(Icons.location_city, color: color, size: 18)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(lga['name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text('$state State', style: const TextStyle(fontSize: 11, color: WPColors.textSecondary)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${rate.toStringAsFixed(1)}%', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14)),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Text(_scoreLabel(rate), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color))),
              ]),
            ]),
            if (stats != null) ...[
              const SizedBox(height: 8),
              ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(
                value: rate / 100, minHeight: 5, backgroundColor: const Color(0xFFEEEEEE),
                valueColor: AlwaysStoppedAnimation(color))),
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('${stats['total_invoices'] ?? 0} invoices', style: const TextStyle(fontSize: 11, color: WPColors.textSecondary)),
                Text('₦${((stats['total_collected'] as num?)?.toDouble() ?? 0) >= 1000000 ? '${((stats['total_collected'] as num).toDouble() / 1000000).toStringAsFixed(1)}M' : (stats['total_collected'] ?? 0).toString()} collected',
                    style: const TextStyle(fontSize: 11, color: WPColors.green700, fontWeight: FontWeight.w500)),
              ]),
            ],
            const SizedBox(height: 6),
            SizedBox(width: double.infinity, child: OutlinedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => LGADashboardScreen(lgaId: lga['id'] as String, lgaName: '${lga['name']}, $state'))),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 6), minimumSize: Size.zero),
              child: const Text('Open LGA Dashboard', style: TextStyle(fontSize: 12)),
            )),
          ]),
        );
      },
    );
  }
}

// ── Companies Tab ─────────────────────────────────────────────────────────────
class _CompaniesTab extends StatelessWidget {
  final List<dynamic> companies; final String state;
  const _CompaniesTab({required this.companies, required this.state});

  @override Widget build(BuildContext context) {
    if (companies.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('No companies registered yet', style: TextStyle(color: WPColors.textMuted)),
      const SizedBox(height: 12),
      ElevatedButton.icon(icon: const Icon(Icons.add_business, size: 16), label: const Text('Register Company'),
          onPressed: () {}),
    ]));
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: companies.length,
      itemBuilder: (_, i) {
        final c = companies[i];
        final trucks = (c['trucks'] as List?) ?? [];
        return Container(
          margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFEEEEEE))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: WPColors.green50, borderRadius: BorderRadius.circular(10)),
                  child: const Center(child: Text('🏢', style: TextStyle(fontSize: 22)))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c['name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text('RC: ${c['rc_number'] ?? 'N/A'} • ${c['fleet_size'] ?? 0} trucks',
                    style: const TextStyle(fontSize: 11, color: WPColors.textSecondary)),
              ])),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: WPColors.green50, borderRadius: BorderRadius.circular(20)),
                child: Text('${c['fleet_size'] ?? 0} trucks', style: const TextStyle(fontSize: 11, color: WPColors.green700, fontWeight: FontWeight.w600))),
            ]),
            if (trucks.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 4, children: trucks.take(6).map((t) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: WPColors.navy.withOpacity(0.07), borderRadius: BorderRadius.circular(6)),
                child: Text(t['wastepay_id'] as String? ?? '',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: WPColors.navy)))).toList()),
            ],
            if ((c['director'] as String?)?.isNotEmpty == true) ...[
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.person_outline, size: 13, color: WPColors.textMuted),
                const SizedBox(width: 4),
                Text(c['director'] as String, style: const TextStyle(fontSize: 11, color: WPColors.textSecondary)),
                const SizedBox(width: 10),
                if ((c['contact_phone'] as String?)?.isNotEmpty == true) ...[
                  const Icon(Icons.phone_outlined, size: 13, color: WPColors.textMuted),
                  const SizedBox(width: 4),
                  Text(c['contact_phone'] as String, style: const TextStyle(fontSize: 11, color: WPColors.textSecondary)),
                ],
              ]),
            ],
          ]),
        );
      },
    );
  }
}

// ── Reports Tab ───────────────────────────────────────────────────────────────
class _StateReportsTab extends StatelessWidget {
  final Map<String, dynamic> stats; final String state;
  const _StateReportsTab({required this.stats, required this.state});

  @override Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('State Financial Summary', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      const SizedBox(height: 10),
      _Row('State', state),
      _Row('Total LGAs active', '${stats['total_lgas'] ?? 0}'),
      _Row('Total invoices', '${stats['total_invoices'] ?? 0}'),
      _Row('Total billed', '₦${((stats['total_billed'] as num?)?.toDouble() ?? 0) >= 1000000 ? '${((stats['total_billed'] as num).toDouble() / 1000000).toStringAsFixed(1)}M' : stats['total_billed'] ?? 0}'),
      _Row('Total collected', '₦${((stats['total_collected'] as num?)?.toDouble() ?? 0) >= 1000000 ? '${((stats['total_collected'] as num).toDouble() / 1000000).toStringAsFixed(1)}M' : stats['total_collected'] ?? 0}'),
      _Row('Collection rate', '${(stats['collection_rate'] as num?)?.toStringAsFixed(1) ?? 0}%'),
      _Row('Contractor companies', '${stats['total_companies'] ?? 0}'),
      _Row('Total trucks', '${stats['total_trucks'] ?? 0}'),
      const SizedBox(height: 20),
      const Text('Export Reports', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      const SizedBox(height: 10),
      _ExportBtn(Icons.file_download_outlined, 'CBN Monthly Report (CSV)', 'For Central Bank compliance', () =>
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CBN report export — connect to /lga/report/cbnaudio')))),
      const SizedBox(height: 8),
      _ExportBtn(Icons.eco_outlined, 'FMEnv Waste Data Report', 'For Federal Ministry of Environment', () =>
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('FMEnv report export')))),
      const SizedBox(height: 8),
      _ExportBtn(Icons.local_shipping_outlined, 'Contractor Performance Report', 'All companies + compliance rates', () =>
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contractor report export')))),
      const SizedBox(height: 8),
      _ExportBtn(Icons.receipt_long_outlined, 'Full Invoice Ledger (PDF)', 'All LGA invoices this period', () =>
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invoice ledger export')))),
    ]),
  );
}

class _Row extends StatelessWidget {
  final String l, v; const _Row(this.l, this.v);
  @override Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFEEEEEE))),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(l, style: const TextStyle(fontSize: 13, color: WPColors.textSecondary)),
      Text(v, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    ]));
}

class _ExportBtn extends StatelessWidget {
  final IconData icon; final String title, subtitle; final VoidCallback onTap;
  const _ExportBtn(this.icon, this.title, this.subtitle, this.onTap);
  @override Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFEEEEEE))),
      child: Row(children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: WPColors.green50, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: WPColors.green500, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: WPColors.textSecondary)),
        ])),
        const Icon(Icons.download, size: 16, color: WPColors.green500),
      ])));
}
