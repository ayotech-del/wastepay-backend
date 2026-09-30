// WastePay Nigeria — LGA Government Dashboard
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/api_service.dart';

class LGADashboardScreen extends StatefulWidget {
  final String lgaId;
  final String lgaName;
  const LGADashboardScreen({super.key, required this.lgaId, required this.lgaName});
  @override State<LGADashboardScreen> createState() => _LGADashboardScreenState();
}

class _LGADashboardScreenState extends State<LGADashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  Map<String, dynamic> _billingStats = {};
  Map<String, dynamic> _contractorReport = {};
  List<dynamic> _invoices = [];
  List<dynamic> _contractors = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        BillingApi.getBillingStats(widget.lgaId),
        ContractorApi.getContractorReport(widget.lgaId),
        BillingApi.getInvoices(widget.lgaId),
        ContractorApi.getLiveContractors(widget.lgaId),
      ]);
      setState(() {
        _billingStats      = results[0] as Map<String, dynamic>;
        _contractorReport  = results[1] as Map<String, dynamic>;
        _invoices          = results[2] as List<dynamic>;
        _contractors       = (results[3] as Map<String, dynamic>)['contractors'] ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WPColors.navy,
      body: Column(children: [
        // Header
        SafeArea(
          bottom: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(children: [
              Row(children: [
                const BackButton(color: Colors.white),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Government Dashboard', style: TextStyle(color: WPColors.green200, fontSize: 12)),
                  Text(widget.lgaName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                ])),
                IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _load),
              ]),
              const SizedBox(height: 12),
              // KPI row
              if (!_loading && _billingStats.isNotEmpty)
                Row(children: [
                  _KPI('₦${_fmt(_billingStats['total_billed'])}', 'Billed'),
                  _KPI('₦${_fmt(_billingStats['total_collected'])}', 'Collected'),
                  _KPI('${_billingStats['collection_rate'] ?? 0}%', 'Rate'),
                  _KPI('${_billingStats['total_invoices'] ?? 0}', 'Invoices'),
                ]),
              const SizedBox(height: 12),
              // Tab bar
              Container(
                decoration: BoxDecoration(color: WPColors.green900, borderRadius: BorderRadius.circular(10)),
                child: TabBar(
                  controller: _tabs,
                  indicator: BoxDecoration(color: WPColors.green500, borderRadius: BorderRadius.circular(8)),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: WPColors.green200,
                  labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  tabs: const [Tab(text: 'Invoices'), Tab(text: 'Contractors'), Tab(text: 'Reports')],
                ),
              ),
            ]),
          ),
        ),

        // Body
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(top: 12),
            decoration: const BoxDecoration(
              color: WPColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: WPColors.green500))
                : TabBarView(controller: _tabs, children: [
                    _InvoicesTab(invoices: _invoices, lgaId: widget.lgaId, onRefresh: _load),
                    _ContractorsTab(contractors: _contractors, report: _contractorReport),
                    _ReportsTab(billingStats: _billingStats, contractorReport: _contractorReport, lgaName: widget.lgaName),
                  ]),
          ),
        ),
      ]),
    );
  }

  String _fmt(dynamic val) {
    if (val == null) return '0';
    final n = (val as num).toDouble();
    if (n >= 1000000) return '${(n/1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n/1000).toStringAsFixed(0)}K';
    return n.toStringAsFixed(0);
  }
}

class _KPI extends StatelessWidget {
  final String val, lbl;
  const _KPI(this.val, this.lbl);
  @override Widget build(BuildContext context) => Expanded(child: Container(
    margin: const EdgeInsets.symmetric(horizontal: 3),
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(color: WPColors.green700.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(8)),
    child: Column(children: [
      Text(val, style: const TextStyle(color: WPColors.goldLight, fontWeight: FontWeight.w700, fontSize: 14)),
      Text(lbl, style: const TextStyle(color: WPColors.green200, fontSize: 10)),
    ]),
  ));
}

// ── INVOICES TAB ─────────────────────────────────────────────────────────────
class _InvoicesTab extends StatelessWidget {
  final List<dynamic> invoices;
  final String lgaId;
  final VoidCallback onRefresh;
  const _InvoicesTab({required this.invoices, required this.lgaId, required this.onRefresh});

  Color _statusColor(String s) {
    switch (s) {
      case 'paid':     return WPColors.green500;
      case 'overdue':  return WPColors.terracotta;
      case 'partial':  return WPColors.gold;
      default:         return Colors.blue;
    }
  }

