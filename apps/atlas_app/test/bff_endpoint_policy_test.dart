import 'package:atlas_app/features/ai/data/bff_endpoint_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('allows https and loopback http bff addresses', () {
    expect(
      validateBffUrl('https://atlas.example.com/'),
      'https://atlas.example.com',
    );
    expect(validateBffUrl('http://127.0.0.1:8787'), 'http://127.0.0.1:8787');
  });

  test('rejects non-loopback plaintext bff addresses', () {
    expect(
      () => validateBffUrl('http://192.168.1.5:8787'),
      throwsFormatException,
    );
  });
}
