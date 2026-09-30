import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'government_registration_screen.dart';

class GovernmentScreen extends StatefulWidget {
  final bool registerContractor;
  const GovernmentScreen({super.key, this.registerContractor = false});
  @override
  State<GovernmentScreen> createState() => _GovernmentScreenState();
}

class _GovernmentScreenState extends State<GovernmentScreen> {
  List<dynamic> _lgas = [];
  String? _selected;
  Map<String, dynamic>? _data;
  String? _error;
  bool _busy = true;
  bool _admin = false;
  bool _platformAdmin = false;
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final profile = await ApiService.request('/users/me');
      final platform = profile['role'] == 'platform_admin';
      if (!platform && profile['role'] != 'lga_admin') {
        throw ApiException(
            'This account has no government access. A system operator must assign your government role and LGA.');
      }
      final result = await ApiService.request('/government/my-lgas');
      if (!mounted) return;
      final lgas = result['lgas'] as List;
      setState(() {
        _admin = true;
        _platformAdmin = platform;
        _lgas = lgas;
        if (!lgas.any((l) => l['id'] == _selected)) {
          _selected = lgas.isEmpty ? null : '${lgas.first['id']}';
        }
      });
      await _load();
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
      _data = null;
    });
    try {
      final result = await ApiService.request(
          '/government/dashboard/${Uri.encodeComponent(_selected!)}');
      if (mounted) setState(() => _data = Map<String, dynamic>.from(result));
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _register(String kind) async {
    final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) => GovernmentRegistrationScreen(
                kind: kind, lgaId: kind == 'lga' ? null : _selected)));
    if (saved == true && mounted) await _initialize();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(widget.registerContractor
                ? 'Contractor registration'
                : 'Government dashboard'),
            actions: [
              IconButton(
                  onPressed: _busy ? null : _initialize,
                  icon: const Icon(Icons.refresh))
            ]),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          if (_admin) ...[
            if (_lgas.isEmpty)
              const Text('No LGAs are registered or assigned to this account.'),
            if (_lgas.isNotEmpty)
              DropdownButtonFormField<String>(
                  key: ValueKey(_selected),
                  initialValue: _selected,
                  decoration:
                      const InputDecoration(labelText: 'Local government area'),
                  items: _lgas
                      .map((l) => DropdownMenuItem(
                          value: '${l['id']}',
                          child: Text('${l['name']}, ${l['state']}')))
                      .toList(),
                  onChanged: _busy
                      ? null
                      : (value) {
                          setState(() => _selected = value);
                          _load();
                        }),
            const SizedBox(height: 16),
            Wrap(spacing: 12, runSpacing: 12, children: [
              if (_platformAdmin)
                OutlinedButton(
                    onPressed: _busy ? null : () => _register('lga'),
                    child: const Text('Add LGA')),
              FilledButton(
                  onPressed: _busy || _selected == null
                      ? null
                      : () => _register('bin'),
                  child: const Text('Add smart bin')),
              FilledButton(
                  onPressed: _busy || _selected == null
                      ? null
                      : () => _register('contractor'),
                  child: const Text('Register contractor')),
            ]),
          ],
          if (_data != null) ...[
            ListTile(
                title: const Text('Total billed'),
                trailing: Text('NGN ${_data!['billing']['total_billed']}')),
            ListTile(
                title: const Text('Total collected'),
                trailing: Text('NGN ${_data!['billing']['total_collected']}')),
            ListTile(
                title: const Text('Collection rate'),
                trailing: Text('${_data!['billing']['collection_rate']}%')),
            ListTile(
                title: const Text('Verified waste collected'),
                trailing:
                    Text('${_data!['performance']['total_kg_collected']} kg')),
            ListTile(
                title: const Text('Active contractors'),
                trailing: Text('${_data!['live']['active_contractors']}')),
            ListTile(
                title: const Text('Registered bins'),
                trailing: Text('${_data!['bins']}')),
            const Divider(),
            const Text('Bins requiring collection'),
            if ((_data!['alerts'] as List).isEmpty)
              const Text('No bins are at the collection threshold.'),
            ...(_data!['alerts'] as List).map((b) => ListTile(
                title: Text('${b['bin_code']}'),
                subtitle: Text('${b['address']}'),
                trailing: Text('${b['fill_percent']}%'))),
          ],
        ]),
      );
}
