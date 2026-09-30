// WastePay — Bin Locator Screen (list + map placeholder)
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'bin_lookup_screen.dart';

class BinLocatorScreen extends StatefulWidget {
  const BinLocatorScreen({super.key});
  @override State<BinLocatorScreen> createState() => _BinLocatorScreenState();
}

class _BinLocatorScreenState extends State<BinLocatorScreen> {
  List<SmartBinInfo> _bins = [];
  bool _loading = true;
  String? _error;
  String _filter = 'all'; // all | available | full

  @override
  void initState() {
    super.initState();
    _loadBins();
  }

  Future<void> _loadBins() async {
    setState(() => _loading = true);
    // Default to Lagos coordinates; in production use GPS from geolocator package
    try {
      final bins = await ApiService.getNearbyBins(lat: 6.4550, lng: 3.3841, radiusKm: 10.0);
      if (mounted) setState(() { _bins = bins; _error = null; });
    } catch (e) { if (mounted) setState(() => _error = '$e'); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  List<SmartBinInfo> get _filtered {
    switch (_filter) {
      case 'available': return _bins.where((b) => !b.isFull).toList();
      case 'full':      return _bins.where((b) => b.isFull).toList();
      default:          return _bins;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Smart Bins'),
        leading: const BackButton(),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_outlined), onPressed: _loadBins),
        ],
      ),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: OutlinedButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BinLookupScreen())),
          icon: const Icon(Icons.qr_code_scanner), label: const Text('Find bin by code / Scan QR'))),
        if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
        // Stats bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: WPColors.green50,
          child: Row(children: [
            _StatChip('${_bins.length}', 'Total bins', WPColors.green500),
            const SizedBox(width: 8),
            _StatChip('${_bins.where((b) => !b.isFull).length}', 'Available', WPColors.green700),
            const SizedBox(width: 8),
            _StatChip('${_bins.where((b) => b.isFull).length}', 'Full', WPColors.terracotta),
          ]),
        ),

        // Filter chips
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(children: [
            _FilterChip('All', 'all', _filter, (v) => setState(() => _filter = v)),
            const SizedBox(width: 8),
            _FilterChip('Available', 'available', _filter, (v) => setState(() => _filter = v)),
            const SizedBox(width: 8),
            _FilterChip('Full', 'full', _filter, (v) => setState(() => _filter = v)),
          ]),
        ),

        // Bin list
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: WPColors.green500))
              : _filtered.isEmpty
                  ? const Center(child: Text('No bins found', style: TextStyle(color: WPColors.textMuted)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) => _BinCard(bin: _filtered[i]),
                    ),
        ),
      ]),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String count, label; final Color color;
  const _StatChip(this.count, this.label, this.color);
  @override Widget build(BuildContext context) => Row(children: [
    Text(count, style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 15)),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(color: WPColors.textSecondary, fontSize: 12)),
  ]);
}

class _FilterChip extends StatelessWidget {
  final String label, value, current; final ValueChanged<String> onSelect;
  const _FilterChip(this.label, this.value, this.current, this.onSelect);
  @override Widget build(BuildContext context) {
    final selected = value == current;
    return GestureDetector(
      onTap: () => onSelect(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? WPColors.green500 : WPColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? WPColors.green500 : const Color(0xFFDDDDDD)),
        ),
        child: Text(label, style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w500,
            color: selected ? Colors.white : WPColors.textSecondary)),
      ),
    );
  }
}

class _BinCard extends StatelessWidget {
  final SmartBinInfo bin;
  const _BinCard({required this.bin});

  Color get _fillColor {
    if (bin.fillPercent >= 85) return WPColors.terracotta;
    if (bin.fillPercent >= 50) return WPColors.gold;
    return WPColors.green500;
  }

  @override Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(bin.fillIcon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(bin.code, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            Text(bin.address, style: const TextStyle(color: WPColors.textSecondary, fontSize: 12)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: bin.isFull ? const Color(0xFFFFEBEE) : WPColors.green50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(bin.isFull ? 'FULL' : 'AVAILABLE',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                    color: bin.isFull ? WPColors.terracotta : WPColors.green700)),
          ),
        ]),
        const SizedBox(height: 10),
        // Fill bar
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Fill level', style: TextStyle(fontSize: 11, color: WPColors.textMuted)),
            Text('${bin.fillPercent}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _fillColor)),
          ]),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: bin.fillPercent / 100,
              backgroundColor: const Color(0xFFEEEEEE),
              valueColor: AlwaysStoppedAnimation<Color>(_fillColor),
              minHeight: 6,
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            icon: const Icon(Icons.directions_outlined, size: 16),
            label: const Text('Directions', style: TextStyle(fontSize: 12)),
            onPressed: () {/* TODO: launch maps URL */},
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 8),
              foregroundColor: WPColors.green500,
              side: const BorderSide(color: WPColors.green500),
            ),
          )),
          const SizedBox(width: 8),
          Expanded(child: ElevatedButton.icon(
            icon: const Icon(Icons.qr_code_scanner, size: 16),
            label: const Text('Scan & Deposit', style: TextStyle(fontSize: 12)),
            onPressed: bin.isFull ? null : () {
              Navigator.of(context).pop(); // return to home to open deposit
            },
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)),
          )),
        ]),
      ]),
    );
  }
}
