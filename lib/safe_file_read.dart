import 'dart:io';
import 'dart:typed_data';

Future<Uint8List> readLimitedFile(File file, int limit) async {
  if (limit < 0) throw ArgumentError.value(limit);
  final builder = BytesBuilder(copy: false);
  await for (final chunk in file.openRead()) {
    if (builder.length + chunk.length > limit) {
      throw StateError('تجاوز الملف حد القراءة المسموح.');
    }
    builder.add(chunk);
  }
  return builder.takeBytes();
}
