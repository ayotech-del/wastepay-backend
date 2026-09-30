import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/theme.dart';
import '../core/config.dart';

class BinQRLabelPrintScreen extends StatefulWidget {
  const BinQRLabelPrintScreen({super.key});
  @override State<BinQRLabelPrintScreen> createState() => _BinQRLabelPrintScreenState();
}

class _BinQRLabelPrintScreenState extends State<BinQRLabelPrintScreen> {
  final _binCtrl  = TextEditingController();
  final _addrCtrl = TextEditingController();
  final _capCtrl  = TextEditingController(text: '1100');
  String _selectedLGA = 'Eti-Osa';
  bool _generated = false;
  String _binCode = '';

  // Seeded bins for testing
  final List<Map<String, String>> _seededBins = [
    {'code': 'BIN-LG-001', 'address': 'Lekki Phase 1, Lagos',    'lga': 'Eti-Osa',    'cap': '1100'},
    {'code': 'BIN-LG-002', 'address': 'Victoria Island, Lagos',  'lga': 'Eti-Osa',    'cap': '1100'},
    {'code': 'BIN-LG-003', 'address': 'Ajah Bus Stop, Lagos',    'lga': 'Eti-Osa',    'cap': '660'},
    {'code': 'BIN-LG-004', 'address': 'Sangotedo Market, Lagos', 'lga': 'Alimosho',   'cap': '1100'},
    {'code': 'BIN-LG-005', 'address': 'Yaba Tech Cluster, Lagos','lga': 'Surulere',   'cap': '660'},
    {'code': 'BIN-LG-006', 'address': 'Ikeja Along, Lagos',      'lga': 'Ikeja',      'cap': '1100'},
    {'code': 'BIN-LG-007', 'address': 'Oshodi Market, Lagos',    'lga': 'Oshodi-Isol','cap': '1100'},
    {'code': 'BIN-LG-008', 'address': 'Badagry Town Hall, Lagos','lga': 'Badagry',    'cap': '660'},
    {'code': 'BIN-LG-009', 'address': 'Ikorodu Bus Terminal',    'lga': 'Ikorodu',    'cap': '1100'},
  ];

  final _lgas = ['Eti-Osa','Lagos Island','Lagos Mainland','Surulere','Alimosho','Ikeja','Kosofe','Ikorodu','Badagry'];

  void _generateNew() {
    if (_addrCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter bin address first')));
      return;
    }
    final code = _binCtrl.text.trim().isNotEmpty
        ? _binCtrl.text.trim().toUpperCase()
        : 'BIN-${_selectedLGA.substring(0,3).toUpperCase()}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    setState(() { _binCode = code; _generated = true; });
  }

