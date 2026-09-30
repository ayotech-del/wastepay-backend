import 'package:flutter/material.dart';
import '../services/api_service.dart';

class GovernmentScreen extends StatefulWidget {
  const GovernmentScreen({super.key});
  @override State<GovernmentScreen> createState() => _GovernmentScreenState();
}
class _GovernmentScreenState extends State<GovernmentScreen> {
  final _lga = TextEditingController();
  Map<String, dynamic>? _data;
  String? _error;
  bool _busy = false;
  @override void dispose() { _lga.dispose(); super.dispose(); }
  Future<void> _load() async {
    if (_lga.text.trim().isEmpty) return;
    setState(() { _busy = true; _error = null; _data = null; });
    try {
      final result = await ApiService.request('/government/dashboard/${Uri.encodeComponent(_lga.text.trim())}');
      if (mounted) setState(() => _data = Map<String, dynamic>.from(result));
    } catch (e) { if (mounted) setState(() => _error = '$e'); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Government overview')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Sign in with your provisioned government account. Access is limited to your assigned LGA.'),
      TextField(controller: _lga, decoration: const InputDecoration(labelText: 'LGA ID')),
      FilledButton(onPressed: _busy ? null : _load, child: const Text('Load overview')),
      if (_busy) const LinearProgressIndicator(),
      if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
      if (_data != null) ...[
        ListTile(title: const Text('Total billed'), trailing: Text('₦${_data!['billing']['total_billed']}')),
        ListTile(title: const Text('Total collected'), trailing: Text('₦${_data!['billing']['total_collected']}')),
        ListTile(title: const Text('Collection rate'), trailing: Text('${_data!['billing']['collection_rate']}%')),
        ListTile(title: const Text('Verified waste collected'), trailing: Text('${_data!['performance']['total_kg_collected']} kg')),
        ListTile(title: const Text('Active contractors'), trailing: Text('${_data!['live']['active_contractors']}')),
        const Divider(), const Text('Bins requiring collection'),
        ...(_data!['alerts'] as List).map((b) => ListTile(title: Text('${b['bin_code']}'), subtitle: Text('${b['address']}'), trailing: Text('${b['fill_percent']}%'))),
      ],
    ]),
  );
}
