import 'package:flutter/material.dart';
import '../services/api_service.dart';

class GovernmentRegistrationScreen extends StatefulWidget {
  final String kind;
  final String? lgaId;
  const GovernmentRegistrationScreen(
      {super.key, required this.kind, this.lgaId});
  @override
  State<GovernmentRegistrationScreen> createState() => _RegistrationState();
}

class _RegistrationState extends State<GovernmentRegistrationScreen> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _fields;
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _saved;
  Map<String, String> get _labels => switch (widget.kind) {
        'bin' => {
            'bin_code': 'Printed bin code (QR content)',
            'address': 'Bin address',
            'latitude': 'Latitude',
            'longitude': 'Longitude'
          },
        'contractor' => {
            'user_id': 'Registered driver user ID',
            'truck_number': 'Truck number',
            'license_plate': 'License plate'
          },
        _ => {'name': 'LGA name', 'state': 'State'},
      };
  String get _title => switch (widget.kind) {
        'bin' => 'Add smart bin',
        'contractor' => 'Register contractor',
        _ => 'Add LGA',
      };
  @override
  void initState() {
    super.initState();
    _fields = {for (final key in _labels.keys) key: TextEditingController()};
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _saved = null;
    });
    try {
      final body = <String, dynamic>{
        for (final entry in _fields.entries)
          if (entry.value.text.trim().isNotEmpty)
            entry.key: entry.value.text.trim()
      };
      if (widget.lgaId != null) body['lga_id'] = widget.lgaId;
      if (widget.kind == 'bin') {
        body['latitude'] = double.parse(_fields['latitude']!.text);
        body['longitude'] = double.parse(_fields['longitude']!.text);
      }
      final path = switch (widget.kind) {
        'bin' => '/bins',
        'contractor' => '/contractors/register',
        _ => '/government/lgas',
      };
      final result = await ApiService.request(path, method: 'POST', body: body);
      if (mounted) setState(() => _saved = Map<String, dynamic>.from(result));
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(_title)),
        body: Form(
            key: _form,
            child: ListView(padding: const EdgeInsets.all(20), children: [
              if (widget.kind == 'contractor')
                const Text(
                    'The driver must first register a normal account. Copy their user ID from My Profile. Government staff register the truck here.'),
              if (widget.kind == 'bin')
                const Text(
                    'Save the physical bin location. Its QR label must contain exactly the printed bin code entered here.'),
              if (widget.kind == 'lga')
                const Text('Only a platform administrator can add an LGA.'),
              for (final entry in _labels.entries)
                Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: TextFormField(
                        controller: _fields[entry.key],
                        keyboardType:
                            ['latitude', 'longitude'].contains(entry.key)
                                ? const TextInputType.numberWithOptions(
                                    decimal: true, signed: true)
                                : TextInputType.text,
                        decoration: InputDecoration(labelText: entry.value),
                        validator: (value) {
                          if (entry.key == 'license_plate') return null;
                          if (value == null || value.trim().isEmpty) {
                            return 'Required';
                          }
                          if (['latitude', 'longitude'].contains(entry.key)) {
                            final number = double.tryParse(value);
                            final limit = entry.key == 'latitude' ? 90 : 180;
                            if (number == null ||
                                !number.isFinite ||
                                number.abs() > limit) {
                              return 'Enter a value between -$limit and $limit';
                            }
                          }
                          if (entry.key == 'bin_code' &&
                              value.trim().length > 20) {
                            return 'Use at most 20 characters';
                          }
                          if (entry.key == 'address' && value.trim().length < 5) {
                            return 'Enter a complete address';
                          }
                          return null;
                        })),
              const SizedBox(height: 20),
              FilledButton(
                  onPressed: _busy ? null : _save,
                  child: Text(_busy ? 'Saving...' : 'Save')),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
              if (_saved != null) ...[
                const Text('Saved successfully.'),
                SelectableText(widget.kind == 'bin'
                    ? 'Printed code: ${_saved!['bin_code']}\nBin ID: ${_saved!['id']}\nAddress: ${_saved!['address']}'
                    : 'ID: ${_saved!['contractor_id'] ?? _saved!['id']}'),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Done')),
              ],
            ])),
      );
}
