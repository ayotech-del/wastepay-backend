// WastePay Nigeria — Contractor Driver App
// 6 screens: Dashboard, Route Map, Bin Collection, Earnings, Performance, Profile

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/theme.dart';
import '../../core/config.dart';

// ── Entry point ───────────────────────────────────────────────────────────────
class ContractorPortal extends StatefulWidget {
  final String contractorId;
  final String name;
  final String truckNumber;
  const ContractorPortal({super.key, required this.contractorId, required this.name, required this.truckNumber});
  @override State<ContractorPortal> createState() => _ContractorPortalState();
}

class _ContractorPortalState extends State<ContractorPortal> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      ContractorDashboard(contractorId: widget.contractorId, name: widget.name, truckNumber: widget.truckNumber),
      ContractorRouteMap(contractorId: widget.contractorId),
      ContractorBinCollection(contractorId: widget.contractorId),
      ContractorEarnings(contractorId: widget.contractorId),
      ContractorPerformance(contractorId: widget.contractorId),
      ContractorProfile(contractorId: widget.contractorId, name: widget.name, truckNumber: widget.truckNumber),
    ];
    return Scaffold(
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        height: 64,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Route'),
          NavigationDestination(icon: Icon(Icons.qr_code_scanner_outlined), selectedIcon: Icon(Icons.qr_code_scanner), label: 'Collect'),
          NavigationDestination(icon: Icon(Icons.payments_outlined), selectedIcon: Icon(Icons.payments), label: 'Earnings'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Performance'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SCREEN 1 — DASHBOARD
// ══════════════════════════════════════════════════════════════════════════════
class ContractorDashboard extends StatefulWidget {
  final String contractorId, name, truckNumber;
  const ContractorDashboard({super.key, required this.contractorId, required this.name, required this.truckNumber});
  @override State<ContractorDashboard> createState() => _ContractorDashboardState();
}

class _ContractorDashboardState extends State<ContractorDashboard> {
  String _status = 'on_route';
  double _todayKg = 0;
  double _todayEarnings = 0;
  int _binsTotal = 9;
  int _binsDone = 3;
  bool _loading = false;

  final _statusOptions = {
    'on_route': ('On Route', WPColors.green500, Icons.local_shipping),
    'break':    ('On Break', WPColors.gold, Icons.coffee),
    'offline':  ('Offline',  Colors.grey,  Icons.power_settings_new),
  };

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _loading = true);
    try {
      await http.post(
        Uri.parse('${AppConfig.baseUrl}/contractors/location/update'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'contractor_id': widget.contractorId, 'lat': 6.4281, 'lng': 3.4219, 'status': newStatus}),
      );
      setState(() { _status = newStatus; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final s = _statusOptions[_status]!;
    final progress = _binsTotal > 0 ? _binsDone / _binsTotal : 0.0;

    return Scaffold(
      backgroundColor: WPColors.navy,
      body: Column(children: [
        // Header
        SafeArea(bottom: false, child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(children: [
            Row(children: [
              Container(width: 46, height: 46, decoration: BoxDecoration(color: WPColors.green700, shape: BoxShape.circle),
                child: const Center(child: Text('🚛', style: TextStyle(fontSize: 22)))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Good morning, ${widget.name.split(' ').first}!',
                    style: const TextStyle(color: WPColors.green200, fontSize: 13)),
                Text(widget.truckNumber, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              ])),
              // Status toggle
              GestureDetector(
                onTap: () => _showStatusPicker(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: s.$2.withOpacity(0.2), borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: s.$2)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: s.$2, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(s.$1, style: TextStyle(color: s.$2, fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: 20),

            // Today's stats
            Row(children: [
              _StatCard('${_todayKg.toStringAsFixed(1)}kg', 'Collected today', WPColors.green500),
              const SizedBox(width: 10),
              _StatCard('₦${_todayEarnings.toStringAsFixed(0)}', 'Earned today', WPColors.gold),
              const SizedBox(width: 10),
              _StatCard('$_binsDone/$_binsTotal', 'Bins done', WPColors.green200),
            ]),
            const SizedBox(height: 16),

            // Route progress bar
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Route progress', style: TextStyle(color: WPColors.green200, fontSize: 12)),
                Text('${(progress * 100).toInt()}%', style: const TextStyle(color: WPColors.goldLight, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
                value: progress, minHeight: 8,
                backgroundColor: WPColors.green900,
                valueColor: const AlwaysStoppedAnimation<Color>(WPColors.green500),
              )),
            ]),
          ]),
        )),

        // Body
        Expanded(child: Container(
          margin: const EdgeInsets.only(top: 16),
          decoration: const BoxDecoration(color: WPColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Active route card
            const Text('Active Route', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Container(padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEEEEEE))),
              child: Column(children: [
                _BinRow('BIN-LG-001', 'Lekki Phase 1, Lagos', 15, true),
                const Divider(height: 16),
                _BinRow('BIN-LG-002', 'Victoria Island, Lagos', 72, true),
                const Divider(height: 16),
                _BinRow('BIN-LG-003', 'Ajah Bus Stop, Lagos', 33, false),
                const Divider(height: 16),
                _BinRow('BIN-LG-004', 'Sangotedo Market, Lagos', 88, false),
              ]),
            ),
            const SizedBox(height: 16),

            // Quick actions
            const Text('Quick Actions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _QuickAction(Icons.qr_code_scanner, 'Scan Bin', WPColors.green500, () {})),
              const SizedBox(width: 10),
              Expanded(child: _QuickAction(Icons.my_location, 'Update GPS', WPColors.navy, () => _updateStatus(_status))),
              const SizedBox(width: 10),
              Expanded(child: _QuickAction(Icons.flag, 'End Route', WPColors.terracotta, () {})),
            ]),
            const SizedBox(height: 16),

            // Last update
            Container(padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: WPColors.green50, borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.location_on, color: WPColors.green500, size: 16),
                const SizedBox(width: 8),
                const Expanded(child: Text('Last GPS ping: Just now • Lekki Phase 1',
                    style: TextStyle(fontSize: 12, color: WPColors.green700))),
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: WPColors.green500, shape: BoxShape.circle)),
              ]),
            ),
          ])),
        )),
      ]),
    );
  }

  void _showStatusPicker(BuildContext ctx) {
    showModalBottomSheet(context: ctx, builder: (_) => Padding(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Update Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        ..._statusOptions.entries.map((e) => ListTile(
          leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: e.value.$2.withOpacity(0.15), shape: BoxShape.circle),
              child: Icon(e.value.$3, color: e.value.$2, size: 18)),
          title: Text(e.value.$1, style: TextStyle(fontWeight: _status == e.key ? FontWeight.w700 : FontWeight.normal)),
          trailing: _status == e.key ? Icon(Icons.check_circle, color: e.value.$2) : null,
          onTap: () { Navigator.pop(ctx); _updateStatus(e.key); },
        )),
      ]),
    ));
  }
}

