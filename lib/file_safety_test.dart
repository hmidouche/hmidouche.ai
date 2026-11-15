import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamidouch_ai/safe_file_read.dart';
import 'package:hamidouch_ai/model_file_check.dart';
import 'package:hamidouch_ai/image_safety.dart';

void main() {
  late Directory temp;
  setUp(() async { temp = await Directory.systemTemp.createTemp('hmidouche_test_'); });
  tearDown(() async { await temp.delete(recursive: true); });
  test('Bounded reading accepts exact limit and rejects overflow', () async {
    final file = File('${temp.path}/sample.bin');
    await file.writeAsBytes([1, 2, 3, 4]);
    expect(await readLimitedFile(file, 4), [1, 2, 3, 4]);
    await expectLater(readLimitedFile(file, 3), throwsStateError);
  });
  test('A renamed non-GGUF file is rejected', () async {
    final file = File('${temp.path}/fake.gguf');
    await file.writeAsString('not a model');
    await expectLater(checkGgufHeader(file.path), throwsStateError);
  });
  test('A header alone does not establish SDXS identity', () async {
    final file = File('${temp.path}/fake-sdxs.gguf');
    await file.writeAsBytes([0x47, 0x47, 0x55, 0x46]);
    await checkGgufHeader(file.path);
    await expectLater(checkSdxsFile(file.path, () => true), throwsStateError);
  });
  test('Image dimension and pixel limits', () {
    expect(imageDimensionsFit(512, 512), isTrue);
    expect(imageDimensionsFit(0, 512), isFalse);
    expect(imageDimensionsFit(5000, 100), isFalse);
    expect(imageDimensionsFit(4096, 4096), isFalse);
  });
}
