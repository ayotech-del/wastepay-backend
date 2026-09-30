import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'contractor_bills_screen.dart';

class OperationsScreen extends StatefulWidget {
  const OperationsScreen({super.key});
  @override
  State<OperationsScreen> createState() => _OperationsScreenState();
}

class _OperationsScreenState extends State<OperationsScreen> {
  final _address = TextEditingController();
  List<dynamic> _invoices = [], _pickups = [], _contracts = [], _jobs = [];
  String? _contract;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final values = await Future.wait([
        ApiService.request('/billing/my-invoices'),
        ApiService.request('/pickups'),
        ApiService.request('/organizations/contracts/mine'),
        ApiService.request('/organizations/jobs/mine'),
      ]);
      if (!mounted) return;
      setState(() {
        _invoices = values[0] as List;
        _pickups = values[1] as List;
        _contracts = values[2] as List;
        _jobs = values[3] as List;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestPickup() async {
    if (_address.text.trim().length < 5) return;
    setState(() => _busy = true);
    try {
      await ApiService.request('/pickups', method: 'POST', body: {
        'address': _address.text.trim(),
        if (_contract != null) 'contract_id': _contract
      });
      _address.clear();
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _report(Map job) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('Report missed pickup'),
                content: TextField(controller: controller, maxLength: 1000),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, controller.text.trim()),
                      child: const Text('Send report'))
                ]));
    Future<void>.delayed(const Duration(milliseconds: 400), controller.dispose);
    if (reason == null || !mounted) return;
    if (reason.length < 5) {
      setState(() => _error = 'Enter a reason with at least five characters.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ApiService.request('/organizations/jobs/${job['id']}/report',
          method: 'POST', body: {'reason': reason});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Report sent to your company and government staff.')));
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('My bills & pickups'), actions: [
          IconButton(
              onPressed: _busy ? null : _load, icon: const Icon(Icons.refresh))
        ]),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          FilledButton(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ContractorBillsScreen())),
              child: const Text('Select contractor & pay bills')),
          Text('Waste levy invoices',
              style: Theme.of(context).textTheme.titleLarge),
          if (_invoices.isEmpty && !_busy)
            const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No invoices assigned to you.')),
          ..._invoices.map((invoice) => Card(
                  child: ListTile(
                title: Text('${invoice['invoice_number']}'),
                subtitle: Text(
                    '${invoice['contractor_name'] ?? 'Government levy'}\n${invoice['billing_period']} • ${invoice['status']}\nBalance: ₦${invoice['balance']}'),
              ))),
          const SizedBox(height: 24),
          Text('Request pickup', style: Theme.of(context).textTheme.titleLarge),
          if (_contracts.isNotEmpty)
            DropdownButtonFormField<String>(
                initialValue: _contract,
                decoration: const InputDecoration(
                    labelText: 'My waste service company'),
                items: _contracts
                    .map((c) => DropdownMenuItem(
                        value: '${c['id']}',
                        child: Text('${c['company']} ? ${c['household_ref']}')))
                    .toList(),
                onChanged: _busy
                    ? null
                    : (v) {
                        setState(() {
                          _contract = v;
                          final selected =
                              _contracts.firstWhere((c) => c['id'] == v);
                          _address.text = '${selected['address']}';
                        });
                      }),
          TextField(
              controller: _address,
              maxLength: 500,
              decoration:
                  const InputDecoration(labelText: 'Collection address')),
          FilledButton(
              onPressed: _busy ? null : _requestPickup,
              child: const Text('Submit request')),
          const SizedBox(height: 20),
          Text('My collection status',
              style: Theme.of(context).textTheme.titleLarge),
          ..._jobs.map((j) => Card(
              child: ListTile(
                  title: Text('${j['bin_code']} ? ${j['driver']}'),
                  subtitle: Text(
                      'Pickup: ${j['collection_status']} | Bill: ${j['payment_status']}\n${j['address']}'),
                  trailing: TextButton(
                      onPressed: _busy ? null : () => _report(j as Map),
                      child: const Text('Report missed pickup'))))),
          const SizedBox(height: 20),
          ..._pickups.map((p) => ListTile(
              leading: const Icon(Icons.local_shipping_outlined),
              title: Text('${p['address']}'),
              subtitle: Text('${p['status']}'))),
        ]),
      );
}