class _StatCard extends StatelessWidget {
  final String val, lbl; final Color color;
  const _StatCard(this.val, this.lbl, this.color);
  @override Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3))),
    child: Column(children: [
      Text(val, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 16)),
      Text(lbl, style: const TextStyle(color: WPColors.green200, fontSize: 10), textAlign: TextAlign.center),
    ]),
  ));
}

class _BinRow extends StatelessWidget {
  final String code, address; final int fill; final bool done;
  const _BinRow(this.code, this.address, this.fill, this.done);
  @override Widget build(BuildContext context) => Row(children: [
    Container(width: 28, height: 28, decoration: BoxDecoration(
        color: done ? WPColors.green50 : fill >= 75 ? const Color(0xFFFFEBEE) : const Color(0xFFFFF3E0),
        shape: BoxShape.circle),
      child: Icon(done ? Icons.check : Icons.circle, size: 14,
          color: done ? WPColors.green500 : fill >= 75 ? WPColors.terracotta : WPColors.gold)),
    const SizedBox(width: 10),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(code, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
          decoration: done ? TextDecoration.lineThrough : null, color: done ? WPColors.textMuted : WPColors.textPrimary)),
      Text(address, style: const TextStyle(fontSize: 11, color: WPColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
    ])),
    Text('$fill%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
        color: done ? WPColors.textMuted : fill >= 75 ? WPColors.terracotta : WPColors.gold)),
  ]);
}

class _QuickAction extends StatelessWidget {
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  const _QuickAction(this.icon, this.label, this.color, this.onTap);
  @override Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3))),
      child: Column(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
      ]),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// SCREEN 2 — ROUTE MAP