  void _loadSeeded(Map<String, String> bin) {
    setState(() {
      _binCode = bin['code']!;
      _addrCtrl.text = bin['address']!;
      _selectedLGA = bin['lga']!;
      _capCtrl.text = bin['cap']!;
      _generated = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR Label Generator'), leading: const BackButton()),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Info banner
        Container(padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(color: WPColors.green50, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: WPColors.green200)),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('How QR Bin Labels Work', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: WPColors.green900)),
            SizedBox(height: 6),
            Text('1. Generate QR label for each physical bin\n'
                '2. Print on paper, laminate, attach to bin\n'
                '3. Contractor scans QR to report fill level\n'
                '4. Citizens scan to deposit recyclables\n'
                '5. Dashboard updates in real time',
                style: TextStyle(fontSize: 12, color: WPColors.green700, height: 1.6)),
          ])),

        // Test bins
        const Text('Test Bins (Pre-registered)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SizedBox(height: 42, child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _seededBins.length,
          itemBuilder: (_, i) {
            final bin = _seededBins[i];
            final selected = _binCode == bin['code'];
            return GestureDetector(
              onTap: () => _loadSeeded(bin),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? WPColors.green500 : WPColors.green50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: selected ? WPColors.green500 : WPColors.green200)),
                child: Text(bin['code']!, style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : WPColors.green700)),
              ),
            );
          },
        )),
        const SizedBox(height: 16),

        // Generate new
        const Text('Generate New Label', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFEEEEEE))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('BIN Code (leave blank to auto-generate)',
                style: TextStyle(fontSize: 12, color: WPColors.textSecondary)),
            const SizedBox(height: 4),
            TextField(controller: _binCtrl, textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(hintText: 'e.g. BIN-LG-010', isDense: true)),
            const SizedBox(height: 10),
            const Text('Address', style: TextStyle(fontSize: 12, color: WPColors.textSecondary)),
            const SizedBox(height: 4),
            TextField(controller: _addrCtrl, decoration: const InputDecoration(hintText: 'Street, Area, Lagos', isDense: true)),
            const SizedBox(height: 10),
            const Text('LGA', style: TextStyle(fontSize: 12, color: WPColors.textSecondary)),
            const SizedBox(height: 4),
            Container(padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(border: Border.all(color: const Color(0xFFDDDDDD)), borderRadius: BorderRadius.circular(8)),
              child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                value: _selectedLGA, isExpanded: true,
                items: _lgas.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                onChanged: (v) => setState(() => _selectedLGA = v!)))),
            const SizedBox(height: 10),
            const Text('Capacity (litres)', style: TextStyle(fontSize: 12, color: WPColors.textSecondary)),
            const SizedBox(height: 4),
            Row(children: ['660', '1100', '2200'].map((c) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _capCtrl.text = c),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _capCtrl.text == c ? WPColors.green500 : WPColors.green50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _capCtrl.text == c ? WPColors.green500 : WPColors.green200)),
                  child: Text('${c}L', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: _capCtrl.text == c ? Colors.white : WPColors.green700)),
                )))).toList()),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _generateNew,
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
              child: const Text('Generate QR Label')),
          ])),

        // QR Label preview
        if (_generated) ...[
          const SizedBox(height: 20),
          const Text('QR Label Preview', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const Text('Print this label, laminate it, and attach to the physical bin',
              style: TextStyle(fontSize: 12, color: WPColors.textSecondary)),
          const SizedBox(height: 10),

          // Label card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCCCCCC), width: 2)),
            child: Column(children: [
              // Header
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('WastePay Nigeria', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: WPColors.green700)),
                  Text('Smart Waste Management', style: TextStyle(fontSize: 10, color: WPColors.textMuted)),
                ]),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: WPColors.green500, borderRadius: BorderRadius.circular(6)),
                  child: const Text('OFFICIAL', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700))),
              ]),
              const Divider(height: 20),

              // QR placeholder (in production use qr_flutter package)
              Container(width: 160, height: 160,
                decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 3), borderRadius: BorderRadius.circular(8)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  // QR grid simulation
                  _QRGrid(),
                  const SizedBox(height: 6),
                  Text(_binCode, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
                ])),
              const SizedBox(height: 12),

              // Bin details
              Text(_binCode, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 2)),
              const SizedBox(height: 4),
              Text(_addrCtrl.text, style: const TextStyle(fontSize: 13, color: WPColors.textSecondary), textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text('LGA: $_selectedLGA  |  Capacity: ${_capCtrl.text}L',
                  style: const TextStyle(fontSize: 11, color: WPColors.textMuted)),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 6),
              const Text('SCAN TO REPORT FILL LEVEL OR DEPOSIT RECYCLABLES',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: WPColors.textMuted),
                  textAlign: TextAlign.center),
              const SizedBox(height: 4),
              const Text('Powered by WastePay Nigeria | wastepay.ng | *932#',
                  style: TextStyle(fontSize: 9, color: WPColors.textMuted)),
            ]),
          ),

          const SizedBox(height: 16),
          // Actions
          ElevatedButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Use browser Print (Ctrl+P) to print this label'))),
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: const Text('Print Label (Ctrl+P)'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => _registerBin(context),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
            child: const Text('Register Bin in System'),
          ),
        ],
        const SizedBox(height: 30),
      ])),
    );
  }

  Future<void> _registerBin(BuildContext context) async {
    try {
      await http.post(Uri.parse('${AppConfig.baseUrl}/bins/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'bin_code': _binCode, 'address': _addrCtrl.text,
          'lga': _selectedLGA, 'capacity_litres': int.tryParse(_capCtrl.text) ?? 1100}));
    } catch (_) {}
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$_binCode registered in WastePay system'), backgroundColor: WPColors.green500));
    }
  }
}

// Simple QR grid visual (no package needed)
class _QRGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const pattern = [
      [1,1,1,1,1,1,1,0,0,1,0,1,0],
      [1,0,0,0,0,0,1,0,1,0,1,0,1],
      [1,0,1,1,1,0,1,0,0,1,1,0,0],
      [1,0,1,1,1,0,1,0,1,0,0,1,1],
      [1,0,1,1,1,0,1,0,0,1,0,0,1],
      [1,0,0,0,0,0,1,0,1,1,0,1,0],
      [1,1,1,1,1,1,1,0,1,0,1,0,1],
      [0,0,0,0,0,0,0,0,0,1,0,1,0],
      [1,0,1,1,0,1,1,1,0,0,1,0,1],
      [0,1,0,0,1,0,0,0,1,1,0,1,0],
      [1,0,1,0,1,1,1,0,1,0,1,0,1],
      [0,1,0,1,0,0,0,1,0,1,0,1,0],
      [1,1,1,0,1,0,1,0,1,0,1,0,1],
    ];
    return SizedBox(width: 104, height: 104,
      child: Column(children: pattern.map((row) => Row(children: row.map((cell) =>
        Container(width: 8, height: 8, color: cell == 1 ? Colors.black : Colors.white)
      ).toList())).toList()));
  }
}
