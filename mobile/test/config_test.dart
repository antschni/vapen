import 'package:flutter_test/flutter_test.dart';
import 'package:vapen/core/config.dart';

void main() {
  test('normalizeBaseUrl trims slashes', () {
    expect(normalizeBaseUrl(' https://example.com/ '), 'https://example.com');
  });

  test('isAllowedBaseUrl allows https in release', () {
    expect(isAllowedBaseUrl('https://vapen.example.com', isRelease: true), isTrue);
  });

  test('isAllowedBaseUrl allows private http in release', () {
    expect(isAllowedBaseUrl('http://192.168.1.10:8080', isRelease: true), isTrue);
  });

  test('isAllowedBaseUrl rejects public http in release', () {
    expect(isAllowedBaseUrl('http://vapen.example.com', isRelease: true), isFalse);
  });
}
