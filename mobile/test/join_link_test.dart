import 'package:flutter_test/flutter_test.dart';
import 'package:vapen/core/join_link.dart';

void main() {
  test('tryParse accepts https invite from any host', () {
    final invite = JoinInviteLink.tryParse(
      Uri.parse('https://vapen.home.example/join/abcdefghij'),
    );
    expect(invite, isNotNull);
    expect(invite!.origin, 'https://vapen.home.example');
    expect(invite.code, 'abcdefghij');
  });

  test('tryParse accepts http on private host', () {
    final invite = JoinInviteLink.tryParse(
      Uri.parse('http://192.168.1.10/join/1234567890'),
    );
    expect(invite, isNotNull);
    expect(invite!.origin, 'http://192.168.1.10');
  });

  test('tryParse rejects wrong code length', () {
    expect(
      JoinInviteLink.tryParse(Uri.parse('https://a.example/join/short')),
      isNull,
    );
  });
}
