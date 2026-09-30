import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/theme.dart';
import '../core/config.dart';
import 'lga_dashboard_screen.dart';
import 'state_dashboard_screen.dart';

class StateSelector extends StatefulWidget {
  const StateSelector({super.key});
  @override State<StateSelector> createState() => _StateSelectorState();
}

class _StateSelectorState extends State<StateSelector> {
  Map<String, int> _counts = {};
  bool _loading = true;

  final _states = [
    {
      'name': 'Lagos',
      'slogan': 'Centre of Excellence',
      'lgas': 20,
      'color': 0xFF0D1B2A,
      'accent': 0xFF1B5E20,
      'icon': Icons.waves,
    },
    {
      'name': 'Ogun',
      'slogan': 'Gateway State',
      'lgas': 20,
      'color': 0xFF1B5E20,
      'accent': 0xFF4CAF50,
      'icon': Icons.factory,
    },
    {
      'name': 'Oyo',
      'slogan': 'Pace Setter State',
      'lgas': 33,
      'color': 0xFF7B1C00,
      'accent': 0xFFE8A020,
      'icon': Icons.account_balance,
    },
    {
      'name': 'Osun',
      'slogan': 'State of the Living Spring',
      'lgas': 30,
      'color': 0xFF0D47A1,
      'accent': 0xFF42A5F5,
      'icon': Icons.water_drop,
    },
    {
      'name': 'Ondo',
      'slogan': 'Sunshine State',
      'lgas': 18,
      'color': 0xFF1A1A1A,
      'accent': 0xFFFF6D00,
      'icon': Icons.wb_sunny,
    },
    {
      'name': 'Ekiti',
      'slogan': 'Land of Honour',
      'lgas': 16,
      'color': 0xFF1B5E20,
      'accent': 0xFFE8A020,
      'icon': Icons.landscape,
    },
  ];

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final r = await http.get(Uri.parse('${AppConfig.baseUrl}/lga/states'));
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        final counts = <String, int>{};
        for (final s in data['states'] as List) { counts[s['state']] = s['lga_count']; }
        setState(() { _counts = counts; _loading = false; });
      } else { setState(() => _loading = false); }
    } catch (_) { setState(() => _loading = false); }
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
              const BackButton(color: Colors.white),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Government Portal', style: TextStyle(color: WPColors.green200, fontSize: 11)),
                Text('South West Nigeria', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
              ])),
              if (_loading)
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: WPColors.green200))
              else
                IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _load),
            ]),
            const SizedBox(height: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: WPColors.green700.withOpacity(0.3), borderRadius: BorderRadius.circular(10)),
              child: const Row(children: [
                Icon(Icons.lock_outlined, color: WPColors.green200, size: 14),
                SizedBox(width: 8),
                Expanded(child: Text('Authorised government officials only — 6 states, 137 LGAs',
                    style: TextStyle(color: WPColors.green200, fontSize: 12))),
              ])),
          ]),
        )),
        Expanded(child: Container(
          margin: const EdgeInsets.only(top: 14),
          decoration: const BoxDecoration(color: WPColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(children: [
            const SizedBox(height: 14),
            Expanded(child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.95),
              itemCount: _states.length,
              itemBuilder: (_, i) {
                final s = _states[i];
                final name = s['name'] as String;
                final slogan = s['slogan'] as String;
                final count = _counts[name] ?? s['lgas'] as int;
                final bgColor = Color(s['color'] as int);
                final accentColor = Color(s['accent'] as int);
                final icon = s['icon'] as IconData;
                return GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => StateDashboardScreen(state: name))),
                  child: Container(
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: bgColor.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        // State icon + badge
                        Row(children: [
                          Container(width: 44, height: 44, decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.2), borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: accentColor.withOpacity(0.5))),
                            child: Icon(icon, color: accentColor, size: 22)),
                          const Spacer(),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: accentColor.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                            child: Text('$count LGAs', style: TextStyle(color: accentColor, fontSize: 10, fontWeight: FontWeight.w600))),
                        ]),
                        const Spacer(),
                        // State name
                        Text(name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        // Official slogan
                        Text(slogan, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11, fontStyle: FontStyle.italic)),
                        const SizedBox(height: 8),
                        // Open button
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(color: accentColor.withOpacity(0.2), borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: accentColor.withOpacity(0.4))),
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.dashboard_outlined, color: accentColor, size: 14),
                            const SizedBox(width: 6),
                            Text('State Dashboard', style: TextStyle(color: accentColor, fontSize: 11, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      ]),
                    ),
                  ),
                );
              },
            )),
            const SizedBox(height: 12),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 14),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add_business, size: 18),
                label: const Text('Register Contractor Company'),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CompanyRegistrationScreen())),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46), side: const BorderSide(color: WPColors.green500)),
              )),
            const SizedBox(height: 14),
          ]),
        )),
      ]),
    );
  }
}

