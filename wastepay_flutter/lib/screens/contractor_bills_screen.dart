import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

class ContractorBillsScreen extends StatefulWidget {
  const ContractorBillsScreen({super.key});
  @override
  State<ContractorBillsScreen> createState() => _ContractorBillsScreenState();
}

class _ContractorBillsScreenState extends State<ContractorBillsScreen> {
  List<dynamic> _companies = [], _invoices = [];
  String? _selected, _state, _error, _reference;
  bool _busy = false;
  final _search = TextEditingController(), _email = TextEditingController();
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiService.request('/organizations/contractor-directory'),
        ApiService.request('/billing/my-invoices'),
        ApiService.request('/organizations/contractor-selection'),
        ApiService.request('/users/me')
      ]);
      if (!mounted) return;
      setState(() {
        _companies = results[0] as List;
        _invoices = results[1] as List;
        _selected = results[2]['company_id'] as String?;
        _email.text = results[3]['email']?.toString() ?? '';
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _choose(String id) async {
    setState(() => _busy = true);
    try {
      await ApiService.request('/organizations/contractor-selection',
          method: 'PUT', body: {'company_id': id});
      if (mounted) setState(() => _selected = id);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pay(Map invoice, String channel) async {
    if (_email.text.trim().isEmpty) {
      setState(() => _error = 'Enter your email for the payment receipt.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ApiService.request('/paystack/initialize',
          method: 'POST',
          body: {
            'purpose': 'levy_payment',
            'invoice_id': invoice['id'],
            'company_id': _selected,
            'amount': invoice['balance'],
            'channel': channel,
            'email': _email.text.trim()
          });
      if (!mounted) return;
      setState(() => _reference = result['reference'] as String);
      final url = Uri.parse(result['payment_url'] as String);
      if (url.scheme != 'https' || url.host != 'checkout.paystack.com') {
        throw Exception('Unexpected checkout address');
      }
      if (!await launchUrl(url, webOnlyWindowName: '_self')) {
        throw Exception('Could not open secure checkout');
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final states = _companies
        .expand((c) => (c['areas'] as List).map((a) => a['state'].toString()))
        .toSet()
        .toList()
      ..sort();
    final companies = _companies
        .where((c) =>
            c['name']
                .toString()
                .toLowerCase()
                .contains(_search.text.toLowerCase()) &&
            (_state == null ||
                (c['areas'] as List).any((a) => a['state'] == _state)))
        .toList();
    final invoices = _invoices
        .where((i) => i['contractor_id'] == _selected && _selected != null)
        .toList();
    final company = _companies.where((c) => c['id'] == _selected).firstOrNull;
    return Scaffold(
        appBar: AppBar(
            title: const Text('Choose contractor & pay bills'),
            actions: [
              IconButton(
                  onPressed: _busy ? null : _load,
                  icon: const Icon(Icons.refresh))
            ]),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          TextField(
              controller: _search,
              decoration:
                  const InputDecoration(labelText: 'Search contractor by name'),
              onChanged: (_) => setState(() {})),
          DropdownButtonFormField<String>(
              initialValue: _state,
              decoration: const InputDecoration(labelText: 'Filter by state'),
              items: [
                const DropdownMenuItem(value: null, child: Text('All states')),
                ...states.map((s) => DropdownMenuItem(value: s, child: Text(s)))
              ],
              onChanged: _busy ? null : (v) => setState(() => _state = v)),
          ...companies.map((c) => Card(
              child: ListTile(
                  title: Text(c['name'].toString()),
                  subtitle: Text((c['areas'] as List)
                      .map((a) => "${a['lga']}, ${a['state']}")
                      .join(' / ')),
                  trailing: TextButton(
                      onPressed:
                          _busy ? null : () => _choose(c['id'].toString()),
                      child: Text(
                          _selected == c['id'] ? 'Selected' : 'Select'))))),
          if (company != null) ...[
            const SizedBox(height: 24),
            Text("Bills for ${company['name']}",
                style: Theme.of(context).textTheme.titleLarge),
            const Text(
                'Only bills issued to your account for this contractor appear here. Selecting a contractor does not move existing bills.'),
            TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Receipt email')),
            if (invoices.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No bills for this contractor yet.')),
            ...invoices.map((i) => Card(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(i['invoice_number'].toString()),
                          Text(
                              "${i['billing_period']} | ${i['status']} | Balance: NGN ${i['balance']}"),
                          if ((i['balance'] as num) > 0 &&
                              i['status'] != 'cancelled')
                            Wrap(spacing: 8, children: [
                              FilledButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _pay(i as Map, 'bank_transfer'),
                                  child: const Text('Bank transfer')),
                              OutlinedButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _pay(i as Map, 'card'),
                                  child: const Text('Debit card'))
                            ])
                        ])))),
            const Text(
                'Payment is confirmed by the provider. Refresh bills after checkout.'),
            if (_reference != null)
              SelectableText('Payment reference: $_reference'),
          ],
        ]));
  }
}