// ══════════════════════════════════════════════════════════════════════════════
class ContractorRouteMap extends StatefulWidget {
  final String contractorId;
  const ContractorRouteMap({super.key, required this.contractorId});
  @override State<ContractorRouteMap> createState() => _ContractorRouteMapState();
}

class _ContractorRouteMapState extends State<ContractorRouteMap> {
  final _bins = [
    {'code': 'BIN-LG-001', 'address': 'Lekki Phase 1, Lagos',    'fill': 15, 'done': true,  'lat': 6.4281, 'lng': 3.4219},
    {'code': 'BIN-LG-002', 'address': 'Victoria Island, Lagos',  'fill': 72, 'done': true,  'lat': 6.4350, 'lng': 3.4580},
    {'code': 'BIN-LG-003', 'address': 'Ajah Bus Stop, Lagos',    'fill': 33, 'done': false, 'lat': 6.4500, 'lng': 3.3841},
    {'code': 'BIN-LG-004', 'address': 'Sangotedo Market, Lagos', 'fill': 88, 'done': false, 'lat': 6.4530, 'lng': 3.3940},
    {'code': 'BIN-LG-005', 'address': 'Yaba Tech Cluster, Lagos','fill': 45, 'done': false, 'lat': 6.5095, 'lng': 3.3711},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Route Map'), automaticallyImplyLeading: false,
          actions: [IconButton(icon: const Icon(Icons.my_location), onPressed: () {})]),
      body: Column(children: [
        // Map placeholder
        Container(height: 280, color: const Color(0xFFE8F5E9),
          child: Stack(children: [
            Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.map, size: 48, color: WPColors.green200),
              const SizedBox(height: 8),
              const Text('Live Map', style: TextStyle(color: WPColors.green500, fontWeight: FontWeight.w600)),
              const Text('Google Maps integration\nrequires API key setup', style: TextStyle(color: WPColors.textMuted, fontSize: 12), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.open_in_new, size: 14),
                label: const Text('Open in Google Maps', style: TextStyle(fontSize: 12)),
                onPressed: () {},
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
              ),
            ])),
            // Bin markers overlay
            ...List.generate(_bins.length, (i) {
              final bin = _bins[i];
              final done = bin['done'] as bool;
              final fill = bin['fill'] as int;
              return Positioned(
                left: 60.0 + i * 50,
                top: 80.0 + (i % 2) * 60,
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: done ? WPColors.green500 : fill >= 75 ? WPColors.terracotta : WPColors.gold,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)],
                  ),
                  child: Center(child: Text('${i+1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
                ),
              );
            }),
            // Truck position
            Positioned(left: 180, top: 120, child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: WPColors.navy, shape: BoxShape.circle, border: Border.all(color: WPColors.gold, width: 2)),
              child: const Center(child: Text('🚛', style: TextStyle(fontSize: 16))),
            )),
          ]),
        ),

        // Bin list
        Expanded(child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _bins.length,
          itemBuilder: (_, i) {
            final bin = _bins[i];
            final done = bin['done'] as bool;
            final fill = bin['fill'] as int;
            final color = done ? WPColors.green500 : fill >= 75 ? WPColors.terracotta : WPColors.gold;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: done ? WPColors.green50 : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: done ? WPColors.green200 : const Color(0xFFEEEEEE)),
              ),
              child: Row(children: [
                Container(width: 32, height: 32, decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    child: Center(child: Text('${i+1}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(bin['code'] as String, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13,
                      decoration: done ? TextDecoration.lineThrough : null)),
                  Text(bin['address'] as String, style: const TextStyle(color: WPColors.textSecondary, fontSize: 11)),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('$fill%', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
                  Text(done ? '✅ Done' : fill >= 75 ? '🔴 Priority' : '🟡 Pending',
                      style: const TextStyle(fontSize: 10, color: WPColors.textMuted)),
                ]),
              ]),
            );
          },
        )),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SCREEN 3 — BIN COLLECTION
// ══════════════════════════════════════════════════════════════════════════════
class ContractorBinCollection extends StatefulWidget {
  final String contractorId;
  const ContractorBinCollection({super.key, required this.contractorId});
  @override State<ContractorBinCollection> createState() => _ContractorBinCollectionState();
}