// ── LGA List ──────────────────────────────────────────────────────────────────
class LGAListScreen extends StatefulWidget {
  final String state;
  const LGAListScreen({super.key, required this.state});
  @override State<LGAListScreen> createState() => _LGAListScreenState();
}

class _LGAListScreenState extends State<LGAListScreen> {
  List<Map<String, String>> _lgas = [];
  List<Map<String, String>> _filtered = [];
  bool _loading = true;
  final _search = TextEditingController();

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final r = await http.get(Uri.parse('${AppConfig.baseUrl}/lga/list?state=${Uri.encodeComponent(widget.state)}'));
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        final list = (data['lgas'] as List).map((e) => {'id': e['id'].toString(), 'name': e['name'].toString(), 'state': e['state'].toString()}).toList();
        setState(() { _lgas = list; _filtered = list; _loading = false; });
      } else { setState(() => _loading = false); }
    } catch (_) { setState(() => _loading = false); }
  }

  void _filter(String q) {
    setState(() { _filtered = q.isEmpty ? _lgas : _lgas.where((l) => l['name']!.toLowerCase().contains(q.toLowerCase())).toList(); });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.state} LGAs')),
      body: Column(children: [
        Container(color: WPColors.green50, padding: const EdgeInsets.all(12),
          child: TextField(controller: _search, onChanged: _filter,
            decoration: InputDecoration(hintText: 'Search ${widget.state} LGAs...',
              prefixIcon: const Icon(Icons.search, size: 18), isDense: true, filled: true, fillColor: Colors.white))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('${_filtered.length} LGAs in ${widget.state}', style: const TextStyle(fontSize: 12, color: WPColors.textMuted)),
            if (_loading) const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: WPColors.green500)),
          ])),
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator(color: WPColors.green500))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final l = _filtered[i];
                return Container(margin: const EdgeInsets.only(bottom: 5),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFEEEEEE))),
                  child: ListTile(
                    leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: WPColors.green50, shape: BoxShape.circle),
                        child: const Icon(Icons.location_city, color: WPColors.green500, size: 18)),
                    title: Text(l['name']!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    subtitle: Text('${l['state']} State', style: const TextStyle(fontSize: 11, color: WPColors.textSecondary)),
                    trailing: const Icon(Icons.chevron_right, size: 16, color: WPColors.green500),
                    dense: true,
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => LGADashboardScreen(lgaId: l['id']!, lgaName: '${l['name']}, ${l['state']}'))),
                  ));
              })),
      ]),
    );
  }
}

// ── Company Registration ──────────────────────────────────────────────────────
class CompanyRegistrationScreen extends StatefulWidget {
  final String? preselectedState;
  const CompanyRegistrationScreen({super.key, this.preselectedState});
  @override State<CompanyRegistrationScreen> createState() => _CompanyRegistrationScreenState();
}

