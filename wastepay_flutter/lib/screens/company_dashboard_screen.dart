import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'profile_screen.dart';
import 'business_form_screen.dart';
import 'route_plan_screen.dart';
import 'company_bank_screen.dart';

class CompanyDashboardScreen extends StatefulWidget {
  const CompanyDashboardScreen({super.key});
  @override
  State<CompanyDashboardScreen> createState() => _CompanyDashboardScreenState();
}

class _CompanyDashboardScreenState extends State<CompanyDashboardScreen> {
  List<dynamic> _companies = [];
  List<dynamic> _audit = [];
  String? _selected, _error;
  Map<String, dynamic>? _data;
  Map<String, dynamic>? _profile;
  Timer? _timer;
  bool _busy = false;
  bool get _manage => _data?['manage_allowed'] == true;
  bool _financeFor(String lga) =>
      ((_profile?['permission_lga_ids'] as Map?)?['government.finance']
                  as List? ??
              [])
          .contains(lga);
  @override
  void initState() {
    super.initState();
    _initialize();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_busy && _selected != null) _load();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiService.request('/users/me'),
        ApiService.request('/organizations/companies')
      ]);
      if (!mounted) return;
      setState(() {
        _profile = Map<String, dynamic>.from(results[0]);
        _companies = results[1] as List;
        if (!_companies.any((c) => c['id'] == _selected)) {
          _selected = _companies.isEmpty ? null : '${_companies.first['id']}';
        }
      });
      if (_selected != null) await _load();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _load() async {
    if (_selected == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiService.request('/organizations/companies/$_selected/dashboard'),
        ApiService.request('/organizations/companies/$_selected/audit')
      ]);
      if (mounted) {
        setState(() {
          _data = Map<String, dynamic>.from(results[0]);
          _audit = results[1] as List;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _form(String title, String path, Map<String, String> fields,
      {Map<String, dynamic> body = const {},
      Set<String> numbers = const {}}) async {
    final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) => BusinessFormScreen(
                title: title,
                path: path,
                fields: fields,
                extraBody: body,
                numbers: numbers)));
    if (saved == true && mounted) await _load();
  }

  Future<void> _route() async {
    final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) =>
                RoutePlanScreen(companyId: _selected!, data: _data!)));
    if (saved == true && mounted) await _load();
  }

  Future<void> _toggleDriver(Map driver) async {
    setState(() => _busy = true);
    try {
      await ApiService.request(
          '/organizations/companies/$_selected/drivers/${driver['id']}',
          method: 'PATCH',
          body: {'active': driver['active'] != true});
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reassign(Map route) async {
    final drivers =
        (_data!['drivers'] as List).where((d) => d['active'] == true).toList();
    final selected = await showDialog<String>(
        context: context,
        builder: (c) => SimpleDialog(
            title: const Text('Reassign route'),
            children: drivers
                .map((d) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(c, '${d['id']}'),
                    child: Text('${d['name']} ? ${d['truck_number']}')))
                .toList()));
    if (selected == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ApiService.request(
          '/organizations/companies/$_selected/routes/${route['id']}/driver',
          method: 'PATCH',
          body: {'driver_id': selected});
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _settle(Map route) async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('Authorize contractor settlement?'),
                content: const Text(
                    'The server calculates payment from verified weight. This authorizes payment; it does not transfer money.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Authorize'))
                ]));
    if (yes != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ApiService.request('/contractors/payment/release',
          method: 'POST', body: {'route_id': route['id']});
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar:
          AppBar(title: const Text('Company fleet & collections'), actions: [
        IconButton(
            onPressed: _busy ? null : _initialize,
            icon: const Icon(Icons.refresh)),
        IconButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ProfileScreen())),
            icon: const Icon(Icons.person))
      ]),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        if (_busy) const LinearProgressIndicator(),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.red)),
        if (_companies.isEmpty && !_busy)
          const Text('No approved companies are assigned to this account.'),
        if (_companies.isNotEmpty)
          DropdownButtonFormField<String>(
              key: ValueKey(_selected),
              initialValue: _selected,
              decoration:
                  const InputDecoration(labelText: 'Contractor company'),
              items: _companies
                  .map((c) => DropdownMenuItem(
                      value: '${c['id']}', child: Text('${c['name']}')))
                  .toList(),
              onChanged: _busy
                  ? null
                  : (v) {
                      setState(() {
                        _selected = v;
                        _data = null;
                      });
                      _load();
                    }),
        if (_data != null) ...[
          SelectableText('Company ID: $_selected'),
          if (_manage)
            FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                CompanyBankScreen(companyId: _selected!))),
                icon: const Icon(Icons.account_balance),
                label:
                    const Text('Complete onboarding: receiving bank & state')),
          if (_manage)
            Wrap(spacing: 10, runSpacing: 10, children: [
              FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _form('Add vehicle',
                              '/organizations/companies/$_selected/vehicles', {
                            'truck_number': 'Truck number',
                            'license_plate': 'License plate'
                          }),
                  child: const Text('Add vehicle')),
              FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _form('Register company driver',
                              '/organizations/companies/$_selected/drivers', {
                            'user_id': 'Registered driver user ID',
                            'vehicle_id': 'Available vehicle ID',
                            'lga_id': 'Company service LGA ID'
                          }),
                  child: const Text('Add driver')),
              FilledButton(
                  onPressed: _busy ? null : _route,
                  child: const Text('Assign route')),
              if ((_profile?['permissions'] as List? ?? [])
                  .contains('government.operations'))
                FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _form('Create consumer service',
                                '/organizations/contracts', {
                              'user_id': 'Consumer user ID',
                              'lga_id': 'LGA ID',
                              'household_ref': 'Household service reference',
                              'address': 'Collection address',
                              'bin_id': 'Registered smart bin ID'
                            },
                                body: {
                                  'company_id': _selected
                                }),
                    child: const Text('Add consumer service')),
            ]),
          const Divider(),
          Text('Drivers and latest GPS',
              style: Theme.of(context).textTheme.titleLarge),
          const Text(
              'Refreshes every 30 seconds. GPS is shown as stale after 90 seconds without a driver update.'),
          ...(_data!['drivers'] as List).map((d) => Card(
              child: ListTile(
                  title: Text('${d['name']} ? ${d['truck_number']}'),
                  subtitle: SelectableText(
                      'Driver ID: ${d['id']}\n${d['status']} | GPS: ${d['gps_stale'] == true ? 'stale or unavailable' : 'recent'}\nLast update: ${d['last_ping'] ?? 'none'}\nLocation: ${d['position'] ?? 'not available'}'),
                  trailing: _manage
                      ? TextButton(
                          onPressed:
                              _busy ? null : () => _toggleDriver(d as Map),
                          child: Text(
                              d['active'] == true ? 'Suspend' : 'Activate'))
                      : null))),
          const Divider(),
          Text('Vehicles', style: Theme.of(context).textTheme.titleLarge),
          ...(_data!['vehicles'] as List).map((v) => ListTile(
              title: Text('${v['truck_number']}'),
              subtitle: SelectableText(
                  'Vehicle ID: ${v['id']}\n${v['driver_id'] == null ? 'Available' : 'Assigned'}'))),
          const Divider(),
          Text('Pickup and payment tracking',
              style: Theme.of(context).textTheme.titleLarge),
          if ((_data!['jobs'] as List).isEmpty)
            const Text('No collection jobs assigned yet.'),
          ...(_data!['jobs'] as List).map((j) => Card(
              child: ListTile(
                  title: Text('${j['bin_code']} ? ${j['driver']}'),
                  subtitle: Text(
                      '${j['address']}\nPickup: ${j['collection_status']} | Invoice: ${j['payment_status']}\nVerified: ${j['verified_at'] ?? 'not yet'}${j['missed_reason'] == null ? '' : '\nReason: ${j['missed_reason']}'}')))),
          const Divider(),
          Text('Routes', style: Theme.of(context).textTheme.titleLarge),
          ...(_data!['routes'] as List).map((r) => Card(
                  child: Column(children: [
                ListTile(
                    title: SelectableText('Route ${r['id']}'),
                    subtitle: Text(
                        'Collection: ${r['status']} | Settlement: ${r['payment_status']}')),
                Wrap(spacing: 10, children: [
                  if (_manage && ['assigned', 'active'].contains(r['status']))
                    TextButton(
                        onPressed: _busy ? null : () => _reassign(r as Map),
                        child: const Text('Reassign driver')),
                  if (_financeFor('${r['lga_id']}') &&
                      r['status'] == 'completed' &&
                      r['payment_status'] == 'pending')
                    TextButton(
                        onPressed: _busy ? null : () => _settle(r as Map),
                        child: const Text('Authorize settlement')),
                ]),
              ]))),
          const Divider(),
          Text('Consumer service contracts',
              style: Theme.of(context).textTheme.titleLarge),
          ...(_data!['contracts'] as List).map((c) => Card(
              child: ListTile(
                  title: Text('${c['household_ref']}'),
                  subtitle: SelectableText(
                      'Contract ID: ${c['id']}\n${c['address']}'),
                  trailing: _financeFor('${c['lga_id']}')
                      ? TextButton(
                          onPressed: _busy
                              ? null
                              : () => _form('Issue service invoice',
                                      '/billing/invoice/generate', {
                                    'amount': 'Amount (NGN)',
                                    'billing_period':
                                        'Billing period, e.g. 2026-09'
                                  }, numbers: {
                                    'amount'
                                  }, body: {
                                    'lga_id': c['lga_id'],
                                    'contract_id': c['id']
                                  }),
                          child: const Text('Issue invoice'))
                      : null))),
          const Divider(),
          Text('Consumer invoice status',
              style: Theme.of(context).textTheme.titleLarge),
          ...(_data!['invoices'] as List).map((i) => ListTile(
              title: Text('${i['invoice_number']}'),
              subtitle: Text(
                  '${i['status']} | Paid NGN ${i['amount_paid']} | Balance NGN ${i['balance']}'))),
          const Divider(),
          Text('Pickup requests',
              style: Theme.of(context).textTheme.titleLarge),
          ...(_data!['pickup_requests'] as List).map((p) => ListTile(
              title: Text('${p['address']}'),
              subtitle: Text('${p['status']} ? ${p['notes'] ?? ''}'))),
          const Divider(),
          Text('Activity and consumer reports',
              style: Theme.of(context).textTheme.titleLarge),
          ..._audit.take(30).map((a) => ListTile(
              title: Text('${a['action']}'),
              subtitle: Text('${a['created_at']}\n${a['details']}'))),
        ],
      ]));
}