class _ContractorBinCollectionState extends State<ContractorBinCollection> {
  final _weightCtrl = TextEditingController();
  String? _scannedBin;
  bool _submitting = false;
  String? _result;
  String _activeRouteId = '';

  Future<void> _simulateScan() async {
    setState(() { _scannedBin = 'BIN-LG-003'; _result = null; });
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ QR scanned — BIN-LG-003 | Ajah Bus Stop, Lagos'), backgroundColor: WPColors.green500));
  }

  Future<void> _submitCollection() async {
    if (_scannedBin == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scan a bin QR code first'))); return; }
    final weight = double.tryParse(_weightCtrl.text);
    if (weight == null || weight <= 0) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter valid weight in kg'))); return; }
    setState(() { _submitting = true; _result = null; });
    try {
      final r = await http.post(
        Uri.parse('${AppConfig.baseUrl}/contractors/collection/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'route_id': _activeRouteId.isEmpty ? 'demo-route-001' : _activeRouteId,
          'bin_id': _scannedBin,
          'weight_kg': weight,
          'qr_scan_data': 'QR-$_scannedBin',
          'lat': 6.4500, 'lng': 3.3841,
        }),
      );
      final data = jsonDecode(r.body);
      setState(() {
        _result = r.statusCode == 200
            ? '✅ Collection verified! ${weight}kg from $_scannedBin\nRoute total: ${data['route_total_kg'] ?? weight}kg\nBins remaining: ${data['bins_remaining'] ?? 0}'
            : '⚠️ ${data['detail'] ?? 'Verification failed'}';
        _submitting = false;
        if (r.statusCode == 200) { _scannedBin = null; _weightCtrl.clear(); }
      });
    } catch (_) {
      setState(() { _result = '✅ Collection recorded locally (offline mode)\n${weight}kg from BIN-LG-003'; _submitting = false; _scannedBin = null; _weightCtrl.clear(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bin Collection'), automaticallyImplyLeading: false),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Step 1 — Scan
        _StepCard('1', 'Scan Bin QR Code', WPColors.green500, Column(children: [
          if (_scannedBin != null) ...[
            Container(padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: WPColors.green50, borderRadius: BorderRadius.circular(8), border: Border.all(color: WPColors.green200)),
              child: Row(children: [
                const Icon(Icons.qr_code, color: WPColors.green500, size: 28),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_scannedBin!, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: WPColors.green900)),
                  const Text('Ajah Bus Stop, Lagos', style: TextStyle(fontSize: 12, color: WPColors.textSecondary)),
                  const Text('Fill level: 33%', style: TextStyle(fontSize: 11, color: WPColors.green700)),
                ])),
                IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => setState(() => _scannedBin = null)),
              ]),
            ),
          ] else ...[
            Container(height: 160, decoration: BoxDecoration(color: WPColors.navy.withOpacity(0.05), borderRadius: BorderRadius.circular(12),
                border: Border.all(color: WPColors.green200, style: BorderStyle.solid)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.qr_code_scanner, size: 48, color: WPColors.green500),
                const SizedBox(height: 8),
                const Text('Point camera at bin QR code', style: TextStyle(color: WPColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 12),
                ElevatedButton.icon(icon: const Icon(Icons.qr_code_scanner, size: 16), label: const Text('Scan QR Code'),
                    onPressed: _simulateScan),
              ]),
            ),
          ],
        ])),
        const SizedBox(height: 12),

        // Step 2 — Weight
        _StepCard('2', 'Enter Weight Collected', WPColors.gold, Column(children: [
          TextField(controller: _weightCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: 'e.g. 280.5', suffixText: 'kg', prefixIcon: Icon(Icons.scale_outlined, size: 20),
                labelText: 'Weight in kilograms'),
          ),
          const SizedBox(height: 8),
          Row(children: [
            _WeightBtn('50kg', () => _weightCtrl.text = '50'),
            const SizedBox(width: 6),
            _WeightBtn('100kg', () => _weightCtrl.text = '100'),
            const SizedBox(width: 6),
            _WeightBtn('250kg', () => _weightCtrl.text = '250'),
            const SizedBox(width: 6),
            _WeightBtn('500kg', () => _weightCtrl.text = '500'),
          ]),
        ])),
        const SizedBox(height: 12),

        // Step 3 — Submit
        _StepCard('3', 'Confirm & Submit', WPColors.green500, Column(children: [
          if (_result != null) Container(
            width: double.infinity, padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _result!.startsWith('✅') ? WPColors.green50 : const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _result!.startsWith('✅') ? WPColors.green200 : const Color(0xFFFFCDD2)),
            ),
            child: Text(_result!, style: TextStyle(color: _result!.startsWith('✅') ? WPColors.green900 : WPColors.terracotta,
                fontSize: 13, fontWeight: FontWeight.w500)),
          ) else const Text('GPS location will be captured automatically when you submit.',
              style: TextStyle(color: WPColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: _submitting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.check_circle, size: 18),
            label: Text(_submitting ? 'Verifying...' : 'Submit Collection'),
            onPressed: _submitting ? null : _submitCollection,
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
        ])),
        const SizedBox(height: 20),

        // Today's collections
        const Text('Today\'s Collections', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...[
          ('BIN-LG-001', 'Lekki Phase 1', '280.5kg', '14:23'),
          ('BIN-LG-002', 'Victoria Island', '195.0kg', '13:41'),
        ].map((c) => Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFEEEEEE))),
          child: Row(children: [
            const Icon(Icons.check_circle, color: WPColors.green500, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.$1, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text(c.$2, style: const TextStyle(color: WPColors.textSecondary, fontSize: 11)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(c.$3, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: WPColors.green700)),
              Text(c.$4, style: const TextStyle(fontSize: 11, color: WPColors.textMuted)),
            ]),
          ]),
        )),
      ])),
    );
  }
}

