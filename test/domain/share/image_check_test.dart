import 'dart:typed_data';

import 'package:fitapp/domain/share/image_check.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _rgba(int w, int h, {int alpha = 0}) {
  final b = Uint8List(w * h * 4);
  for (var i = 3; i < b.length; i += 4) {
    b[i] = alpha;
  }
  return b;
}

void main() {
  test('a fully transparent image is blank', () {
    expect(isBlankImage(_rgba(30, 40), width: 30, height: 40), isTrue);
  });

  test('an opaque image is not blank', () {
    expect(
      isBlankImage(_rgba(30, 40, alpha: 255), width: 30, height: 40),
      isFalse,
    );
  });

  test('one opaque corner is enough', () {
    final b = _rgba(30, 40);
    b[((40 - 1) * 30 + (30 - 1)) * 4 + 3] = 255; // bottom-right
    expect(isBlankImage(b, width: 30, height: 40), isFalse);
  });

  test('an opaque centre is enough', () {
    final b = _rgba(31, 41);
    b[(20 * 31 + 15) * 4 + 3] = 128;
    expect(isBlankImage(b, width: 31, height: 41), isFalse);
  });

  test('empty or mismatched data counts as blank', () {
    expect(isBlankImage(Uint8List(0), width: 0, height: 0), isTrue);
    expect(isBlankImage(Uint8List(8), width: 10, height: 10), isTrue);
  });
}
