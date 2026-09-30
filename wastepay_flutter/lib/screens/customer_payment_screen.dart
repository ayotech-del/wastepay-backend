// WastePay Nigeria — Customer Payment Screen
// Filter by State → LGA → BIN number → Contractor → Pay
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/theme.dart';
import '../core/config.dart';

class CustomerPaymentScreen extends StatefulWidget {
  const CustomerPaymentScreen({super.key});
  @override State<CustomerPaymentScreen> createState() => _CustomerPaymentScreenState();
}

class _CustomerPaymentScreenState extends State<CustomerPaymentScreen> {
  // Step: 0=state, 1=lga, 2=bin, 3=contractor, 4=pay, 5=done
  int _step = 0;
  String? _selectedState;
  Map<String, String>? _selectedLGA;
  Map<String, dynamic>? _household;
  Map<String, dynamic>? _selectedContractor;
  List<Map<String, String>> _lgas = [];
  List<Map<String, dynamic>> _contractors = [];
  bool _loading = false;
  String? _error;
  final _binCtrl = TextEditingController();
  final _amtCtrl = TextEditingController(text: '3500');

  final _states = ['Lagos','Ogun','Oyo','Osun','Ondo','Ekiti'];
  final _stateIcons = {
    'Lagos': Icons.waves, 'Ogun': Icons.factory,
    'Oyo': Icons.account_balance, 'Osun': Icons.water_drop,
    'Ondo': Icons.forest, 'Ekiti': Icons.landscape,
  };

