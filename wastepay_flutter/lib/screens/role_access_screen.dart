import 'package:flutter/material.dart';
import '../services/api_service.dart';

class RoleAccessScreen extends StatefulWidget {
  const RoleAccessScreen({super.key});
  @override
  State<RoleAccessScreen> createState() => _RoleAccessScreenState();
}

class _RoleAccessScreenState extends State<RoleAccessScreen> {
  final _user = TextEditingController();
  final _scopeValue = TextEditingController();
  String _role = 'government_supervisor', _scope = 'lga';
  List<dynamic> _grants = [];
  bool _busy = false;
  String? _error;
  static const _roles = [
    'government_supervisor',
    'government_operations',
    'government_finance',
    'lga_admin',
    'contractor_manager',
    'platform_admin'
  ];
  List<String> get _scopes => _role == 'platform_admin'
      ? ['national']
      : _role == 'contractor_manager'
          ? ['company']
          : _role == 'lga_admin'
              ? ['lga']
              : ['lga', 'state', 'national'];
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _user.dispose();
    _scopeValue.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ApiService.request('/access/grants');
      if (mounted) setState(() => _grants = result as List);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_user.text.trim().isEmpty ||
        (_scope != 'national' && _scopeValue.text.trim().isEmpty)) {
      setState(() => _error = 'Enter the registered user ID and access scope.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ApiService.request('/access/grants', method: 'POST', body: {
        'user_id': _user.text.trim(),
        'role': _role,
        'scope_kind': _scope,
        'scope_value': _scope == 'national' ? null : _scopeValue.text.trim(),
      });
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggle(Map grant) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: Text(grant['active'] == true
                    ? 'Revoke this access?'
                    : 'Activate this access?'),
                content: Text('${grant['role']} for user ${grant['user_id']}'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Confirm'))
                ]));
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ApiService.request(
          '/access/grants/${Uri.encodeComponent('${grant['id']}')}',
          method: 'PATCH',
          body: {'active': grant['active'] != true});
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Manage user roles')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          const Text(
              'Give each account only the access it needs. Changes apply to subsequent requests immediately.'),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          TextField(
              controller: _user,
              decoration:
                  const InputDecoration(labelText: 'Registered user ID')),
          DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Role'),
              items: _roles
                  .map((r) => DropdownMenuItem(
                      value: r, child: Text(r.replaceAll('_', ' '))))
                  .toList(),
              onChanged: _busy
                  ? null
                  : (value) {
                      setState(() {
                        _role = value!;
                        _scope = _scopes.first;
                      });
                    }),
          DropdownButtonFormField<String>(
              key: ValueKey(_role),
              initialValue: _scope,
              decoration: const InputDecoration(labelText: 'Access scope'),
              items: _scopes
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged:
                  _busy ? null : (value) => setState(() => _scope = value!)),
          if (_scope != 'national')
            TextField(
                controller: _scopeValue,
                decoration: InputDecoration(
                    labelText: _scope == 'state'
                        ? 'State name'
                        : _scope == 'company'
                            ? 'Company ID'
                            : 'LGA ID')),
          FilledButton(
              onPressed: _busy ? null : _save,
              child: const Text('Grant access')),
          const Divider(),
          ..._grants.map((g) => Card(
              child: ListTile(
                  title: Text(
                      '${g['role']} ? ${g['active'] == true ? 'active' : 'revoked'}'),
                  subtitle: SelectableText(
                      'User: ${g['user_id']}\nScope: ${g['scope_kind']} ${g['scope_value'] ?? ''}'),
                  trailing: TextButton(
                      onPressed: _busy ? null : () => _toggle(g as Map),
                      child:
                          Text(g['active'] == true ? 'Revoke' : 'Activate'))))),
        ]),
      );
}
