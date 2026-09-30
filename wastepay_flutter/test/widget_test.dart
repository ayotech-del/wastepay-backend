import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wastepay/main.dart';
import 'package:wastepay/screens/auth_screen.dart';
import 'package:wastepay/screens/profile_screen.dart';
import 'package:wastepay/screens/government_screen.dart';
import 'package:wastepay/screens/contractor/verified_routes_screen.dart';
import 'package:wastepay/screens/bin_lookup_screen.dart';
import 'package:wastepay/screens/home_screen.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('Signed-out startup opens the login screen', (tester) async {
    await tester.pumpWidget(const WastePayApp());
    expect(find.text('WastePay'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Disposing the splash before its delay finishes is safe',
      (tester) async {
    await tester.pumpWidget(const WastePayApp());
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1400));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Government menu opens the dashboard', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('State Dashboard'), 300);
    await Scrollable.ensureVisible(tester.element(find.text('State Dashboard')), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(find.text('State Dashboard'));
    await tester.pumpAndSettle();
    expect(find.byType(GovernmentScreen), findsOneWidget);
    expect(find.text('Government dashboard'), findsOneWidget);
  });

  testWidgets('Contractor registration opens its screen', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Contractor registration'), 300);
    await Scrollable.ensureVisible(tester.element(find.text('Contractor registration')), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Contractor registration'));
    await tester.pumpAndSettle();
    expect(find.byType(GovernmentScreen), findsOneWidget);
    expect(find.text('Contractor registration'), findsOneWidget);
  });

  testWidgets('Driver menu opens assigned routes', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Contractor Driver App'), 300);
    await Scrollable.ensureVisible(tester.element(find.text('Contractor Driver App')), alignment: 0.5);
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

}