class _CompanyRegistrationScreenState extends State<CompanyRegistrationScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _name = TextEditingController();
  final _rc   = TextEditingController();
  final _ph   = TextEditingController();
  final _em   = TextEditingController();
  final _dir  = TextEditingController();
  final _addr = TextEditingController();
  String? _state;
  bool _busy = false;
  String? _companyId;
  String? _companyName;
  final _plate  = TextEditingController();
  final _driver = TextEditingController();
  final _drvPh  = TextEditingController();
  String _type  = '5-tonne compactor';
  double _cap   = 5.0;
  List<Map<String, String>> _trucks = [];
  bool _addBusy = false;
  final _states = ['Lagos','Ogun','Oyo','Osun','Ondo','Ekiti'];
  final _types  = ['5-tonne compactor','10-tonne tipper','3-tonne pick-up','20-tonne roll-on','Tricycle/Keke'];

  @override void initState() { super.initState(); _tabs = TabController(length: 2, vsync: this); _state = widget.preselectedState; }

  Future<void> _register() async {
    if (_name.text.isEmpty || _state == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Company name and state required'))); return;
    }
    setState(() => _busy = true);
    try {
      final r = await http.post(Uri.parse('${AppConfig.baseUrl}/contractors/company/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': _name.text, 'state': _state, 'rc_number': _rc.text,
          'contact_phone': _ph.text, 'contact_email': _em.text, 'director_name': _dir.text, 'address': _addr.text}));
      final data = jsonDecode(r.body);
      setState(() { _companyId = data['company_id']; _companyName = data['company_name']; _busy = false; });
    } catch (_) {
      setState(() { _companyId = 'offline-${DateTime.now().millisecondsSinceEpoch}'; _companyName = _name.text; _busy = false; });
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_name.text} registered!'), backgroundColor: WPColors.green500));
      _tabs.animateTo(1);
    }
  }

  Future<void> _addTruck() async {
    if (_plate.text.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plate number required'))); return; }
    setState(() => _addBusy = true);
    final sc = _state?.substring(0, 2).toUpperCase() ?? 'XX';
    final wpId = 'WP-$sc-${(_trucks.length + 1).toString().padLeft(3, '0')}';
    try {
      await http.post(Uri.parse('${AppConfig.baseUrl}/contractors/company/truck/add'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'company_id': _companyId, 'plate_number': _plate.text,
          'truck_type': _type, 'capacity_tonnes': _cap, 'driver_name': _driver.text, 'driver_phone': _drvPh.text}));
    } catch (_) {}
    setState(() {
      _trucks.add({'wastepay_id': wpId, 'plate': _plate.text, 'type': _type, 'driver': _driver.text});
      _plate.clear(); _driver.clear(); _drvPh.clear(); _addBusy = false;
    });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Truck $wpId added!'), backgroundColor: WPColors.green500));
  }

  Widget _lbl(String t) => Padding(padding: const EdgeInsets.only(bottom: 4, top: 8),
      child: Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: WPColors.textSecondary)));
  Widget _fld(TextEditingController c, String h, [TextInputType? k]) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: TextField(controller: c, keyboardType: k, decoration: InputDecoration(hintText: h, isDense: true)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register Contractor Company'),
        bottom: TabBar(controller: _tabs, tabs: const [Tab(text: 'Company Details'), Tab(text: 'Fleet & Trucks')])),
      body: TabBarView(controller: _tabs, children: [
        SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_companyId != null) Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: WPColors.green50, borderRadius: BorderRadius.circular(8), border: Border.all(color: WPColors.green200)),
            child: Row(children: [
              const Icon(Icons.check_circle, color: WPColors.green500, size: 20), const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_companyName ?? '', style: const TextStyle(fontWeight: FontWeight.w600, color: WPColors.green900)),
                const Text('Registered', style: TextStyle(fontSize: 11, color: WPColors.green700)),
              ])),
              TextButton(onPressed: () => _tabs.animateTo(1), child: const Text('Add Trucks')),
            ])),
          _lbl('Company Name *'), _fld(_name, 'e.g. Lagos Waste Solutions Ltd'),
          _lbl('State *'),
          Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(border: Border.all(color: const Color(0xFFDDDDDD)), borderRadius: BorderRadius.circular(8)),
            child: DropdownButtonHideUnderline(child: DropdownButton<String>(
              value: _state, isExpanded: true, hint: const Text('Select state'),
              items: _states.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => _state = v)))),
          _lbl('CAC RC Number'), _fld(_rc, 'RC-1234567'),
          _lbl('Director Name'), _fld(_dir, 'Full legal name'),
          _lbl('Phone'), _fld(_ph, '+234...', TextInputType.phone),
          _lbl('Email'), _fld(_em, 'user@example.invalid', TextInputType.emailAddress),
          _lbl('Address'),
          TextField(controller: _addr, maxLines: 2, decoration: const InputDecoration(hintText: 'Street, LGA, State', isDense: true)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.business, size: 18),
            label: Text(_busy ? 'Registering...' : 'Register Company'),
            onPressed: _busy ? null : _register,
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50))),
        ])),
        SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_companyId == null) Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(8), border: Border.all(color: WPColors.gold)),
            child: const Row(children: [Icon(Icons.warning_amber, color: WPColors.gold, size: 18), SizedBox(width: 8),
              Expanded(child: Text('Register the company first.', style: TextStyle(fontSize: 13)))])),
          if (_trucks.isNotEmpty) ...[
            Text('Fleet — ${_trucks.length} trucks', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ..._trucks.map((t) => Container(margin: const EdgeInsets.only(bottom: 7), padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: WPColors.green50, borderRadius: BorderRadius.circular(10), border: Border.all(color: WPColors.green200)),
              child: Row(children: [
                const Icon(Icons.local_shipping, color: WPColors.green500, size: 26),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t['wastepay_id']!, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: WPColors.green900)),
                  Text('${t['plate']} • ${t['type']}', style: const TextStyle(fontSize: 11, color: WPColors.textSecondary)),
                  if ((t['driver'] ?? '').isNotEmpty) Text('Driver: ${t['driver']}', style: const TextStyle(fontSize: 11, color: WPColors.textMuted)),
                ])),
              ]))),
            const SizedBox(height: 10),
          ],
          const Text('Add New Truck', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFEEEEEE))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _lbl('Plate Number *'), _fld(_plate, 'e.g. LSD-123-AA'),
              _lbl('Truck Type'),
              Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(border: Border.all(color: const Color(0xFFDDDDDD)), borderRadius: BorderRadius.circular(8)),
                child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                  value: _type, isExpanded: true,
                  items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (v) => setState(() => _type = v!)))),
              _lbl('Capacity'),
              Row(children: [5.0, 10.0, 20.0].map((c) => Padding(padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(onTap: () => setState(() => _cap = c),
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: _cap == c ? WPColors.green500 : WPColors.green50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _cap == c ? WPColors.green500 : WPColors.green200)),
                    child: Text('${c.toInt()}t', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: _cap == c ? Colors.white : WPColors.green700)))))).toList()),
              _lbl('Driver Name'), _fld(_driver, 'Full name'),
              _lbl('Driver Phone'), _fld(_drvPh, '+234...', TextInputType.phone),
              const SizedBox(height: 8),
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: WPColors.green50, borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  const Icon(Icons.tag, color: WPColors.green500, size: 16), const SizedBox(width: 8),
                  Expanded(child: Text('Auto WastePay ID: WP-${_state?.substring(0,2).toUpperCase() ?? 'XX'}-${(_trucks.length+1).toString().padLeft(3,'0')}',
                      style: const TextStyle(fontSize: 12, color: WPColors.green700, fontWeight: FontWeight.w500))),
                ])),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: _addBusy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.add, size: 18),
                label: Text(_addBusy ? 'Adding...' : 'Add Truck to Fleet'),
                onPressed: _addBusy ? null : _addTruck,
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(46))),
            ])),
          if (_trucks.isNotEmpty) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.check, size: 18),
              label: Text('Done — ${_trucks.length} truck${_trucks.length > 1 ? 's' : ''} registered'),
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46))),
          ],
          const SizedBox(height: 20),
        ])),
      ]),
    );
  }
}
