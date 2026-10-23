import 'package:flutter_test/flutter_test.dart';
import 'package:gastadoor/features/accounts/presentation/account_form_sheet.dart';

void main() {
  test('no warning when the balance is zero', () {
    final text = archiveMessage('Cash', 0);
    expect(text, isNot(contains('still')));
    expect(text, contains('restore it'));
  });

  test('warns when the account still has money', () {
    final text = archiveMessage('GCash', 150000);
    expect(text, startsWith('GCash still has ₱1,500.00.'));
    expect(text, contains('no longer count in your net worth'));
  });

  test('warns when the account still owes money', () {
    final text = archiveMessage('BPI Card', -12050);
    expect(text, startsWith('BPI Card still owes ₱120.50.'));
  });

  test('mentions the sub-accounts that get archived too', () {
    expect(
      archiveMessage('GoTyme', 0, pockets: 1),
      startsWith('Its sub-account will be archived too.'),
    );
    expect(
      archiveMessage('GoTyme', 5900000, pockets: 2),
      contains('Its 2 sub-accounts will be archived too.'),
    );
  });
}
