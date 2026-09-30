// WastePay — App Config
// Change BACKEND_URL to your Railway domain before production build

class AppConfig {
  // ── LOCAL DEV ──────────────────────────────────────────────────────────────
  // With ADB reverse tunnel (physical device):  adb reverse tcp:8300 tcp:8300
  static const String _devUrl = 'http://10.0.2.2:8300';   // Android emulator
  // static const String _devUrl = 'http://localhost:8300'; // iOS simulator

  // ── PRODUCTION (Railway) ───────────────────────────────────────────────────
  static const String _prodUrl = 'https://wastepay-backend.up.railway.app';

  // ── TOGGLE HERE ────────────────────────────────────────────────────────────
  static const bool isProduction = false;

  static const String _configuredUrl = String.fromEnvironment('API_BASE_URL');
  static String get baseUrl => _configuredUrl.isNotEmpty
      ? _configuredUrl.replaceAll(RegExp(r'/+$'), '')
      : (isProduction ? _prodUrl : _devUrl);

  // Credit rates (NGN per kg) — mirrors backend, for offline display
  static const Map<String, double> creditRates = {
    'plastic':     400.0,
    'paper':       300.0,
    'glass':       150.0,
    'metal':       600.0,
    'organic':      80.0,
    'electronics': 1200.0,
    'mixed':       100.0,
  };

  static const Map<String, String> wasteIcons = {
    'plastic':     '♻️',
    'paper':       '📄',
    'glass':       '🫙',
    'metal':       '🔩',
    'organic':     '🍃',
    'electronics': '📱',
    'mixed':       '🗑️',
  };
}