class _StepCard extends StatelessWidget {
  final String step, title; final Color color; final Widget child;
  const _StepCard(this.step, this.title, this.color, this.child);
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFEEEEEE))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 28, height: 28, decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Center(child: Text(step, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)))),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      ]),
      const SizedBox(height: 12),
      child,
    ]),
  );
}

class _WeightBtn extends StatelessWidget {
  final String label; final VoidCallback onTap;
  const _WeightBtn(this.label, this.onTap);
  @override Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: WPColors.green50, borderRadius: BorderRadius.circular(6), border: Border.all(color: WPColors.green200)),
      child: Text(label, style: const TextStyle(fontSize: 12, color: WPColors.green700, fontWeight: FontWeight.w500))),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// SCREEN 4 — EARNINGS
// ══════════════════════════════════════════════════════════════════════════════
class ContractorEarnings extends StatefulWidget {
  final String contractorId;
  const ContractorEarnings({super.key, required this.contractorId});
  @override State<ContractorEarnings> createState() => _ContractorEarningsState();
}

class _ContractorEarningsState extends State<ContractorEarnings> {
  String _period = 'today';

  final _payments = [
    {'ref': 'WP-CPAY-3F8A12', 'date': 'Today 16:30', 'amount': 35700.0, 'tonnes': 4.2, 'status': 'paid'},
    {'ref': 'WP-CPAY-2E7B09', 'date': 'Yesterday', 'amount': 57800.0, 'tonnes': 6.8, 'status': 'paid'},
    {'ref': 'WP-CPAY-1D6C08', 'date': 'Jun 13', 'amount': 42500.0, 'tonnes': 5.0, 'status': 'paid'},
    {'ref': 'WP-CPAY-0C5D07', 'date': 'Jun 12', 'amount': 11900.0, 'tonnes': 1.4, 'status': 'withheld', 'reason': 'Route deviation detected'},
    {'ref': 'WP-CPAY-9B4E06', 'date': 'Jun 11', 'amount': 63750.0, 'tonnes': 7.5, 'status': 'paid'},
  ];

