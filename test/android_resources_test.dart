import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the Android resource XML that the Flutter test suite otherwise never
/// looks at. A malformed resource only surfaces during `assembleDebug`, which
/// runs in CI — so a cheap check here turns a slow red build into a fast test
/// failure.
void main() {
  final androidDir = Directory('android');

  List<File> androidXmlFiles() => androidDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.xml'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('android resource XML exists to check', () {
    expect(androidDir.existsSync(), isTrue);
    expect(androidXmlFiles(), isNotEmpty);
  });

  test('no XML comment contains a double hyphen', () {
    // The XML spec forbids "--" inside a comment. AAPT2 rejects it with
    // "The string "--" is not permitted within comments" and fails the build.
    // This bit us with a comment naming the "--ln-surface" design token.
    final offenders = <String>[];

    for (final file in androidXmlFiles()) {
      final source = file.readAsStringSync();
      for (final match
          in RegExp(r'<!--(.*?)-->', dotAll: true).allMatches(source)) {
        final body = match.group(1)!;
        if (body.contains('--')) {
          final line = '\n'.allMatches(source.substring(0, match.start)).length + 1;
          offenders.add('${file.path}:$line — <!--${body.trim()}-->');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'XML comments must not contain "--"; AAPT2 rejects them:\n'
          '${offenders.join('\n')}',
    );
  });

  test('every XML file is well-formed enough to have balanced comments', () {
    // An unterminated comment swallows the rest of the document; catch the
    // simple case of unbalanced comment delimiters.
    for (final file in androidXmlFiles()) {
      final source = file.readAsStringSync();
      final opens = '<!--'.allMatches(source).length;
      final closes = '-->'.allMatches(source).length;
      expect(
        opens,
        closes,
        reason: '${file.path} has $opens "<!--" but $closes "-->"',
      );
    }
  });
}
