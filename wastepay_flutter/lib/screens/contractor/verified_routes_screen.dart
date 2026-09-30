import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/api_service.dart';
import '../profile_screen.dart';
import '../bin_scan_screen.dart';

class VerifiedRoutesScreen extends StatefulWidget {
  const VerifiedRoutesScreen({super.key});
  @override
  State<VerifiedRoutesScreen> createState() => _VerifiedRoutesScreenState();
}

class _VerifiedRoutesScreenState extends State<VerifiedRoutesScreen>
    with WidgetsBindingObserver {
  Timer? _trackingTimer;
  bool _pingBusy = false;
  String? _contractorId;
  List<dynamic> _routes = [];
  String? _message;
  bool _busy = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    _trackingTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _trackingTimer?.cancel();
      _trackingTimer = null;
      if (mounted) setState(() {});
    }
  }

  Future<void> _toggleTracking() async {
    if (_trackingTimer != null) {
      _trackingTimer?.cancel();
      setState(() => _trackingTimer = null);
      return;
    }
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Enable location services');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission is required');
      }
      final contractor = await ApiService.request('/contractors/me');
      _contractorId = contractor['id'];
      if (!mounted) return;
      _trackingTimer =
          Timer.periodic(const Duration(seconds: 30), (_) => _ping());
      setState(() {});
      await _ping();
    } catch (e) {
      if (mounted) setState(() => _message = '$e');
    }
  }

  Future<void> _ping() async {
    if (_pingBusy || _contractorId == null || _trackingTimer == null) return;
    _pingBusy = true;
    try {
      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 15));
      if (!mounted || _trackingTimer == null) return;
      await ApiService.request('/contractors/location/update',
          method: 'POST',
          body: {
            'contractor_id': _contractorId,
            'lat': position.latitude,
            'lng': position.longitude,
            'status': 'on_route',
          });
    } catch (e) {
      if (mounted) setState(() => _message = 'Location update failed: $e');
    } finally {
      _pingBusy = false;
    }
  }

  Future<void> _load() async {
    try {
      final routes = await ApiService.request('/contractors/my-routes');
      if (mounted) setState(() => _routes = routes as List);
    } catch (e) {
      if (mounted) setState(() => _message = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _updateJob(Map job, String status) async {
    String reason = '';
    if (status == 'missed') {
      final controller = TextEditingController();
      final value = await showDialog<String>(
          context: context,
          builder: (c) => AlertDialog(
                  title: const Text('Why was pickup missed?'),
                  content: TextField(controller: controller, maxLength: 1000),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () =>
                            Navigator.pop(c, controller.text.trim()),
                        child: const Text('Report'))
                  ]));
      // Dialog controllers are released after the closing animation.
      Future<void>.delayed(
          const Duration(milliseconds: 400), controller.dispose);
      if (value == null || !mounted) return;
      reason = value;
      if (reason.length < 5) {
        setState(
            () => _message = 'Enter a reason with at least five characters.');
        return;
      }
    }
    setState(() => _busy = true);
    try {
      await ApiService.request('/organizations/driver/jobs/${job['id']}',
          method: 'PATCH', body: {'status': status, 'reason': reason});
      await _load();
    } catch (e) {
      if (mounted) setState(() => _message = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _collect(Map route, String binId) async {
    final qr = await Navigator.push<String>(
        context, MaterialPageRoute(builder: (_) => const BinScanScreen()));
    if (qr == null || !mounted) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Enable device location services');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission is required to verify collection');
      }
      final p = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 20));
      if (p.accuracy > 50) {
        throw Exception('GPS accuracy is too low. Try again outdoors.');
      }
      final result = await ApiService.request('/contractors/collection/verify',
          method: 'POST',
          body: {
            'route_id': route['id'],
            'bin_id': binId,
            'qr_scan_data': qr,
            'lat': p.latitude,
            'lng': p.longitude,
            'weight_kg': 0,
          });
      if (mounted) {
        setState(() => _message =
            'Verified ${result['weight_kg']} kg from sensor readings.');
      }
      await _load();
    } catch (e) {
      if (mounted) setState(() => _message = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar:
            AppBar(title: const Text('Assigned collection routes'), actions: [
          IconButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen())),
              icon: const Icon(Icons.person)),
          IconButton(
              onPressed: _busy ? null : _load, icon: const Icon(Icons.refresh))
        ]),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          FilledButton(
              onPressed: _busy ? null : _toggleTracking,
              child: Text(_trackingTimer == null
                  ? 'Start foreground GPS tracking'
                  : 'Stop GPS tracking')),
          const Text(
              'Location sends every 30 seconds while this screen is open. Tracking stops when the app is paused.'),
          if (_busy) const LinearProgressIndicator(),
          if (_message != null)
            Padding(padding: const EdgeInsets.all(12), child: Text(_message!)),
          if (_routes.isEmpty && !_busy && _message == null)
            const Text('No assigned routes. Contact your LGA dispatcher.'),
          ..._routes.map((r) => Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Route ${r['id']}',
                            style: Theme.of(context).textTheme.titleMedium),
                        Text('${r['status']} • ${r['total_kg']} kg verified'),
                        if ((r['jobs'] as List? ?? []).isNotEmpty)
                          ...(r['jobs'] as List).map((j) => Card(
                                  child: Column(children: [
                                ListTile(
                                    title: Text('${j['bin_code']}'),
                                    subtitle: Text(
                                        '${j['address']}\n${j['collection_status']}')),
                                if (['assigned', 'active']
                                        .contains(r['status']) &&
                                    ![
                                      'collected_verified',
                                      'missed',
                                      'cancelled'
                                    ].contains(j['collection_status']))
                                  Wrap(spacing: 8, children: [
                                    if (j['collection_status'] == 'assigned')
                                      TextButton(
                                          onPressed: _busy
                                              ? null
                                              : () => _updateJob(
                                                  j as Map, 'en_route'),
                                          child: const Text('Start pickup')),
                                    TextButton(
                                        onPressed: _busy
                                            ? null
                                            : () => _collect(
                                                r as Map, '${j['bin_id']}'),
                                        child: const Text('Scan & verify')),
                                    TextButton(
                                        onPressed: _busy
                                            ? null
                                            : () =>
                                                _updateJob(j as Map, 'missed'),
                                        child: const Text('Report missed')),
                                  ]),
                              ]))),
                        if ((r['jobs'] as List? ?? []).isEmpty &&
                            (r['status'] == 'assigned' ||
                                r['status'] == 'active'))
                          ...(r['bin_ids'] as List).map((id) => ListTile(
                              title: Text('Bin $id'),
                              trailing: FilledButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _collect(r as Map, '$id'),
                                  child: const Text('Scan & verify')))),
                      ])))),
        ]),
      );
}