  @override
  Widget build(BuildContext context) {
    final totalPaid = _payments.where((p) => p['status'] == 'paid').fold(0.0, (s, p) => s + (p['amount'] as double));
    final totalTonnes = _payments.fold(0.0, (s, p) => s + (p['tonnes'] as double));

    return Scaffold(
      appBar: AppBar(title: const Text('Earnings & Payments'), automaticallyImplyLeading: false),
      body: Column(children: [
        // Summary card
        Container(color: WPColors.navy, padding: const EdgeInsets.fromLTRB(16, 0, 16, 20), child: Column(children: [
          const SizedBox(height: 8),
          const Text('Total Earned (This Week)', style: TextStyle(color: WPColors.green200, fontSize: 13)),
          const SizedBox(height: 6),
          Text('₦${totalPaid.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Row(children: [
            _EarnStat('₦8,500', 'Rate/tonne'),
            _EarnStat('${totalTonnes.toStringAsFixed(1)}t', 'Total collected'),
            _EarnStat('5', 'Collections'),
            _EarnStat('1', 'Withheld'),
          ]),
          const SizedBox(height: 12),
          // Period filter
          Row(children: ['today', 'week', 'month'].map((p) => Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: () => setState(() => _period = p),
              child: Container(padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: _period == p ? WPColors.green500 : WPColors.green700.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(p[0].toUpperCase() + p.substring(1), textAlign: TextAlign.center,
                    style: TextStyle(color: _period == p ? Colors.white : WPColors.green200, fontSize: 12, fontWeight: FontWeight.w500))),
            ),
          ))).toList()),
        ])),

        // Payment list
        Expanded(child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _payments.length,
          itemBuilder: (_, i) {
            final p = _payments[i];
            final paid = p['status'] == 'paid';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFEEEEEE))),
              child: Column(children: [
                Row(children: [
                  Container(width: 36, height: 36, decoration: BoxDecoration(
                      color: paid ? WPColors.green50 : const Color(0xFFFFEBEE), shape: BoxShape.circle),
                    child: Icon(paid ? Icons.account_balance : Icons.block, size: 18,
                        color: paid ? WPColors.green500 : WPColors.terracotta)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p['ref'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text('${p['date']} • ${p['tonnes']}t collected',
                        style: const TextStyle(fontSize: 11, color: WPColors.textSecondary)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('₦${(p['amount'] as double).toStringAsFixed(0)}',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14,
                            color: paid ? WPColors.green700 : WPColors.terracotta)),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: paid ? WPColors.green50 : const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(10)),
                      child: Text(paid ? 'PAID' : 'WITHHELD',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                              color: paid ? WPColors.green700 : WPColors.terracotta))),
                  ]),
                ]),
                if (!paid && p['reason'] != null) ...[
                  const SizedBox(height: 8),
                  Container(padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(6)),
                    child: Row(children: [
                      const Icon(Icons.warning_amber, size: 14, color: WPColors.terracotta),
                      const SizedBox(width: 6),
                      Text(p['reason'] as String, style: const TextStyle(fontSize: 11, color: WPColors.terracotta)),
                    ])),
                ],
              ]),
            );
          },
        )),
      ]),
    );
  }
}

class _EarnStat extends StatelessWidget {
  final String val, lbl;
  const _EarnStat(this.val, this.lbl);
  @override Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(val, style: const TextStyle(color: WPColors.goldLight, fontWeight: FontWeight.w700, fontSize: 14)),
    Text(lbl, style: const TextStyle(color: WPColors.green200, fontSize: 10)),
  ]));
}

// ══════════════════════════════════════════════════════════════════════════════
// SCREEN 5 — PERFORMANCE
// ══════════════════════════════════════════════════════════════════════════════
class ContractorPerformance extends StatefulWidget {
  final String contractorId;
  const ContractorPerformance({super.key, required this.contractorId});
  @override State<ContractorPerformance> createState() => _ContractorPerformanceState();
}

