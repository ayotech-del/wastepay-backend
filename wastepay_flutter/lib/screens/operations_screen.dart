import 'package:flutter/material.dart';
import '../services/api_service.dart';

class OperationsScreen extends StatefulWidget {
  const OperationsScreen({super.key});
  @override State<OperationsScreen> createState() => _OperationsScreenState();
}
class _OperationsScreenState extends State<OperationsScreen> {
  final _address = TextEditingController();
  List<dynamic> _invoices = [], _pickups = [];
  bool _busy = false;
  String? _error;
  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _address.dispose(); super.dispose(); }
  Future<void> _load() async {
    setState(() { _busy = true; _error = null; });
    try {
      final values = await Future.wait([
        ApiService.request('/billing/my-invoices'), ApiService.request('/pickups'),
      ]);
      if (!mounted) return;
      setState(() { _invoices = values[0] as List; _pickups = values[1] as List; });
    } catch (e) { if (mounted) setState(() => _error = '$e'); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _pay(Map invoice) async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Pay waste levy'),
      content: Text('Pay ₦${invoice['balance']} from your Eco Credits?'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Pay'))],
    ));
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ApiService.request('/billing/invoice/${invoice['id']}/pay', method: 'POST',
          body: {'payment_method': 'eco_credits', 'amount': invoice['balance']});
      await _load();
    } catch (e) { if (mounted) setState(() => _error = '$e'); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _requestPickup() async {
    if (_address.text.trim().length < 5) return;
    setState(() => _busy = true);
    try {
      await ApiService.request('/pickups', method: 'POST', body: {'address': _address.text.trim()});
      _address.clear(); await _load();
    } catch (e) { if (mounted) setState(() => _error = '$e'); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My bills & pickups'), actions: [
      IconButton(onPressed: _busy ? null : _load, icon: const Icon(Icons.refresh))]),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      if (_busy) const LinearProgressIndicator(),
      if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
      Text('Waste levy invoices', style: Theme.of(context).textTheme.titleLarge),
      if (_invoices.isEmpty && !_busy) const Padding(padding: EdgeInsets.all(16), child: Text('No invoices assigned to you.')),
      ..._invoices.map((invoice) => Card(child: ListTile(
        title: Text('${invoice['invoice_number']}'),
        subtitle: Text('${invoice['billing_period']} • ${invoice['status']}\nBalance: ₦${invoice['balance']}'),
        trailing: (invoice['balance'] as num) > 0 && invoice['status'] != 'cancelled'
          ? FilledButton(onPressed: _busy ? null : () => _pay(invoice as Map), child: const Text('Pay')) : null))),
      const SizedBox(height: 24),
      Text('Request pickup', style: Theme.of(context).textTheme.titleLarge),
      TextField(controller: _address, maxLength: 500, decoration: const InputDecoration(labelText: 'Collection address')),
      FilledButton(onPressed: _busy ? null : _requestPickup, child: const Text('Submit request')),
      const SizedBox(height: 20),
      ..._pickups.map((p) => ListTile(leading: const Icon(Icons.local_shipping_outlined),
        title: Text('${p['address']}'), subtitle: Text('${p['status']}'))),
    ]),
  );
}
