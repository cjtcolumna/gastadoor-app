import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gastadoor/features/accounts/domain/ph_banks.dart';

String? bank(String name) => bankForName(name)?.id;

void main() {
  test('capitals, spaces and dashes do not matter', () {
    for (final name in ['GoTyme', 'gotyme', 'GOTYME', 'Go Tyme', 'Go-Tyme']) {
      expect(bank(name), 'gotyme', reason: name);
    }
  });

  test('extra words around the bank name still match', () {
    expect(bank('BDO Savings'), 'bdo');
    expect(bank('My GCash'), 'gcash');
    expect(bank('BPI Payroll'), 'bpi');
    expect(bank('Metro Bank'), 'metrobank');
    expect(bank('Security Bank Checking'), 'securitybank');
  });

  test('other names people use', () {
    expect(bank('PayMaya'), 'maya');
    expect(bank('SeaBank'), 'maribank');
    expect(bank('Banco de Oro'), 'bdo');
    expect(bank('Land Bank of the Philippines'), 'landbank');
    expect(bank('Philippine National Bank'), 'pnb');
  });

  test('only whole words count', () {
    expect(bank('Mayaman Fund'), isNull); // not Maya
    expect(bank('Cash'), isNull); // not GCash
    expect(bank('Securities'), isNull);
    expect(bank('Emergency Fund'), isNull);
  });

  test('banks not in the list get nothing', () {
    expect(bank('Maybank'), isNull);
    expect(bank('HSBC'), isNull);
    expect(bank('DBP'), isNull);
    expect(bank('Tonik'), isNull);
  });

  test('the longer match wins', () {
    // "Bank of the Philippine Islands" also contains "Philippine".
    expect(bank('Bank of the Philippine Islands'), 'bpi');
    expect(bank('Philippine Savings Bank'), 'psbank');
  });

  test('every bank has its icon file', () {
    for (final b in phBanks) {
      expect(File(b.iconAsset).existsSync(), isTrue, reason: b.iconAsset);
    }
  });

  test('ids are unique', () {
    final ids = phBanks.map((b) => b.id).toList();
    expect(ids.toSet().length, ids.length);
  });
}