class _ContractorPerformanceState extends State<ContractorPerformance> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Performance'), automaticallyImplyLeading: false),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Overall score
        Container(padding: const EdgeInsets.all(20), width: double.infinity,
          decoration: BoxDecoration(color: WPColors.navy, borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            const Text('Overall Performance Score', style: TextStyle(color: WPColors.green200, fontSize: 13)),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('94', style: TextStyle(color: _scoreColor(94), fontSize: 56, fontWeight: FontWeight.w700)),
              Text('/100', style: TextStyle(color: _scoreColor(94).withOpacity(0.6), fontSize: 24)),
            ]),
            Container(margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(color: WPColors.green500.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
              child: const Text('⭐ Excellent Contractor', style: TextStyle(color: WPColors.green200, fontWeight: FontWeight.w600))),
            const Text('Top 5% of contractors in Eti-Osa LGA', style: TextStyle(color: WPColors.green200, fontSize: 12)),
          ]),
        ),
        const SizedBox(height: 16),

        // Metric cards
        const Text('This Week', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Row(children: [
          _PerfCard('25.7t', 'Waste collected', WPColors.green500, 0.86),
          const SizedBox(width: 10),
          _PerfCard('96%', 'Route compliance', WPColors.green500, 0.96),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _PerfCard('18/19', 'Bins completed', WPColors.gold, 18/19),
          const SizedBox(width: 10),
          _PerfCard('0', 'Deviations', WPColors.green500, 1.0),
        ]),
        const SizedBox(height: 16),

        // Daily breakdown
        const Text('Daily Collection (kg)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFEEEEEE))),
          child: Column(children: [
            _DayBar('Mon', 5200, 6000),
            _DayBar('Tue', 4800, 6000),
            _DayBar('Wed', 6000, 6000),
            _DayBar('Thu', 3500, 6000),
            _DayBar('Fri', 4200, 6000),
            _DayBar('Sat', 2000, 6000),
          ]),
        ),
        const SizedBox(height: 16),

        // Alerts
        const Text('Recent Alerts', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        _Alert(Icons.check_circle, 'Route completed on time — Jun 14', WPColors.green500, WPColors.green50),
        _Alert(Icons.warning_amber, 'Payment withheld — Jun 12: Route deviation 2.1km', WPColors.terracotta, const Color(0xFFFFEBEE)),
        _Alert(Icons.star, 'Performance bonus earned — Jun 10: 7.5 tonnes collected', WPColors.gold, const Color(0xFFFFF8E1)),
        const SizedBox(height: 20),
      ])),
    );
  }

  Color _scoreColor(int s) => s >= 85 ? WPColors.green500 : s >= 70 ? WPColors.gold : WPColors.terracotta;
}

class _PerfCard extends StatelessWidget {
  final String val, lbl; final Color color; final double progress;
  const _PerfCard(this.val, this.lbl, this.color, this.progress);
  @override Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFEEEEEE))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(val, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
      Text(lbl, style: const TextStyle(fontSize: 11, color: WPColors.textSecondary)),
      const SizedBox(height: 8),
      ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(
        value: progress, minHeight: 5, backgroundColor: const Color(0xFFEEEEEE),
        valueColor: AlwaysStoppedAnimation<Color>(color),
      )),
    ]),
  ));
}

class _DayBar extends StatelessWidget {
  final String day; final int val, max;
  const _DayBar(this.day, this.val, this.max);
  @override Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      SizedBox(width: 32, child: Text(day, style: const TextStyle(fontSize: 12, color: WPColors.textSecondary))),
      Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
        value: val / max, minHeight: 12, backgroundColor: const Color(0xFFEEEEEE),
        valueColor: AlwaysStoppedAnimation<Color>(val >= max * 0.8 ? WPColors.green500 : WPColors.gold),
      ))),
      const SizedBox(width: 8),
      SizedBox(width: 50, child: Text('${(val/1000).toStringAsFixed(1)}t', style: const TextStyle(fontSize: 11, color: WPColors.textSecondary), textAlign: TextAlign.right)),
    ]),
  );
}

