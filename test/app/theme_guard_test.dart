import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Feature 034 (SC-001): nothing of the previous look may remain.
void main() {
  const oldPalette = [
    '1C1C1E', '2C2C2E', '8E8E93', '5A5A5F', '11D16C', '2BE07F', '7CF5B0',
    '64D2FF', 'FF9F0A', 'FF453A', 'FFD60A', '14261C',
  ];
  final banned = <String, RegExp>{
    'stock Material icon': RegExp(r'\bIcons\.'),
    'circle shape': RegExp(r'BoxShape\.circle|CircleBorder|CircleAvatar'),
    'pill shape': RegExp(r'StadiumBorder|Radii\.pill'),
    'rounded corner': RegExp(r'Radius\.circular\(\s*([5-9]|\d{2,})'),
    'pure black': RegExp('0x[0-9A-Fa-f]{2}000000'),
    'old palette': RegExp(
      '0x[0-9A-Fa-f]{2}(${oldPalette.join('|')})',
      caseSensitive: false,
    ),
  };

  List<File> dartFiles(String dir) => Directory(dir)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  for (final dir in ['lib', 'test']) {
    test('no leftover of the old look in $dir/', () {
      final hits = <String>[];
      for (final file in dartFiles(dir)) {
        if (file.path.endsWith('theme_guard_test.dart')) continue;
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          for (final MapEntry(:key, :value) in banned.entries) {
            if (value.hasMatch(lines[i])) {
              hits.add('${file.path}:${i + 1} $key: ${lines[i].trim()}');
            }
          }
        }
      }
      expect(hits, isEmpty, reason: hits.join('\n'));
    });
  }

  test('launcher and splash use soot', () {
    for (final path in [
      'flutter_launcher_icons.yaml',
      'flutter_native_splash.yaml',
    ]) {
      final text = File(path).readAsStringSync();
      expect(text, isNot(contains('#000000')), reason: path);
      expect(text, contains('#15120F'), reason: path);
    }
  });
}
