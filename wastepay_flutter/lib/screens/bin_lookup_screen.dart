import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'bin_scan_screen.dart';

class BinLookupScreen extends StatefulWidget {
  const BinLookupScreen({super.key});
  @override
  State<BinLookupScreen> createState() => _BinLookupScreenState();
}

class _BinLookupScreenState extends State<BinLookupScreen> {
  final _identifier = TextEditingController();
  Map<String, dynamic>? _bin;
  String? _error;
  bool _busy = false;
  @override
  void dispose() {
    _identifier.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    if (_identifier.text.trim().isEmpty) {
      setState(() => _error = 'Enter a bin code or ID');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _bin = null;
    });
    try {
      final result = await ApiService.request(
          '/bins/lookup?identifier=${Uri.encodeQueryComponent(_identifier.text.trim())}');
      if (mounted) setState(() => _bin = Map<String, dynamic>.from(result));
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scan() async {
    final code = await Navigator.push<String>(
        context, MaterialPageRoute(builder: (_) => const BinScanScreen()));
    if (code == null || !mounted) return;
    _identifier.text = code;
    await _lookup();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Find bin by code or ID')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          TextField(
              controller: _identifier,
              decoration: const InputDecoration(
                  labelText: 'Printed bin code or bin ID'),
              onSubmitted: (_) {
                if (!_busy) _lookup();
              }),
          const SizedBox(height: 16),
          Wrap(spacing: 12, children: [
            FilledButton(
                onPressed: _busy ? null : _lookup,
                child: const Text('Find bin')),
            OutlinedButton.icon(
                onPressed: _busy ? null : _scan,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan QR')),
          ]),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          if (_bin != null) ...[
            const SizedBox(height: 20),
            Text('${_bin!['bin_code']}',
                style: Theme.of(context).textTheme.titleLarge),
            Text('${_bin!['address']}'),
            SelectableText('Bin ID: ${_bin!['id']}'),
            Text('Location: ${_bin!['latitude']}, ${_bin!['longitude']}'),
            Text(
                'Status: ${_bin!['status']} | Fill: ${_bin!['fill_percent']}%'),
            FilledButton(
                onPressed: () => Navigator.pop(context, _bin),
                child: const Text('Use this bin')),
          ],
        ]),
      );
}
