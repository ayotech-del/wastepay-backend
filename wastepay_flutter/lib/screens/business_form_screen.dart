import 'package:flutter/material.dart';
import '../services/api_service.dart';

class BusinessFormScreen extends StatefulWidget {
  final String title, path;
  final Map<String, String> fields;
  final Map<String, dynamic> extraBody;
  final Set<String> numbers;
  const BusinessFormScreen(
      {super.key,
      required this.title,
      required this.path,
      required this.fields,
      this.extraBody = const {},
      this.numbers = const {}});
  @override
  State<BusinessFormScreen> createState() => _BusinessFormScreenState();
}

class _BusinessFormScreenState extends State<BusinessFormScreen> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _saved;
  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final key in widget.fields.keys) key: TextEditingController()
    };
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final body = <String, dynamic>{...widget.extraBody};
      for (final entry in _controllers.entries) {
        body[entry.key] = widget.numbers.contains(entry.key)
            ? double.parse(entry.value.text)
            : entry.value.text.trim();
      }
      final result =
          await ApiService.request(widget.path, method: 'POST', body: body);
      if (mounted) setState(() => _saved = Map<String, dynamic>.from(result));
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            for (final entry in widget.fields.entries)
              Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextFormField(
                      controller: _controllers[entry.key],
                      decoration: InputDecoration(labelText: entry.value),
                      keyboardType: widget.numbers.contains(entry.key)
                          ? const TextInputType.numberWithOptions(decimal: true)
                          : TextInputType.text,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Required';
                        }
                        if (widget.numbers.contains(entry.key)) {
                          final n = double.tryParse(value);
                          if (n == null || !n.isFinite || n <= 0) {
                            return 'Enter a positive number';
                          }
                        }
                        return null;
                      })),
            FilledButton(
                onPressed: _busy || _saved != null ? null : _save,
                child: Text(_busy ? 'Saving...' : 'Save')),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            if (_saved != null) ...[
              const Text('Saved successfully.'),
              SelectableText(
                  'ID: ${_saved!['id'] ?? _saved!['invoice']?['id'] ?? ''}'),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Done'))
            ],
          ])));
}
