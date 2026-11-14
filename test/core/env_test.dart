import 'package:fitapp/core/env.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sync is not configured without dart-defines', () {
    expect(Env.isSyncConfigured, isFalse);
  });
}