  @override Widget build(BuildContext context) {
    if (invoices.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('No invoices yet', style: TextStyle(color: WPColors.textMuted, fontSize: 15)),
      const SizedBox(height: 16),
      ElevatedButton.icon(
        icon: const Icon(Icons.add, size: 16),
        label: const Text('Generate Invoice'),
        onPressed: () => _showGenerateDialog(context),
      ),
    ]));
    }

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${invoices.length} invoices', style: const TextStyle(fontSize: 13, color: WPColors.textSecondary)),
          ElevatedButton.icon(
            icon: const Icon(Icons.add, size: 14),
            label: const Text('Generate', style: TextStyle(fontSize: 12)),
            onPressed: () => _showGenerateDialog(context),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
          ),
        ]),
      ),
      Expanded(child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: invoices.length,
        itemBuilder: (_, i) {
          final inv = invoices[i];
          final status = inv['status'] as String;
          final color = _statusColor(status);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFEEEEEE)),
            ),
            child: Row(children: [
              Container(width: 3, height: 48, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(inv['invoice_number'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(inv['zone'] ?? inv['description'] ?? '', style: const TextStyle(color: WPColors.textSecondary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(inv['billing_period'] ?? '', style: const TextStyle(color: WPColors.textMuted, fontSize: 11)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('₦${(inv['amount'] as num).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: Text(status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
                ),
              ]),
            ]),
          );
        },
      )),
    ]);
  }

  void _showGenerateDialog(BuildContext ctx) {
    final amountCtrl = TextEditingController(text: '3500');
    final zoneCtrl   = TextEditingController(text: 'Zone A');
    final countCtrl  = TextEditingController(text: '10');
    showDialog(context: ctx, builder: (_) => AlertDialog(
      title: const Text('Generate Invoices', style: TextStyle(fontSize: 16)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: zoneCtrl, decoration: const InputDecoration(labelText: 'Zone name', isDense: true)),
        const SizedBox(height: 10),
        TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount per household (₦)', isDense: true)),
        const SizedBox(height: 10),
        TextField(controller: countCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Number of households', isDense: true)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(ctx);
            await BillingApi.generateBulkInvoices(
              lgaId: lgaId, zone: zoneCtrl.text,
              amount: double.tryParse(amountCtrl.text) ?? 3500,
              householdCount: int.tryParse(countCtrl.text) ?? 10,
              billingPeriod: '2026-06',
            );
            onRefresh();
          },
          child: const Text('Generate'),
        ),
      ],
    ));
  }
}

// ── CONTRACTORS TAB ───────────────────────────────────────────────────────────
class _ContractorsTab extends StatelessWidget {
  final List<dynamic> contractors;
  final Map<String, dynamic> report;
  const _ContractorsTab({required this.contractors, required this.report});

  @override Widget build(BuildContext context) {
    if (contractors.isEmpty) return const Center(child: Text('No active contractors', style: TextStyle(color: WPColors.textMuted)));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: contractors.length,
      itemBuilder: (_, i) {
        final c = contractors[i];
        final status = c['status'] as String;
        final statusColor = status == 'on_route' ? WPColors.green500
            : status == 'break' ? WPColors.gold : Colors.grey;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEEEEEE)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 40, height: 40, decoration: const BoxDecoration(color: WPColors.green50, shape: BoxShape.circle),
                child: const Center(child: Text('🚛', style: TextStyle(fontSize: 20))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(c['truck_number'] ?? '', style: const TextStyle(color: WPColors.textSecondary, fontSize: 12)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text(status.replaceAll('_', ' ').toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor)),
                ]),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              _CTile('${c['today_kg'] ?? 0}kg', 'collected today'),
              _CTile('${c['bins_remaining'] ?? 0}', 'bins remaining'),
              _CTile(c['position'] != null ? '📍 Live' : '📍 N/A', 'GPS'),
            ]),
          ]),
        );
      },
    );
  }
}

class _CTile extends StatelessWidget {
  final String val, lbl;
  const _CTile(this.val, this.lbl);
  @override Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(val, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: WPColors.green900)),
    Text(lbl, style: const TextStyle(fontSize: 10, color: WPColors.textMuted)),
  ]));
}

// ── REPORTS TAB ───────────────────────────────────────────────────────────────
class _ReportsTab extends StatelessWidget {
  final Map<String, dynamic> billingStats;
  final Map<String, dynamic> contractorReport;
  final String lgaName;
  const _ReportsTab({required this.billingStats, required this.contractorReport, required this.lgaName});

  @override Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Billing Summary', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        _ReportCard('Total invoiced', '₦${billingStats['total_billed'] ?? 0}'),
        _ReportCard('Total collected', '₦${billingStats['total_collected'] ?? 0}'),
        _ReportCard('Outstanding', '₦${billingStats['outstanding'] ?? 0}'),
        _ReportCard('Collection rate', '${billingStats['collection_rate'] ?? 0}%'),
        _ReportCard('Paid invoices', '${billingStats['paid_count'] ?? 0}'),
        _ReportCard('Overdue invoices', '${billingStats['overdue_count'] ?? 0}'),
        const SizedBox(height: 16),
        const Text('Contractor Summary', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        _ReportCard('Total contractors', '${contractorReport['total_contractors'] ?? 0}'),
        _ReportCard('Total waste collected', '${contractorReport['total_kg_collected'] ?? 0}kg'),
        _ReportCard('Total paid to contractors', '₦${contractorReport['total_paid_ngn'] ?? 0}'),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          icon: const Icon(Icons.download, size: 16),
          label: const Text('Export CBN Report (CSV)'),
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('CBN report export — connect to backend /lga/report/cbnaudio')),
          ),
          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          icon: const Icon(Icons.share, size: 16),
          label: const Text('Share FMEnv Report'),
          onPressed: () {},
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
        ),
      ]),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String label, value;
  const _ReportCard(this.label, this.value);
  @override Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFEEEEEE))),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(fontSize: 13, color: WPColors.textSecondary)),
      Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: WPColors.textPrimary)),
    ]),
  );
}
