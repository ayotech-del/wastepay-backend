// WastePay — Data Models

class AuthResult {
  final bool success;
  final String? error;
  final String? accessToken;
  final String? userId;
  final String? fullName;
  final String? kycTier;

  AuthResult._({required this.success, this.error, this.accessToken, this.userId, this.fullName, this.kycTier});

  factory AuthResult.success(Map<String, dynamic> data) => AuthResult._(
    success: true,
    accessToken: data['access_token'],
    userId: data['user_id'],
    fullName: data['full_name'],
    kycTier: data['kyc_tier'],
  );

  factory AuthResult.error(String msg) => AuthResult._(success: false, error: msg);
}

class WalletBalance {
  final double ecoCredits;
  final double totalEarned;
  final double totalRedeemed;
  final double kgDeposited;

  WalletBalance({
    required this.ecoCredits,
    required this.totalEarned,
    required this.totalRedeemed,
    required this.kgDeposited,
  });

  factory WalletBalance.fromJson(Map<String, dynamic> j) => WalletBalance(
    ecoCredits:    (j['eco_credits']    as num).toDouble(),
    totalEarned:   (j['total_earned']   as num).toDouble(),
    totalRedeemed: (j['total_redeemed'] as num).toDouble(),
    kgDeposited:   (j['kg_deposited']   as num).toDouble(),
  );

  WalletBalance copyWith({double? ecoCredits, double? kgDeposited}) => WalletBalance(
    ecoCredits:    ecoCredits    ?? this.ecoCredits,
    totalEarned:   totalEarned,
    totalRedeemed: totalRedeemed,
    kgDeposited:   kgDeposited   ?? this.kgDeposited,
  );
}

class WalletTransaction {
  final String id;
  final String type;
  final double amount;
  final String? description;
  final String status;
  final String createdAt;

  WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    this.description,
    required this.status,
    required this.createdAt,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> j) => WalletTransaction(
    id:          j['id'] ?? '',
    type:        j['type'] ?? '',
    amount:      (j['amount'] as num).toDouble(),
    description: j['description'],
    status:      j['status'] ?? '',
    createdAt:   j['created_at'] ?? '',
  );

  bool get isCredit => type == 'credit_earned';
}

class DepositResult {
  final bool success;
  final String? error;
  final String? depositId;
  final String? wasteType;
  final double? weightKg;
  final double? creditValue;
  final double? newBalance;
  final String? message;

  DepositResult._({required this.success, this.error, this.depositId, this.wasteType,
      this.weightKg, this.creditValue, this.newBalance, this.message});

  factory DepositResult.success(Map<String, dynamic> d) => DepositResult._(
    success: true,
    depositId:   d['deposit_id'],
    wasteType:   d['waste_type'],
    weightKg:    (d['weight_kg'] as num?)?.toDouble(),
    creditValue: (d['credit_value'] as num?)?.toDouble(),
    newBalance:  (d['new_balance'] as num?)?.toDouble(),
    message:     d['message'],
  );

  factory DepositResult.error(String msg) => DepositResult._(success: false, error: msg);
}

class RedeemResult {
  final bool success;
  final String? error;
  final String? reference;
  final String? message;

  RedeemResult._({required this.success, this.error, this.reference, this.message});

  factory RedeemResult.success(Map<String, dynamic> d) => RedeemResult._(
    success: true, reference: d['reference'], message: d['message']);

  factory RedeemResult.error(String msg) => RedeemResult._(success: false, error: msg);
}

class SmartBinInfo {
  final String id;
  final String code;
  final String address;
  final double lat;
  final double lng;
  final int fillPercent;
  final String status;

  SmartBinInfo({
    required this.id,
    required this.code,
    required this.address,
    required this.lat,
    required this.lng,
    required this.fillPercent,
    required this.status,
  });

  factory SmartBinInfo.fromJson(Map<String, dynamic> j) => SmartBinInfo(
    id:          j['id'] ?? '',
    code:        j['bin_code'] ?? '',
    address:     j['address'] ?? '',
    lat:         (j['latitude']    as num).toDouble(),
    lng:         (j['longitude']   as num).toDouble(),
    fillPercent: (j['fill_percent'] as num).toInt(),
    status:      j['status'] ?? 'active',
  );

  bool get isFull   => fillPercent >= 85 || status == 'full';
  bool get isActive => status == 'active';

  String get fillIcon {
    if (fillPercent >= 85) return '🔴';
    if (fillPercent >= 50) return '🟡';
    return '🟢';
  }
}
