import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wastepay/main.dart';
import 'package:wastepay/services/api_service.dart';
import 'package:wastepay/screens/auth_screen.dart';
import 'package:wastepay/screens/profile_screen.dart';
import 'package:wastepay/screens/government_screen.dart';
import 'package:wastepay/screens/company_dashboard_screen.dart';
import 'package:wastepay/screens/role_home_screen.dart';
import 'package:wastepay/screens/contractor/verified_routes_screen.dart';
import 'package:wastepay/screens/bin_lookup_screen.dart';
import 'package:wastepay/screens/home_screen.dart';
import 'package:wastepay/screens/operations_screen.dart';

Map<String, dynamic> profile(String role) {
  final permissions = switch (role) {
    'platform_admin' => [
        'government.view',
        'government.operations',
        'government.finance',
        'access.manage'
      ],
    'lga_admin' => [
        'government.view',
        'government.operations',
        'government.finance'
      ],
    'government_supervisor' => ['government.view'],
    'government_operations' => ['government.view', 'government.operations'],
    'government_finance' => ['government.view', 'government.finance'],
    'contractor_manager' => ['company.view', 'company.manage'],
    'driver' => ['driver.work'],
    _ => <String>[],
  };
  return {
    'id': 'test-user',
    'full_name': 'Test User',
    'phone': '+2348000000000',
    'kyc_tier': 'tier_1',
    'role': role,
    'roles': [role],
    'permissions': permissions,
    'grants': [
      {
        'id': 'grant',
        'role': role,
        'scope_kind': role == 'contractor_manager' || role == 'driver'
            ? 'company'
            : 'lga',
        'scope_value': role == 'contractor_manager' || role == 'driver'
            ? 'companyA'
            : 'lga',
        'permissions': permissions
      }
    ],
    'permission_lga_ids': {
      for (final permission in [
        'government.view',
        'government.operations',
        'government.finance'
      ])
        permission: permissions.contains(permission) ? ['lga'] : []
    }
  };
}

