// WastePay — Complete API Service wired to FastAPI backend
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/config.dart';
import '../models/models.dart';

class ApiService {
  static const _storage = FlutterSecureStorage();
  static http.Client _client = http.Client();

  @visibleForTesting
  static void setHttpClientForTesting(http.Client client) => _client = client;
  static String get _base => AppConfig.baseUrl;

  static Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.read(key: 'access_token');
    return {'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'};
  }

  static Future<void> _saveTokens(Map<String, dynamic> data) async {
    await _storage.write(key: 'access_token',  value: data['access_token']);
    await _storage.write(key: 'refresh_token', value: data['refresh_token']);
    await _storage.write(key: 'user_id',       value: data['user_id']);
    await _storage.write(key: 'full_name',     value: data['full_name']);
    await _storage.write(key: 'kyc_tier',      value: data['kyc_tier']);
  }

  static Future<bool> isLoggedIn() async => (await _storage.read(key: 'access_token')) != null;
  static Future<String?> getStoredName() => _storage.read(key: 'full_name');
  static Future<String?> getStoredKYC()  => _storage.read(key: 'kyc_tier');
  static Future<void> logout() async => await _storage.deleteAll();

  static Future<bool> refreshToken() async {
    final refresh = await _storage.read(key: 'refresh_token');
    if (refresh == null) return false;
    final resp = await _client.post(Uri.parse('$_base/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refresh}));
    if (resp.statusCode == 200) { await _saveTokens(jsonDecode(resp.body)); return true; }
    return false;
  }

  static Future<http.Response> _req(Future<http.Response> Function() call) async {
    var r = await call().timeout(const Duration(seconds: 25));
    if (r.statusCode == 401 && await refreshToken()) {
      // Earlier callers capture the old header map; replay using freshly stored tokens.
      final request = r.request;
      if (request is http.Request) {
        final retry = http.Request(request.method, request.url)
          ..headers.addAll(await _authHeaders())
          ..bodyBytes = request.bodyBytes;
        r = await http.Response.fromStream(await _client.send(retry)
            .timeout(const Duration(seconds: 25)));
      }
    }
    return r;
  }

  static Future<dynamic> request(String path, {String method = 'GET',
      Map<String, dynamic>? body}) async {
    Future<http.Response> call() async {
      final req = http.Request(method, Uri.parse('$_base$path'))
        ..headers.addAll(await _authHeaders());
      if (body != null) req.body = jsonEncode(body);
      return http.Response.fromStream(await _client.send(req));
    }
    final response = await _req(call);
    dynamic data;
    try { data = jsonDecode(response.body); }
    catch (_) { throw ApiException('Server returned an invalid response'); }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(data is Map ? '${data['detail'] ?? 'Request failed'}' : 'Request failed');
    }
    return data;
  }

  // AUTH
  static Future<AuthResult> register({required String phone, required String fullName, required String password, String? email}) async {
    final resp = await _client.post(Uri.parse('$_base/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone, 'full_name': fullName, 'password': password, if (email != null && email.isNotEmpty) 'email': email}));
    final data = jsonDecode(resp.body);
    if (resp.statusCode == 201) { await _saveTokens(data); return AuthResult.success(data); }
    return AuthResult.error(data['detail'] ?? 'Registration failed');
  }

  static Future<AuthResult> login({required String phone, required String password}) async {
    final resp = await _client.post(Uri.parse('$_base/auth/login'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'username=${Uri.encodeComponent(phone)}&password=${Uri.encodeComponent(password)}');
    final data = jsonDecode(resp.body);
    if (resp.statusCode == 200) { await _saveTokens(data); return AuthResult.success(data); }
    return AuthResult.error(data['detail'] ?? 'Login failed');
  }

  // WALLET
  static Future<WalletBalance> getBalance() async {
    final h = await _authHeaders();
    final r = await _req(() => _client.get(Uri.parse('$_base/wallet/balance'), headers: h));
    if (r.statusCode == 200) return WalletBalance.fromJson(jsonDecode(r.body));
    throw ApiException('Balance load failed: ${r.statusCode}');
  }

  static Future<List<WalletTransaction>> getTransactions({int skip = 0, int limit = 20}) async {
    final h = await _authHeaders();
    final r = await _req(() => _client.get(Uri.parse('$_base/wallet/transactions?skip=$skip&limit=$limit'), headers: h));
    if (r.statusCode == 200) return (jsonDecode(r.body) as List).map((e) => WalletTransaction.fromJson(e)).toList();
    throw ApiException('Transactions load failed');
  }

  static Future<RedeemResult> redeemCredits({required double amount, required String billerCode, required String customerRef, String? description}) async {
    final h = await _authHeaders();
    final r = await _req(() => _client.post(Uri.parse('$_base/wallet/redeem'), headers: h,
        body: jsonEncode({'amount': amount, 'biller_code': billerCode, 'customer_ref': customerRef, if (description != null) 'description': description})));
    final data = jsonDecode(r.body);
    if (r.statusCode == 200) return RedeemResult.success(data);
    return RedeemResult.error(data['detail'] ?? 'Redemption failed');
  }

  // DEPOSITS
  static Future<DepositResult> submitDeposit({required String wasteType, required double weightKg, String? binId, String? qrScanData}) async {
    final h = await _authHeaders();
    final r = await _req(() => _client.post(Uri.parse('$_base/waste/deposit'), headers: h,
        body: jsonEncode({'waste_type': wasteType, 'weight_kg': weightKg, if (binId != null) 'bin_id': binId, if (qrScanData != null) 'qr_scan_data': qrScanData})));
    final data = jsonDecode(r.body);
    if (r.statusCode == 200 && data['credit_value'] != null) return DepositResult.success(data);
    return DepositResult.error(data['detail'] ?? 'Deposit failed');
  }

  static Future<Map<String, double>> getCreditRates() async {
    final r = await _client.get(Uri.parse('$_base/waste/rates'));
    if (r.statusCode == 200) {
      final data = jsonDecode(r.body);
      return Map<String, double>.from((data['rates_ngn_per_kg'] as Map).map((k, v) => MapEntry(k, (v as num).toDouble())));
    }
    return AppConfig.creditRates;
  }

  // BINS
  static Future<List<SmartBinInfo>> getNearbyBins({required double lat, required double lng, double radiusKm = 3.0}) async {
    final data = await request('/bins/nearby?lat=$lat&lng=$lng&radius_km=$radiusKm');
    return (data as List).map((e) => SmartBinInfo.fromJson(Map<String,dynamic>.from(e))).toList();
  }

  static Future<bool> ping() async {
    try { return (await _client.get(Uri.parse('$_base/health')).timeout(const Duration(seconds: 5))).statusCode == 200; }
    catch (_) { return false; }
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override String toString() => message;
}

// ── BILLING ───────────────────────────────────────────────────────────────────
extension BillingApi on ApiService {
  static Future<Map<String, dynamic>> getBillingStats(String lgaId) async {
    final h = await ApiService._authHeaders();
    final r = await ApiService._client.get(Uri.parse('${ApiService._base}/billing/stats/$lgaId'), headers: h);
    return jsonDecode(r.body);
  }

  static Future<List<dynamic>> getInvoices(String lgaId) async {
    final h = await ApiService._authHeaders();
    final r = await ApiService._client.get(Uri.parse('${ApiService._base}/billing/invoices/$lgaId'), headers: h);
    if (r.statusCode == 200) return jsonDecode(r.body) as List;
    return [];
  }

  static Future<Map<String, dynamic>> generateBulkInvoices({
    required String lgaId, required String zone,
    required double amount, required int householdCount, required String billingPeriod,
  }) async {
    final h = await ApiService._authHeaders();
    final r = await ApiService._client.post(
      Uri.parse('${ApiService._base}/billing/invoice/bulk'), headers: h,
      body: jsonEncode({'lga_id': lgaId, 'zone': zone, 'amount': amount,
          'household_count': householdCount, 'billing_period': billingPeriod}),
    );
    return jsonDecode(r.body);
  }

  static Future<Map<String, dynamic>> payInvoice(String invoiceId, double amount) async {
    final h = await ApiService._authHeaders();
    final r = await ApiService._client.post(
      Uri.parse('${ApiService._base}/billing/invoice/$invoiceId/pay'), headers: h,
      body: jsonEncode({'payment_method': 'eco_credits', 'amount': amount}),
    );
    return jsonDecode(r.body);
  }
}

// ── CONTRACTORS ───────────────────────────────────────────────────────────────
extension ContractorApi on ApiService {
  static Future<Map<String, dynamic>> getLiveContractors(String lgaId) async {
    final h = await ApiService._authHeaders();
    final r = await ApiService._client.get(
      Uri.parse('${ApiService._base}/contractors/live?lga_id=$lgaId'), headers: h);
    if (r.statusCode == 200) return jsonDecode(r.body);
    return {'contractors': []};
  }

  static Future<Map<String, dynamic>> getContractorReport(String lgaId) async {
    final h = await ApiService._authHeaders();
    final r = await ApiService._client.get(
      Uri.parse('${ApiService._base}/contractors/report/$lgaId'), headers: h);
    if (r.statusCode == 200) return jsonDecode(r.body);
    return {};
  }
}

// ── PAYSTACK ──────────────────────────────────────────────────────────────────
extension PaystackApi on ApiService {
  static Future<Map<String, dynamic>> initializePayment({
    required double amount, required String purpose, String? invoiceId,
  }) async {
    final h = await ApiService._authHeaders();
    final r = await ApiService._client.post(
      Uri.parse('${ApiService._base}/paystack/initialize'), headers: h,
      body: jsonEncode({'amount': amount, 'purpose': purpose, if (invoiceId != null) 'invoice_id': invoiceId}),
    );
    return jsonDecode(r.body);
  }

  static Future<Map<String, dynamic>> verifyPayment(String reference) async {
    final r = await ApiService._client.get(Uri.parse('${ApiService._base}/paystack/verify/$reference'), headers: await ApiService._authHeaders());
    return jsonDecode(r.body);
  }

  static Future<List<dynamic>> getBanks() async {
    final r = await ApiService._client.get(Uri.parse('${ApiService._base}/paystack/banks'));
    if (r.statusCode == 200) return jsonDecode(r.body)['banks'] as List;
    return [];
  }
}
