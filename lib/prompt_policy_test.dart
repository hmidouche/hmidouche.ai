import 'package:flutter_test/flutter_test.dart';
import 'package:hamidouch_ai/prompt_policy.dart';

void main() {
  test('Java and Dart source files are accepted', () {
    expect(supportsTextFile('Main.java'), isTrue);
    expect(supportsTextFile('MAIN.JAVA'), isTrue);
    expect(supportsTextFile('main.dart'), isTrue);
  });
  test('Binary, image and extensionless files are rejected', () {
    expect(supportsTextFile('photo.png'), isFalse);
    expect(supportsTextFile('book.pdf'), isFalse);
    expect(supportsTextFile('java'), isFalse);
    expect(supportsTextFile('fake.java.exe'), isFalse);
  });
  test('File size boundaries', () {
    expect(fileFits(0), isTrue);
    expect(fileFits(65536), isTrue);
    expect(fileFits(65537), isFalse);
    expect(fileFits(-1), isFalse);
  });
  test('Rendered prompt budget reserves 768 tokens', () {
    expect(contextFits(3328), isTrue);
    expect(contextFits(3329), isFalse);
    expect(contextFits(null), isFalse);
    expect(contextFits(-1), isFalse);
  });
  test('Prompt size boundaries', () {
    expect(promptFits('x' * 10000), isTrue);
    expect(promptFits('x' * 10001), isFalse);
  });
}
