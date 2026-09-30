import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CompanyBankScreen extends StatefulWidget {
  final String companyId;
  const CompanyBankScreen({super.key, required this.companyId});
  @override
  State<CompanyBankScreen> createState() => _CompanyBankScreenState();
}

class _CompanyBankScreenState extends State<CompanyBankScreen> {
  final _account = TextEditingController();
  List<dynamic> _banks = [];
  List<String> _states = [];
  String? _bank, _state, _error;
  Map? _profile;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _account.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final results = await Future.wait([
        ApiService.request(
            '/organizations/companies/${widget.companyId}/bank-profile'),
        ApiService.request('/organizations/contractor-directory')
      ]);
      if (!mounted) return;
      final companies = results[1] as List;
      final company = companies.firstWhere((c) => c['id'] == widget.companyId);
      setState(() {
        _profile = results[0] as Map;
        _states = (company['areas'] as List)
            .map((a) => a['state'].toString())
            .toSet()
            .toList();
        _state = _states.firstOrNull;
      });
      final banks = await ApiService.request('/paystack/banks');
      if (mounted) setState(() => _banks = banks['banks'] as List);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_bank == null ||
        _state == null ||
        !RegExp(r'^\d{10}$').hasMatch(_account.text.trim())) {
      setState(() =>
          _error = 'Choose your state, bank and a 10-digit account number.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ApiService.request(
          '/organizations/companies/${widget.companyId}/bank-profile',
          method: 'PUT',
          body: {
            'state': _state,
            'bank_code': _bank,
            'account_number': _account.text.trim()
          });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Receiving account verified and saved.')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Contractor bank setup')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        if (_busy) const LinearProgressIndicator(),
        const Text(
            'Set up the bank account that receives customer invoice payments. The payment provider verifies the account holder before saving.'),
        if (_profile?['configured'] == true)
          Text(
              "Current account: ${_profile!['bank_name']} / ${_profile!['account_name']} / ${_profile!['account_number']}"),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.red)),
        DropdownButtonFormField<String>(
            initialValue: _state,
            decoration: const InputDecoration(labelText: 'Service state'),
            items: _states
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: _busy ? null : (v) => setState(() => _state = v)),
        DropdownButtonFormField<String>(
            initialValue: _bank,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Receiving bank'),
            items: _banks
                .map((b) => DropdownMenuItem(
                    value: b['code'].toString(),
                    child: Text(b['name'].toString())))
                .toList(),
            onChanged: _busy ? null : (v) => setState(() => _bank = v)),
        TextField(
            controller: _account,
            maxLength: 10,
            keyboardType: TextInputType.number,
            decoration:
                const InputDecoration(labelText: 'Receiving account number')),
        FilledButton(
            onPressed: _busy ? null : _save,
            child: const Text('Verify & save receiving bank')),
      ]));
}
