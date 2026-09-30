import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:wastepay/services/api_service.dart';
import 'package:wastepay/screens/contractor_bills_screen.dart';

void main() {
  testWidgets(
      'Customers select real contractor names and only see its own bills',
      (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    String? selected;
    ApiService.setHttpClientForTesting(MockClient((request) async {
      dynamic result;
      switch (request.url.path) {
        case '/organizations/contractor-directory':
          result = [
            {
              'id': 'a',
              'name': 'Alpha Waste',
              'areas': [
                {'state': 'Lagos', 'lga': 'Ikeja'}
              ]
            },
            {
              'id': 'b',
              'name': 'Beta Waste',
              'areas': [
                {'state': 'Ogun', 'lga': 'Abeokuta'}
              ]
            }
          ];
          break;
        case '/billing/my-invoices':
          result = [
            {
              'id': 'ia',
              'invoice_number': 'ALPHA-BILL',
              'contractor_id': 'a',
              'billing_period': '2026-10',
              'status': 'sent',
              'balance': 100
            },
            {
              'id': 'ib',
              'invoice_number': 'BETA-BILL',
              'contractor_id': 'b',
              'billing_period': '2026-10',
              'status': 'sent',
              'balance': 200
            }
          ];
          break;
        case '/organizations/contractor-selection':
          if (request.method == 'PUT') {
            selected = jsonDecode(request.body)['company_id'];
          }
          result = {'company_id': selected};
          break;
        default:
          result = {'email': 'customer@example.com'};
      }
      return http.Response(jsonEncode(result), 200);
    }));
    await tester.pumpWidget(const MaterialApp(home: ContractorBillsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Alpha Waste'), findsOneWidget);
    expect(find.text('Beta Waste'), findsOneWidget);
    expect(find.text('ALPHA-BILL'), findsNothing);
    await tester.tap(find.text('Select').first);
    await tester.pumpAndSettle();
    expect(selected, 'a');
    expect(find.text('ALPHA-BILL'), findsOneWidget);
    expect(find.text('BETA-BILL'), findsNothing);
    expect(find.text('Bank transfer'), findsOneWidget);
    expect(find.text('Debit card'), findsOneWidget);
    expect(find.text('Eco Credits'), findsNothing);
    await tester.enterText(
        find.widgetWithText(TextField, 'Search contractor by name'), 'Beta');
    await tester.pumpAndSettle();
    expect(find.text('Alpha Waste'), findsNothing);
    expect(find.text('Beta Waste'), findsOneWidget);
  });
}