void main() {
  late Map<String, dynamic> currentProfile;
  late List<dynamic> jobs;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    currentProfile = profile('citizen');
    jobs = [];
    ApiService.setHttpClientForTesting(MockClient((request) async {
      final path = request.url.path;
      dynamic data;
      if (path == '/users/me') {
        data = currentProfile;
      } else if (path == '/government/my-lgas') {
        data = {
          'lgas': [
            {'id': 'lga', 'name': 'Test LGA', 'state': 'Lagos'}
          ]
        };
      } else if (path == '/government/dashboard/lga') {
        data = {
          'billing': {
            'total_billed': 80,
            'total_collected': 0,
            'collection_rate': 0
          },
          'performance': {'total_kg_collected': 0},
          'live': {'active_contractors': 0},
          'bins': 1,
          'alerts': []
        };
      } else if (path == '/organizations/companies') {
        data = [
          {
            'id': 'companyA',
            'name': 'Company A',
            'lga_ids': ['lga']
          }
        ];
      } else if (path.endsWith('/dashboard')) {
        data = {
          'company': {
            'id': 'companyA',
            'name': 'Company A',
            'lga_ids': ['lga']
          },
          'manage_allowed': (currentProfile['permissions'] as List)
                  .contains('company.manage') ||
              (currentProfile['permissions'] as List)
                  .contains('government.operations'),
          'drivers': [],
          'vehicles': [],
          'jobs': jobs,
          'routes': [],
          'contracts': [],
          'invoices': [],
          'pickup_requests': []
        };
      } else if (path == '/organizations/jobs/mine') {
        data = jobs;
      } else if (path == '/wallet/balance') {
        data = {
          'eco_credits': 0,
          'total_earned': 0,
          'total_redeemed': 0,
          'kg_deposited': 0
        };
      } else if (path == '/waste/rates') {
        data = {
          'rates_ngn_per_kg': {'plastic': 400}
        };
      } else {
        data = [];
      }
      return http.Response(jsonEncode(data), 200,
          headers: {'content-type': 'application/json'});
    }));
  });

  testWidgets('Signed-out startup opens the login screen', (tester) async {
    await tester.pumpWidget(const WastePayApp());
    expect(find.text('WastePay'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Disposing splash before delay finishes is safe', (tester) async {
    await tester.pumpWidget(const WastePayApp());
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1400));
    expect(tester.takeException(), isNull);
  });
  testWidgets('Government profile menu opens dashboard', (tester) async {
    currentProfile = profile('lga_admin');
    await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('State Dashboard'));
    await tester.pumpAndSettle();
    expect(find.byType(GovernmentScreen), findsOneWidget);
    expect(find.text('Add smart bin'), findsOneWidget);
  });
  testWidgets('Contractor registration opens government approval screen',
      (tester) async {
    currentProfile = profile('government_operations');
    await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Contractor registration'));
    await tester.pumpAndSettle();
    expect(find.byType(GovernmentScreen), findsOneWidget);
    expect(find.text('Approve contractor company'), findsOneWidget);
  });
  testWidgets('Driver menu opens only assigned routes', (tester) async {
    currentProfile = profile('driver');
    await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Contractor Driver App'));
    await tester.pumpAndSettle();
    expect(find.byType(VerifiedRoutesScreen), findsOneWidget);
  });
  testWidgets('Deposit lookup accepts a printed code or ID', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DepositScreen()));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Find bin / Scan QR'));
    await tester.tap(find.text('Find bin / Scan QR'));
    await tester.pumpAndSettle();
    expect(find.byType(BinLookupScreen), findsOneWidget);
    await tester.tap(find.text('Find bin'));
    await tester.pump();
    expect(find.text('Enter a bin code or ID'), findsOneWidget);
  });
  testWidgets('Consumer cannot see staff or company menus', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
    await tester.pumpAndSettle();
    expect(find.text('State Dashboard'), findsNothing);
    expect(find.text('My contractor company'), findsNothing);
    expect(find.text('Manage user roles'), findsNothing);
    expect(find.text('Contractor Driver App'), findsNothing);
    expect(find.text('My bills & pickups'), findsOneWidget);
  });
  testWidgets('Company manager cannot see government or role management',
      (tester) async {
    currentProfile = profile('contractor_manager');
    await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
    await tester.pumpAndSettle();
    expect(find.text('My contractor company'), findsOneWidget);
    expect(find.text('State Dashboard'), findsNothing);
    expect(find.text('Manage user roles'), findsNothing);
    expect(find.text('Contractor Driver App'), findsNothing);
  });
  testWidgets('Government supervisor has view access without edit buttons',
      (tester) async {
    currentProfile = profile('government_supervisor');
    await tester.pumpWidget(const MaterialApp(home: GovernmentScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Government dashboard'), findsOneWidget);
    expect(find.text('Companies, tracking & payments'), findsOneWidget);
    expect(find.text('Add smart bin'), findsNothing);
    expect(find.text('Approve contractor company'), findsNothing);
    expect(find.text('Manage user roles'), findsNothing);
  });
  testWidgets('Finance dashboard hides operations controls', (tester) async {
    currentProfile = profile('government_finance');
    await tester.pumpWidget(const MaterialApp(home: GovernmentScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Add smart bin'), findsNothing);
    expect(find.text('Approve contractor company'), findsNothing);
  });
  for (final role in [
    'government_supervisor',
    'contractor_manager',
    'driver',
    'citizen'
  ]) {
    testWidgets('Login landing follows $role access', (tester) async {
      currentProfile = profile(role);
      await tester.pumpWidget(const MaterialApp(home: RoleHomeScreen()));
      await tester.pumpAndSettle();
      if (role == 'government_supervisor') {
        expect(find.byType(GovernmentScreen), findsOneWidget);
      } else if (role == 'contractor_manager') {
        expect(find.byType(CompanyDashboardScreen), findsOneWidget);
      } else if (role == 'driver') {
        expect(find.byType(VerifiedRoutesScreen), findsOneWidget);
      } else {
        expect(find.byType(HomeScreen), findsOneWidget);
      }
    });
  }
  testWidgets('Consumers see payment and collection as independent statuses',
      (tester) async {
    jobs = [
      {
        'id': 'job',
        'bin_code': 'BIN-1',
        'driver': 'Driver A',
        'address': '12 Test Street',
        'collection_status': 'assigned',
        'payment_status': 'paid'
      }
    ];
    await tester.pumpWidget(const MaterialApp(home: OperationsScreen()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('BIN-1 ? Driver A'), 200, scrollable: find.byType(Scrollable).first);
    expect(
        find.textContaining('Pickup: assigned | Bill: paid'), findsOneWidget);
  });
}
