// WastePay Nigeria — Customer Onboarding
// BIN number login → contractor selection → payment setup
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/theme.dart';
import '../core/config.dart';

class CustomerOnboardingScreen extends StatefulWidget {
  const CustomerOnboardingScreen({super.key});
  @override State<CustomerOnboardingScreen> createState() => _CustomerOnboardingScreenState();
}

class _CustomerOnboardingScreenState extends State<CustomerOnboardingScreen> {
  int _step = 0; // 0=enter BIN, 1=confirm address, 2=select contractor, 3=payment setup, 4=done
  final _binCtrl = TextEditingController();
  Map<String, dynamic>? _household;
  List<Map<String, dynamic>> _companies = [];
  Map<String, dynamic>? _selectedCompany;
  bool _loading = false;
  String? _error;

  Future<void> _lookupBIN() async {
    if (_binCtrl.text.trim().isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      final r = await http.get(Uri.parse('${AppConfig.baseUrl}/billing/household/${_binCtrl.text.trim().toUpperCase()}'));
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        setState(() { _household = data; _loading = false; _step = 1; });
      } else {
        final data = jsonDecode(r.body);
        setState(() { _error = data['detail'] ?? 'BIN number not found. Contact your LGA office.'; _loading = false; });
      }
    } catch (_) {
      // Demo mode
      setState(() {
        _household = {'bin_number': _binCtrl.text.trim().toUpperCase(), 'address': '12 Adeola Street, Lekki Phase 1, Lagos',
          'lga': 'Eti-Osa', 'state': 'Lagos', 'property_type': 'residential', 'monthly_levy': 3500.0, 'linked': false};
        _loading = false; _step = 1;
      });
    }
  }

  Future<void> _loadContractors() async {
    setState(() { _loading = true; });
    try {
      final state = _household?['state'] ?? 'Lagos';
      final r = await http.get(Uri.parse('${AppConfig.baseUrl}/contractors/company/list?state=$state'));
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        setState(() { _companies = List<Map<String, dynamic>>.from(data['companies']); _loading = false; _step = 2; });
      } else { setState(() { _loading = false; _step = 2; }); }
    } catch (_) {
      setState(() {
        _companies = [
          {'id': 'demo-001', 'name': 'Lagos Waste Solutions Ltd', 'rc_number': 'RC-1234567',
           'state': 'Lagos', 'fleet_size': 12, 'director': 'Adewale Okafor', 'contact_phone': 'YOUR_PHONE_NUMBER',
           'trucks': [{'wastepay_id': 'WP-LG-001'}, {'wastepay_id': 'WP-LG-002'}]},
          {'id': 'demo-002', 'name': 'EcoClean Nigeria Ltd', 'rc_number': 'RC-7654321',
           'state': 'Lagos', 'fleet_size': 8, 'director': 'Fatima Kwari', 'contact_phone': 'YOUR_PHONE_NUMBER',
           'trucks': [{'wastepay_id': 'WP-LG-003'}]},
          {'id': 'demo-003', 'name': 'Green Earth Waste Mgmt', 'rc_number': 'RC-9876543',
           'state': 'Lagos', 'fleet_size': 5, 'director': 'Chukwudi Bello', 'contact_phone': 'YOUR_PHONE_NUMBER',
           'trucks': []},
        ];
        _loading = false; _step = 2;
      });
    }
  }

  Future<void> _selectContractor(Map<String, dynamic> company) async {
    setState(() { _selectedCompany = company; _loading = true; });
    try {
      await http.post(Uri.parse('${AppConfig.baseUrl}/billing/household/contractor/select'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'bin_number': _household?['bin_number'], 'company_id': company['id']}));
    } catch (_) {}
    setState(() { _loading = false; _step = 3; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WPColors.navy,
      body: Column(children: [
        // Header
        SafeArea(bottom: false, child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(children: [
            const Row(children: [
              BackButton(color: Colors.white),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('WastePay Nigeria', style: TextStyle(color: WPColors.green200, fontSize: 11)),
                Text('Customer Setup', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
              ])),
              Text('♻', style: TextStyle(fontSize: 28)),
            ]),
            const SizedBox(height: 16),
            // Step indicator
            Row(children: List.generate(4, (i) => Expanded(child: Row(children: [
              Expanded(child: Container(height: 4, decoration: BoxDecoration(
                color: i <= _step - 1 ? WPColors.green500 : WPColors.green700.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2)))),
              if (i < 3) const SizedBox(width: 4),
            ])))),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _StepDot(0, _step, 'BIN'),
              _StepDot(1, _step, 'Address'),
              _StepDot(2, _step, 'Contractor'),
              _StepDot(3, _step, 'Payment'),
            ]),
          ]),
        )),

        // Body
        Expanded(child: Container(
          margin: const EdgeInsets.only(top: 16),
          decoration: const BoxDecoration(color: WPColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: _buildStep()),
        )),
      ]),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0: return _stepBIN();
      case 1: return _stepConfirm();
      case 2: return _stepContractor();
      case 3: return _stepPayment();
      case 4: return _stepDone();
      default: return _stepBIN();
    }
  }

  // ── STEP 0: Enter BIN number ──────────────────────────────────────────────
  Widget _stepBIN() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Enter Your BIN Number', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
    const SizedBox(height: 8),
    const Text('Your BIN (Bin Identification Number) was assigned by your LGA when your household was registered.',
        style: TextStyle(color: WPColors.textSecondary, fontSize: 14)),
    const SizedBox(height: 24),
    Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: WPColors.green50, borderRadius: BorderRadius.circular(12)),
      child: const Column(children: [
        Icon(Icons.qr_code, size: 48, color: WPColors.green500),
        SizedBox(height: 8),
        Text('BIN format: BIN-ETI-001234', style: TextStyle(fontSize: 12, color: WPColors.textMuted)),
      ])),
    const SizedBox(height: 20),
    TextField(
      controller: _binCtrl,
      textCapitalization: TextCapitalization.characters,
      decoration: InputDecoration(
        labelText: 'BIN Number',
        hintText: 'e.g. BIN-ETI-001234',
        prefixIcon: const Icon(Icons.tag, color: WPColors.green500),
        suffixIcon: _binCtrl.text.isNotEmpty
            ? IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () { _binCtrl.clear(); setState(() {}); })
            : null,
        errorText: _error,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onChanged: (_) => setState(() => _error = null),
      onSubmitted: (_) => _lookupBIN(),
    ),
    const SizedBox(height: 16),
    ElevatedButton.icon(
      icon: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : const Icon(Icons.search, size: 18),
      label: Text(_loading ? 'Looking up...' : 'Find My Account'),
      onPressed: _loading ? null : _lookupBIN,
      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
    ),
    const SizedBox(height: 20),
    Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(10), border: Border.all(color: WPColors.gold)),
      child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.help_outline, color: WPColors.gold, size: 16),
          SizedBox(width: 8),
          Text('Don\'t have a BIN number?', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: WPColors.navy)),
        ]),
        SizedBox(height: 6),
        Text('Visit your LGA office to register your household and receive a BIN number. You can also dial *932# and select "Register Household".',
            style: TextStyle(fontSize: 12, color: WPColors.textSecondary)),
      ])),
  ]);

  // ── STEP 1: Confirm address ───────────────────────────────────────────────
  Widget _stepConfirm() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Confirm Your Address', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
    const SizedBox(height: 8),
    const Text('Please confirm this is your property before continuing.', style: TextStyle(color: WPColors.textSecondary, fontSize: 14)),
    const SizedBox(height: 24),
    Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFEEEEEE))),
      child: Column(children: [
        _InfoRow('BIN Number', _household?['bin_number'] ?? '', icon: Icons.tag, color: WPColors.green500),
        const Divider(height: 20),
        _InfoRow('Address', _household?['address'] ?? '', icon: Icons.home_outlined),
        const Divider(height: 20),
        _InfoRow('LGA', '${_household?['lga']}, ${_household?['state']}', icon: Icons.location_city_outlined),
        const Divider(height: 20),
        _InfoRow('Property Type', (_household?['property_type'] ?? '').toString().toUpperCase(), icon: Icons.apartment_outlined),
        const Divider(height: 20),
        _InfoRow('Monthly Levy', '₦${_household?['monthly_levy']?.toStringAsFixed(0) ?? '3,500'}', icon: Icons.payments_outlined, color: WPColors.green500),
      ])),
    const SizedBox(height: 24),
    ElevatedButton.icon(
      icon: const Icon(Icons.check, size: 18),
      label: const Text('Yes, this is my property'),
      onPressed: _loadContractors,
      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
    ),
    const SizedBox(height: 10),
    OutlinedButton(
      onPressed: () => setState(() { _step = 0; _household = null; }),
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
      child: const Text('Not my property — try again'),
    ),
  ]);

  // ── STEP 2: Select contractor ─────────────────────────────────────────────
  Widget _stepContractor() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Select Your Contractor', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
    const SizedBox(height: 8),
    Text('Choose the waste collection company serving your area in ${_household?['lga']}.',
        style: const TextStyle(color: WPColors.textSecondary, fontSize: 14)),
    const SizedBox(height: 20),
    if (_loading) const Center(child: CircularProgressIndicator(color: WPColors.green500))
    else if (_companies.isEmpty)
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: WPColors.green50, borderRadius: BorderRadius.circular(12)),
        child: const Column(children: [
          Icon(Icons.business_outlined, size: 40, color: WPColors.textMuted),
          SizedBox(height: 8),
          Text('No contractors registered in your area yet.', style: TextStyle(color: WPColors.textMuted)),
          Text('Contact your LGA office.', style: TextStyle(fontSize: 12, color: WPColors.textMuted)),
        ]))
    else
      ..._companies.map((c) {
        final trucks = (c['trucks'] as List?) ?? [];
        final isSelected = _selectedCompany?['id'] == c['id'];
        return GestureDetector(
          onTap: () => setState(() => _selectedCompany = c),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? WPColors.green50 : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isSelected ? WPColors.green500 : const Color(0xFFEEEEEE), width: isSelected ? 2 : 1),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 44, height: 44, decoration: BoxDecoration(
                    color: isSelected ? WPColors.green500 : WPColors.green50, borderRadius: BorderRadius.circular(10)),
                  child: Center(child: Text('🏢', style: TextStyle(fontSize: isSelected ? 22 : 20)))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c['name'] as String, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  Text('RC: ${c['rc_number'] ?? 'N/A'}', style: const TextStyle(fontSize: 11, color: WPColors.textSecondary)),
                ])),
                if (isSelected) const Icon(Icons.check_circle, color: WPColors.green500, size: 24),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                _Tag(Icons.local_shipping, '${c['fleet_size'] ?? trucks.length} trucks'),
                const SizedBox(width: 8),
                _Tag(Icons.person, c['director'] as String? ?? 'Director'),
                const SizedBox(width: 8),
                _Tag(Icons.location_on, c['state'] as String? ?? ''),
              ]),
              if (trucks.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 6, children: trucks.take(3).map((t) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: WPColors.navy.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
                  child: Text(t['wastepay_id'] as String? ?? '', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: WPColors.navy)),
                )).toList()),
              ],
            ]),
          ),
        );
      }),
    if (_selectedCompany != null) ...[
      const SizedBox(height: 16),
      ElevatedButton.icon(
        icon: const Icon(Icons.check, size: 18),
        label: Text('Select ${_selectedCompany!['name']}'),
        onPressed: () => _selectContractor(_selectedCompany!),
        style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
      ),
    ],
  ]);

  // ── STEP 3: Payment setup ─────────────────────────────────────────────────
  Widget _stepPayment() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Payment Setup', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
    const SizedBox(height: 8),
    const Text('Choose how you want to pay your monthly waste levy.', style: TextStyle(color: WPColors.textSecondary, fontSize: 14)),
    const SizedBox(height: 20),

    // Summary
    Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: WPColors.navy, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.receipt_long, color: WPColors.green200, size: 18),
          SizedBox(width: 8),
          Text('Payment Summary', style: TextStyle(color: WPColors.green200, fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 12),
        _SummaryRow('BIN Number', _household?['bin_number'] ?? ''),
        _SummaryRow('Address', (_household?['address'] ?? '').toString().length > 30
            ? '${(_household?['address'] ?? '').toString().substring(0, 30)}...' : _household?['address'] ?? ''),
        _SummaryRow('Contractor', _selectedCompany?['name'] ?? ''),
        _SummaryRow('Monthly levy', '₦${_household?['monthly_levy']?.toStringAsFixed(0) ?? '3,500'}'),
        const Divider(color: WPColors.green700, height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Due now (July 2026)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          Text('₦${_household?['monthly_levy']?.toStringAsFixed(0) ?? '3,500'}', style: const TextStyle(color: WPColors.goldLight, fontSize: 18, fontWeight: FontWeight.w700)),
        ]),
      ])),
    const SizedBox(height: 20),

    // Payment options
    const Text('How would you like to pay?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
    const SizedBox(height: 10),
    _PayOption(Icons.account_balance_wallet, 'Eco Credits', 'Use recycling credits — free payment!', WPColors.green500, true, () => setState(() => _step = 4)),
    _PayOption(Icons.credit_card, 'Debit/Credit Card', 'Visa, Mastercard, Verve via Paystack', WPColors.navy, false, () => setState(() => _step = 4)),
    _PayOption(Icons.phone_android, 'USSD *932#', 'Pay without internet on any phone', WPColors.gold, false, () => setState(() => _step = 4)),
    _PayOption(Icons.account_balance, 'Bank Transfer', 'Pay directly to LGA sub-account', Colors.blue, false, () => setState(() => _step = 4)),
    const SizedBox(height: 16),
    OutlinedButton(onPressed: () => setState(() => _step = 2), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)), child: const Text('← Change contractor')),
  ]);

  // ── STEP 4: Done ──────────────────────────────────────────────────────────
  Widget _stepDone() => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const SizedBox(height: 40),
    Container(width: 80, height: 80, decoration: const BoxDecoration(color: WPColors.green500, shape: BoxShape.circle),
        child: const Center(child: Icon(Icons.check, color: Colors.white, size: 44))),
    const SizedBox(height: 20),
    const Text('Account Setup Complete!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
    const SizedBox(height: 8),
    Text('BIN ${_household?['bin_number']} is now active.', style: const TextStyle(color: WPColors.textSecondary, fontSize: 14), textAlign: TextAlign.center),
    const SizedBox(height: 24),
    Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: WPColors.green50, borderRadius: BorderRadius.circular(12), border: Border.all(color: WPColors.green200)),
      child: Column(children: [
        _InfoRow('BIN Number', _household?['bin_number'] ?? '', icon: Icons.tag, color: WPColors.green500),
        const Divider(height: 16),
        _InfoRow('Contractor', _selectedCompany?['name'] ?? '', icon: Icons.business_outlined),
        const Divider(height: 16),
        _InfoRow('Monthly levy', '₦${_household?['monthly_levy']?.toStringAsFixed(0) ?? '3,500'}', icon: Icons.payments_outlined, color: WPColors.green500),
        const Divider(height: 16),
        const _InfoRow('Next payment', 'August 1, 2026', icon: Icons.calendar_today_outlined),
      ])),
    const SizedBox(height: 24),
    Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: WPColors.navy, borderRadius: BorderRadius.circular(10)),
      child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.lightbulb_outline, color: WPColors.goldLight, size: 16),
          SizedBox(width: 8),
          Text('Earn Eco Credits!', style: TextStyle(color: WPColors.goldLight, fontWeight: FontWeight.w600, fontSize: 13)),
        ]),
        SizedBox(height: 6),
        Text('Deposit sorted recyclables at any WastePay smart bin to earn credits. Use credits to pay your next waste levy for free!',
            style: TextStyle(color: WPColors.green200, fontSize: 12)),
      ])),
    const SizedBox(height: 24),
    ElevatedButton.icon(
      icon: const Icon(Icons.home, size: 18),
      label: const Text('Go to Dashboard'),
      onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
    ),
    const SizedBox(height: 10),
    OutlinedButton.icon(
      icon: const Icon(Icons.share, size: 16),
      label: const Text('Share BIN number with household'),
      onPressed: () {},
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
    ),
  ]);
}

