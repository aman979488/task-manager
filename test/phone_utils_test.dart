import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/features/call_history/utils/phone_utils.dart';

void main() {
  group('PhoneUtils.normalize', () {
    test('adds India country code to a 10-digit local number', () {
      expect(PhoneUtils.normalize('9794887387'), '919794887387');
    });

    test('preserves an explicit international country code', () {
      expect(PhoneUtils.normalize('+91 97948 87387'), '919794887387');
      expect(PhoneUtils.normalize('+1 202 555 0123'), '12025550123');
    });

    test('converts an international 00 prefix', () {
      expect(PhoneUtils.normalize('0091 97948 87387'), '919794887387');
    });

    test('converts a local number with a leading zero', () {
      expect(PhoneUtils.normalize('09794887387'), '919794887387');
    });

    test('returns an empty string when there are no digits', () {
      expect(PhoneUtils.normalize(''), isEmpty);
      expect(PhoneUtils.normalize('---'), isEmpty);
    });
  });
}