  Future<void> _loadLGAs(String state) async {
    setState(() { _loading = true; _lgas = []; });
    try {
      final r = await http.get(Uri.parse('${AppConfig.baseUrl}/lga/list?state=${Uri.encodeComponent(state)}'));
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        final list = (data['lgas'] as List).map((e) => {'id': e['id'].toString(), 'name': e['name'].toString()}).toList();
        setState(() { _lgas = list; _loading = false; _step = 1; });
      } else { setState(() { _loading = false; _step = 1; }); }
    } catch (_) {
      setState(() {
        _lgas = [
          {'id': '878d4350-553e-4d76-abab-f531bcdefefe', 'name': 'Eti-Osa'},
          {'id': '4e7f162a-56c8-43df-818f-d486c69350f9', 'name': 'Lagos Island'},
          {'id': '0215a68f-3f85-452f-a490-63d6e8031ab8', 'name': 'Lagos Mainland'},
          {'id': '4a564421-5e00-4232-8c57-5e5b55d01cc2', 'name': 'Surulere'},
          {'id': '92d74cb1-4ae9-48bb-9318-94178509aa0c', 'name': 'Alimosho'},
        ];
        _loading = false; _step = 1;
      });
    }
  }

  Future<void> _lookupBIN() async {
    final bin = _binCtrl.text.trim().toUpperCase();
    if (bin.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      final r = await http.get(Uri.parse('${AppConfig.baseUrl}/billing/household/$bin'));
      if (r.statusCode == 200) {
        setState(() { _household = jsonDecode(r.body); _loading = false; _step = 3; });
        _loadContractors();
      } else {
        setState(() { _error = 'BIN not found in ${_selectedLGA?['name']}. Contact your LGA.'; _loading = false; });
      }
    } catch (_) {
      setState(() {
        _household = {'bin_number': bin, 'address': '12 Adeola Street, ${_selectedLGA?['name']}, $_selectedState',
          'lga': _selectedLGA?['name'] ?? '', 'state': _selectedState ?? '', 'monthly_levy': double.tryParse(_amtCtrl.text) ?? 3500.0};
        _loading = false; _step = 3;
      });
      _loadContractors();
    }
  }

  Future<void> _loadContractors() async {
    try {
      final r = await http.get(Uri.parse('${AppConfig.baseUrl}/contractors/company/list?state=${Uri.encodeComponent(_selectedState ?? '')}'));
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        setState(() { _contractors = List<Map<String, dynamic>>.from(data['companies'] ?? []); });
      }
    } catch (_) {
      setState(() {
        _contractors = [
          {'id': 'c1', 'name': 'Lagos Waste Solutions Ltd', 'rc_number': 'RC-1234567', 'fleet_size': 12,
           'director': 'Adewale Okafor', 'trucks': [{'wastepay_id': 'WP-LG-001'},{'wastepay_id': 'WP-LG-002'}]},
          {'id': 'c2', 'name': 'EcoClean Nigeria Ltd', 'rc_number': 'RC-7654321', 'fleet_size': 8,
           'director': 'Fatima Kwari', 'trucks': [{'wastepay_id': 'WP-LG-003'}]},
        ];
      });
    }
  }

  Future<void> _makePayment(String method) async {
    setState(() { _loading = true; });
    await Future.delayed(const Duration(seconds: 1));
    setState(() { _loading = false; _step = 5; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WPColors.navy,
      body: Column(children: [
        SafeArea(bottom: false, child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(children: [
            Row(children: [
              if (_step > 0) IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => setState(() { _step = _step - 1; _error = null; }))
              else const BackButton(color: Colors.white),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('WastePay Nigeria', style: TextStyle(color: WPColors.green200, fontSize: 11)),
                Text('Pay Waste Levy', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
              ])),
              const Icon(Icons.payments_outlined, color: WPColors.goldLight, size: 28),
            ]),
            const SizedBox(height: 12),
            // Progress
            Row(children: List.generate(5, (i) => Expanded(child: Container(
              margin: EdgeInsets.only(right: i < 4 ? 4 : 0), height: 4,
              decoration: BoxDecoration(
                color: i < _step ? WPColors.green500 : i == _step ? WPColors.green200 : WPColors.green700.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2)))))),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              for (final label in ['State', 'LGA', 'BIN', 'Contractor', 'Pay'])
                Text(label, style: TextStyle(fontSize: 9, color: ['State','LGA','BIN','Contractor','Pay'].indexOf(label) <= _step ? WPColors.green500 : WPColors.green200)),
            ]),
          ]),
        )),
        Expanded(child: Container(
          margin: const EdgeInsets.only(top: 12),
          decoration: const BoxDecoration(color: WPColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: _buildStep()),
        )),
      ]),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0: return _stepState();
      case 1: return _stepLGA();
      case 2: return _stepBIN();
      case 3: return _stepContractor();
      case 4: return _stepPay();
      case 5: return _stepDone();
      default: return _stepState();
    }
  }

  Widget _stepState() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Select Your State', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
    const SizedBox(height: 6),
    const Text('Which state is your property in?', style: TextStyle(color: WPColors.textSecondary, fontSize: 14)),
    const SizedBox(height: 20),
    GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 2.2),
      itemCount: _states.length,
      itemBuilder: (_, i) {
        final s = _states[i];
        final icon = _stateIcons[s] ?? Icons.location_on;
        return GestureDetector(
          onTap: () { setState(() => _selectedState = s); _loadLGAs(s); },
          child: Container(
            decoration: BoxDecoration(color: WPColors.green500.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12),
                border: Border.all(color: WPColors.green200)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: WPColors.green500, size: 20),
              const SizedBox(width: 8),
              Text(s, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: WPColors.green900)),
            ])));
      }),
    if (_loading) const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: WPColors.green500))),
  ]);

  Widget _stepLGA() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('Select LGA in $_selectedState', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
    const SizedBox(height: 6),
    const Text('Which local government area is your property in?', style: TextStyle(color: WPColors.textSecondary, fontSize: 14)),
    const SizedBox(height: 20),
    if (_loading) const Center(child: CircularProgressIndicator(color: WPColors.green500))
    else ..._lgas.map((lga) => GestureDetector(
      onTap: () => setState(() { _selectedLGA = lga; _step = 2; }),
      child: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFEEEEEE))),
        child: Row(children: [
          const Icon(Icons.location_city, color: WPColors.green500, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(lga['name']!, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14))),
          const Icon(Icons.chevron_right, color: WPColors.green500, size: 18),
        ])))),
  ]);

  Widget _stepBIN() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Enter BIN Number', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
    const SizedBox(height: 6),
    Text('Enter your household BIN number for ${_selectedLGA?['name']}, $_selectedState',
        style: const TextStyle(color: WPColors.textSecondary, fontSize: 14)),
    const SizedBox(height: 20),
    Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: WPColors.green50, borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        const Icon(Icons.tag, size: 40, color: WPColors.green500),
        const SizedBox(height: 6),
        Text('Format: BIN-${(_selectedLGA?['name'] ?? 'LGA').substring(0,3).toUpperCase()}-000001',
            style: const TextStyle(fontSize: 12, color: WPColors.textMuted)),
      ])),
    const SizedBox(height: 16),
    TextField(controller: _binCtrl, textCapitalization: TextCapitalization.characters,
      onChanged: (_) => setState(() => _error = null),
      decoration: InputDecoration(labelText: 'BIN Number', hintText: 'e.g. BIN-ETI-001234',
        prefixIcon: const Icon(Icons.tag, color: WPColors.green500),
        errorText: _error, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
    const SizedBox(height: 14),
    ElevatedButton.icon(
      icon: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : const Icon(Icons.search, size: 18),
      label: Text(_loading ? 'Looking up...' : 'Find My Account'),
      onPressed: _loading ? null : _lookupBIN,
      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50))),
  ]);

  Widget _stepContractor() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Select Contractor', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
    const SizedBox(height: 6),
    Text('Choose your waste contractor in ${_household?['lga']}, $_selectedState',
        style: const TextStyle(color: WPColors.textSecondary, fontSize: 14)),
    const SizedBox(height: 14),
    // BIN summary
    Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: WPColors.green50, borderRadius: BorderRadius.circular(10), border: Border.all(color: WPColors.green200)),
      child: Row(children: [
        const Icon(Icons.tag, color: WPColors.green500, size: 16),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_household?['bin_number'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, color: WPColors.green900)),
          Text(_household?['address'] ?? '', style: const TextStyle(fontSize: 11, color: WPColors.green700)),
        ]),
      ])),
    const SizedBox(height: 14),
    if (_contractors.isEmpty) const Center(child: CircularProgressIndicator(color: WPColors.green500))
    else ..._contractors.map((c) {
      final selected = _selectedContractor?['id'] == c['id'];
      final trucks = (c['trucks'] as List?) ?? [];
      return GestureDetector(
        onTap: () => setState(() => _selectedContractor = c),
        child: Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? WPColors.green50 : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? WPColors.green500 : const Color(0xFFEEEEEE), width: selected ? 2 : 1)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 42, height: 42, decoration: BoxDecoration(color: selected ? WPColors.green500 : WPColors.green50, borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.local_shipping, color: selected ? Colors.white : WPColors.green500, size: 22)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c['name'] as String, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                Text('RC: ${c['rc_number'] ?? 'N/A'} • ${c['fleet_size'] ?? trucks.length} trucks',
                    style: const TextStyle(fontSize: 11, color: WPColors.textSecondary)),
              ])),
              if (selected) const Icon(Icons.check_circle, color: WPColors.green500, size: 22),
            ]),
            if (trucks.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 6, children: trucks.take(4).map((t) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: WPColors.navy.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(6)),
                child: Text(t['wastepay_id'] as String? ?? '', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: WPColors.navy)))).toList()),
            ],
          ])));
    }),
    if (_selectedContractor != null) ...[
      const SizedBox(height: 14),
      ElevatedButton.icon(icon: const Icon(Icons.check, size: 18),
        label: Text('Pay with ${_selectedContractor!['name']}'),
        onPressed: () => setState(() => _step = 4),
        style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50))),
    ],
  ]);

  Widget _stepPay() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Make Payment', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
    const SizedBox(height: 6),
    const Text('Choose your payment method', style: TextStyle(color: WPColors.textSecondary, fontSize: 14)),
    const SizedBox(height: 16),
    Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: WPColors.navy, borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('BIN Number', style: TextStyle(color: WPColors.green200, fontSize: 12)),
          Text(_household?['bin_number'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Contractor', style: TextStyle(color: WPColors.green200, fontSize: 12)),
          Flexible(child: Text(_selectedContractor?['name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
        ]),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('LGA', style: TextStyle(color: WPColors.green200, fontSize: 12)),
          Text('${_selectedLGA?['name']}, $_selectedState', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
        const Divider(color: WPColors.green700, height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Amount', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
          Text('₦${_household?['monthly_levy']?.toStringAsFixed(0) ?? '3,500'}',
              style: const TextStyle(color: WPColors.goldLight, fontSize: 22, fontWeight: FontWeight.w700)),
        ]),
      ])),
    const SizedBox(height: 20),
    const Text('Pay with:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
    const SizedBox(height: 10),
    _POpt(Icons.account_balance_wallet, 'Eco Credits', 'Use recycling credits — FREE!', WPColors.green500, true, () => _makePayment('credits')),
    _POpt(Icons.credit_card, 'Debit/Credit Card', 'Visa, Mastercard via Paystack', WPColors.navy, false, () => _makePayment('card')),
    _POpt(Icons.phone_android, 'USSD *932#', 'Works on any phone, no internet', WPColors.gold, false, () => _makePayment('ussd')),
    _POpt(Icons.account_balance, 'Bank Transfer', 'Direct to contractor account', Colors.blue, false, () => _makePayment('bank')),
    if (_loading) const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: WPColors.green500))),
  ]);

  Widget _stepDone() => Column(children: [
    const SizedBox(height: 32),
    Container(width: 80, height: 80, decoration: const BoxDecoration(color: WPColors.green500, shape: BoxShape.circle),
        child: const Center(child: Icon(Icons.check, color: Colors.white, size: 44))),
    const SizedBox(height: 20),
    const Text('Payment Successful!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
    const SizedBox(height: 8),
    const Text('Your waste levy has been paid.', style: TextStyle(color: WPColors.textSecondary), textAlign: TextAlign.center),
    const SizedBox(height: 24),
    Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: WPColors.green50, borderRadius: BorderRadius.circular(12), border: Border.all(color: WPColors.green200)),
      child: Column(children: [
        _SR('BIN Number', _household?['bin_number'] ?? ''),
        const Divider(height: 16),
        _SR('State / LGA', '${_selectedLGA?['name']}, $_selectedState'),
        const Divider(height: 16),
        _SR('Contractor', _selectedContractor?['name'] ?? ''),
        const Divider(height: 16),
        _SR('Amount paid', '₦${_household?['monthly_levy']?.toStringAsFixed(0) ?? '3,500'}'),
        const Divider(height: 16),
        _SR('Reference', 'WP-PAY-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}'),
      ])),
    const SizedBox(height: 20),
    Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: WPColors.navy, borderRadius: BorderRadius.circular(10)),
      child: const Row(children: [
        Icon(Icons.lightbulb_outline, color: WPColors.goldLight, size: 16), SizedBox(width: 8),
        Expanded(child: Text('Deposit recyclables at any smart bin to earn Eco Credits and pay next month for free!',
            style: TextStyle(color: WPColors.green200, fontSize: 12))),
      ])),
    const SizedBox(height: 24),
    ElevatedButton.icon(icon: const Icon(Icons.home, size: 18), label: const Text('Back to Home'),
      onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50))),
    const SizedBox(height: 10),
    OutlinedButton.icon(icon: const Icon(Icons.download, size: 16), label: const Text('Download Receipt'),
      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Receipt PDF — coming soon'))),
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44))),
    const SizedBox(height: 20),
  ]);
}

class _POpt extends StatelessWidget {
  final IconData icon; final String title, subtitle; final Color color;
  final bool recommended; final VoidCallback onTap;
  const _POpt(this.icon, this.title, this.subtitle, this.color, this.recommended, this.onTap);
  @override Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: recommended ? WPColors.green50 : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: recommended ? WPColors.green500 : const Color(0xFFEEEEEE), width: recommended ? 2 : 1)),
      child: Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            if (recommended) ...[const SizedBox(width: 6),
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: WPColors.green500, borderRadius: BorderRadius.circular(4)),
                child: const Text('FREE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)))],
          ]),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: WPColors.textSecondary)),
        ])),
        const Icon(Icons.arrow_forward_ios, size: 14, color: WPColors.textMuted),
      ])));
}

class _SR extends StatelessWidget {
  final String l, v; const _SR(this.l, this.v);
  @override Widget build(BuildContext context) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(l, style: const TextStyle(fontSize: 12, color: WPColors.textSecondary)),
    Text(v, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
  ]);
}
