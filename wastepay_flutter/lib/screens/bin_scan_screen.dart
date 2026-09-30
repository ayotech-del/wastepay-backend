import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BinScanScreen extends StatefulWidget {
  const BinScanScreen({super.key});
  @override
  State<BinScanScreen> createState() => _BinScanScreenState();
}

class _BinScanScreenState extends State<BinScanScreen> {
  final _scanner = MobileScannerController();
  final _code = TextEditingController();
  bool _returned = false;
  void _return(String value) {
    if (_returned || value.trim().isEmpty) return;
    _returned = true;
    Navigator.pop(context, value.trim());
  }

  @override
  void dispose() {
    _scanner.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Scan bin QR code')),
        body: Column(children: [
          Expanded(
              child: MobileScanner(
                  controller: _scanner,
                  onDetect: (capture) {
                    if (capture.barcodes.isNotEmpty) {
                      _return(capture.barcodes.first.rawValue ?? '');
                    }
                  })),
          Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                TextField(
                    controller: _code,
                    decoration: const InputDecoration(
                        labelText: 'Or enter the printed bin code'),
                    onSubmitted: _return),
                FilledButton(
                    onPressed: () => _return(_code.text),
                    child: const Text('Use bin code')),
              ])),
        ]),
      );
}