// ── Shared widgets ────────────────────────────────────────────────────────────
class _StepDot extends StatelessWidget {
  final int step, current; final String label;
  const _StepDot(this.step, this.current, this.label);
  @override Widget build(BuildContext context) {
    final done = step < current;
    final active = step == current;
    return Column(children: [
      Container(width: 24, height: 24, decoration: BoxDecoration(
        color: done ? WPColors.green500 : active ? WPColors.green500 : WPColors.green700.withValues(alpha: 0.3),
        shape: BoxShape.circle),
        child: Center(child: done
            ? const Icon(Icons.check, color: Colors.white, size: 13)
            : Text('${step+1}', style: TextStyle(color: active ? Colors.white : WPColors.green200, fontSize: 11, fontWeight: FontWeight.w700)))),
      const SizedBox(height: 3),
      Text(label, style: TextStyle(fontSize: 9, color: active ? WPColors.green500 : WPColors.green200)),
    ]);
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value; final IconData? icon; final Color? color;
  const _InfoRow(this.label, this.value, {this.icon, this.color});
  @override Widget build(BuildContext context) => Row(children: [
    if (icon != null) ...[Icon(icon!, size: 16, color: color ?? WPColors.textMuted), const SizedBox(width: 10)],
    Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: WPColors.textSecondary))),
    Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color ?? WPColors.textPrimary)),
  ]);
}

class _SummaryRow extends StatelessWidget {
  final String label, value;
  const _SummaryRow(this.label, this.value);
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 6),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: WPColors.green200, fontSize: 12)),
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
    ]));
}

class _Tag extends StatelessWidget {
  final IconData icon; final String text;
  const _Tag(this.icon, this.text);
  @override Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 12, color: WPColors.textMuted),
    const SizedBox(width: 3),
    Text(text, style: const TextStyle(fontSize: 11, color: WPColors.textSecondary)),
  ]);
}

class _PayOption extends StatelessWidget {
  final IconData icon; final String title, subtitle; final Color color;
  final bool recommended; final VoidCallback onTap;
  const _PayOption(this.icon, this.title, this.subtitle, this.color, this.recommended, this.onTap);
  @override Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: recommended ? WPColors.green50 : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: recommended ? WPColors.green500 : const Color(0xFFEEEEEE), width: recommended ? 2 : 1),
      ),
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
      ]),
    ),
  );
}
