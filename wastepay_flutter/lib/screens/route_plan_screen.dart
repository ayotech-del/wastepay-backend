import 'package:flutter/material.dart';
import '../services/api_service.dart';

class RoutePlanScreen extends StatefulWidget {
  final String companyId;
  final Map<String, dynamic> data;
  const RoutePlanScreen(
      {super.key, required this.companyId, required this.data});
  @override
  State<RoutePlanScreen> createState() => _RoutePlanScreenState();
}

class _RoutePlanScreenState extends State<RoutePlanScreen> {
  String? _driver, _lga, _contract, _invoice, _pickup;
  List<dynamic> _bins = [];
  final Set<String> _selected = {};
  bool _busy = false;
  String? _error;
  List<dynamic> get _drivers => (widget.data['drivers'] as List)
      .where((d) => d['active'] == true)
      .toList();
  List<dynamic> get _contracts => (widget.data['contracts'] as List)
      .where((c) => c['active'] == true && c['lga_id'] == _lga)
      .toList();
  Future<void> _loadBins(String lga) async {
    setState(() {
      _lga = lga;
      _selected.clear();
      _bins = [];
      _contract = null;
      _invoice = null;
      _pickup = null;
      _busy = true;
      _error = null;
    });
    try {
      final result = await ApiService.request(
          '/organizations/companies/${widget.companyId}/bins?lga_id=${Uri.encodeQueryComponent(lga)}');
      if (mounted) setState(() => _bins = result as List);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_driver == null || _lga == null || _selected.isEmpty) {
      setState(() => _error = 'Choose a driver, LGA and at least one bin.');
      return;
    }
    final contracts = _contracts.where((c) => c['id'] == _contract).toList();
    final contract = contracts.isEmpty ? null : contracts.first;
    if (contract != null && !_selected.contains('${contract['bin_id']}')) {
      setState(() => _error = 'Select the service contract bin.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ApiService.request(
          '/organizations/companies/${widget.companyId}/routes',
          method: 'POST',
          body: {
            'driver_id': _driver,
            'lga_id': _lga,
            'stops': _selected
                .map((bin) => {
                      'bin_id': bin,
                      if (contract != null && contract['bin_id'] == bin) ...{
                        'contract_id': _contract,
                        if (_invoice != null) 'invoice_id': _invoice,
                        if (_pickup != null) 'pickup_id': _pickup,
                      }
                    })
                .toList()
          });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invoices = (widget.data['invoices'] as List)
        .where((i) => i['contract_id'] == _contract)
        .toList();
    final requests = (widget.data['pickup_requests'] as List)
        .where(
            (p) => p['contract_id'] == _contract && p['status'] == 'requested')
        .toList();
    return Scaffold(
        appBar: AppBar(title: const Text('Assign collection route')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          DropdownButtonFormField<String>(
              initialValue: _driver,
              decoration: const InputDecoration(labelText: 'Driver'),
              items: _drivers
                  .map((d) => DropdownMenuItem(
                      value: '${d['id']}',
                      child: Text('${d['name']} ? ${d['truck_number']}')))
                  .toList(),
              onChanged: _busy ? null : (v) => setState(() => _driver = v)),
          DropdownButtonFormField<String>(
              initialValue: _lga,
              decoration: const InputDecoration(labelText: 'Service LGA'),
              items: (widget.data['company']['lga_ids'] as List)
                  .map((l) => DropdownMenuItem(value: '$l', child: Text('$l')))
                  .toList(),
              onChanged: _busy
                  ? null
                  : (v) {
                      if (v != null) _loadBins(v);
                    }),
          if (_lga != null)
            DropdownButtonFormField<String>(
                key: ValueKey('contract:$_lga'),
                initialValue: _contract,
                decoration: const InputDecoration(
                    labelText: 'Consumer service (optional)'),
                items: [
                  const DropdownMenuItem<String>(
                      value: '', child: Text('Public bin collection')),
                  ..._contracts.map((c) => DropdownMenuItem(
                      value: '${c['id']}',
                      child: Text('${c['household_ref']} ? ${c['address']}')))
                ],
                onChanged: _busy
                    ? null
                    : (v) => setState(() {
                          _contract = v == '' ? null : v;
                          _invoice = null;
                          _pickup = null;
                        })),
          if (_contract != null) ...[
            DropdownButtonFormField<String>(
                key: ValueKey('invoice:$_contract'),
                initialValue: _invoice,
                decoration: const InputDecoration(
                    labelText: 'Related invoice (optional)'),
                items: invoices
                    .map((i) => DropdownMenuItem(
                        value: '${i['id']}',
                        child: Text('${i['invoice_number']} ? ${i['status']}')))
                    .toList(),
                onChanged: _busy ? null : (v) => setState(() => _invoice = v)),
            DropdownButtonFormField<String>(
                key: ValueKey('pickup:$_contract'),
                initialValue: _pickup,
                decoration: const InputDecoration(
                    labelText: 'Pickup request (optional)'),
                items: requests
                    .map((p) => DropdownMenuItem(
                        value: '${p['id']}', child: Text('${p['address']}')))
                    .toList(),
                onChanged: _busy ? null : (v) => setState(() => _pickup = v)),
          ],
          const SizedBox(height: 20),
          const Text('Bins to collect'),
          ..._bins.map((b) => CheckboxListTile(
              value: _selected.contains('${b['id']}'),
              title: Text('${b['bin_code']}'),
              subtitle: Text('${b['address']}'),
              onChanged: _busy
                  ? null
                  : (selected) => setState(() {
                        if (selected == true) {
                          _selected.add('${b['id']}');
                        } else {
                          _selected.remove('${b['id']}');
                        }
                      }))),
          FilledButton(
              onPressed: _busy ? null : _save,
              child: const Text('Assign route')),
        ]));
  }
}