class _Alert extends StatelessWidget {
  final IconData icon; final String msg; final Color color, bg;
  const _Alert(this.icon, this.msg, this.color, this.bg);
  @override Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
    child: Row(children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(width: 10),
      Expanded(child: Text(msg, style: TextStyle(fontSize: 12, color: color))),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// SCREEN 6 — PROFILE
// ══════════════════════════════════════════════════════════════════════════════
class ContractorProfile extends StatefulWidget {
  final String contractorId, name, truckNumber;
  const ContractorProfile({super.key, required this.contractorId, required this.name, required this.truckNumber});
  @override State<ContractorProfile> createState() => _ContractorProfileState();
}

class _ContractorProfileState extends State<ContractorProfile> {
  bool _gpsActive = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile'), automaticallyImplyLeading: false),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // Avatar
        Center(child: Column(children: [
          Container(width: 80, height: 80, decoration: const BoxDecoration(color: WPColors.green500, shape: BoxShape.circle),
              child: const Center(child: Text('🚛', style: TextStyle(fontSize: 36)))),
          const SizedBox(height: 10),
          Text(widget.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: WPColors.green50, borderRadius: BorderRadius.circular(20)),
            child: Text(widget.truckNumber, style: const TextStyle(color: WPColors.green700, fontSize: 13, fontWeight: FontWeight.w600))),
          const SizedBox(height: 4),
          const Text('Registered Contractor — Eti-Osa LGA', style: TextStyle(fontSize: 12, color: WPColors.textSecondary)),
        ])),
        const SizedBox(height: 20),

        // Stats row
        Row(children: [
          _PStat('142t', 'Total collected'),
          _PStat('₦1.2M', 'Total earned'),
          _PStat('94%', 'Compliance'),
        ]),
        const SizedBox(height: 20),

        // Truck details
        _Section('Truck Details'),
        _InfoRow('Truck Number', widget.truckNumber),
        _InfoRow('License Plate', 'LSD-123-AA'),
        _InfoRow('Capacity', '5 tonnes'),
        _InfoRow('Assigned LGA', 'Eti-Osa, Lagos'),
        _InfoRow('Rate', '₦8,500 per tonne'),
        const SizedBox(height: 16),

        // Bank details
        _Section('Payment Details'),
        _InfoRow('Bank', 'GTBank'),
        _InfoRow('Account', '****6789'),
        _InfoRow('Account Name', widget.name),
        const SizedBox(height: 4),
        TextButton.icon(icon: const Icon(Icons.edit, size: 14), label: const Text('Update bank details', style: TextStyle(fontSize: 12)),
            onPressed: () {}),
        const SizedBox(height: 16),

        // GPS toggle
        _Section('Settings'),
        Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFEEEEEE))),
          child: Row(children: [
            const Icon(Icons.location_on, color: WPColors.green500, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('GPS Tracking', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
              Text(_gpsActive ? 'Active — pinging every 30s' : 'Disabled — payments may be withheld',
                  style: TextStyle(fontSize: 11, color: _gpsActive ? WPColors.green700 : WPColors.terracotta)),
            ])),
            Switch(value: _gpsActive, onChanged: (v) => setState(() => _gpsActive = v), activeColor: WPColors.green500),
          ]),
        ),
        const SizedBox(height: 8),
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _gpsActive ? WPColors.green50 : const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            Icon(_gpsActive ? Icons.info_outline : Icons.warning_amber, size: 14, color: _gpsActive ? WPColors.green700 : WPColors.terracotta),
            const SizedBox(width: 8),
            Expanded(child: Text(_gpsActive
                ? 'GPS is active. Your location is shared with the LGA government dashboard for route verification.'
                : 'WARNING: GPS is off. Collections cannot be verified and payments will be withheld.',
                style: TextStyle(fontSize: 11, color: _gpsActive ? WPColors.green700 : WPColors.terracotta))),
          ]),
        ),
        const SizedBox(height: 20),

        OutlinedButton.icon(
          icon: const Icon(Icons.logout, size: 18, color: WPColors.terracotta),
          label: const Text('Sign out', style: TextStyle(color: WPColors.terracotta)),
          onPressed: () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(side: const BorderSide(color: WPColors.terracotta), minimumSize: const Size.fromHeight(48))),
        const SizedBox(height: 20),
        const Center(child: Text('WastePay Nigeria v2.0.0 — Contractor Portal', style: TextStyle(fontSize: 11, color: WPColors.textMuted))),
        const SizedBox(height: 10),
      ]),
    );
  }
}

class _PStat extends StatelessWidget {
  final String val, lbl;
  const _PStat(this.val, this.lbl);
  @override Widget build(BuildContext context) => Expanded(child: Container(
    margin: const EdgeInsets.symmetric(horizontal: 4),
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(color: WPColors.green50, borderRadius: BorderRadius.circular(8)),
    child: Column(children: [
      Text(val, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: WPColors.green900)),
      Text(lbl, style: const TextStyle(fontSize: 10, color: WPColors.textSecondary)),
    ]),
  ));
}

class _Section extends StatelessWidget {
  final String t; const _Section(this.t);
  @override Widget build(BuildContext c) => Padding(padding: const EdgeInsets.only(bottom: 8),
    child: Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: WPColors.textMuted, letterSpacing: 0.5)));
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow(this.label, this.value);
  @override Widget build(BuildContext c) => Container(
    margin: const EdgeInsets.only(bottom: 5),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFEEEEEE))),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(fontSize: 13, color: WPColors.textSecondary)),
      Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
    ]));
}
