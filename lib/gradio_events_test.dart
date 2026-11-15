import 'package:flutter_test/flutter_test.dart';
import 'package:hamidouch_ai/gradio_events.dart';

void main() {
  test('Complete event split across network chunks', () async {
    final result = await parseGradioResult(Stream.fromIterable([
      'event: comp', 'lete\ndata: [{"url":"https://example.invalid/image.png"}]\n\n',
    ]));
    expect(result.first['url'], 'https://example.invalid/image.png');
  });
  test('Null error event is not treated as success', () async {
    await expectLater(parseGradioResult(Stream.value('event: error\ndata: null\n\n')), throwsStateError);
  });
  test('Interrupted stream cannot return a fake result', () async {
    await expectLater(parseGradioResult(Stream.value('event: heartbeat\ndata: null\n\n')), throwsStateError);
  });
  test('Handles completion at end of stream', () async {
    final result = await parseGradioResult(Stream.value('event: complete\ndata: [42]'));
    expect(result, [42]);
  });
  test('Rejects empty completion payload', () async {
    await expectLater(parseGradioResult(Stream.value('event: complete\ndata: []\n\n')), throwsStateError);
  });
}
