import 'dart:typed_data';
import 'dart:ui' as ui;

bool imageDimensionsFit(int width, int height) => width > 0 && height > 0 &&
    width <= 4096 && height <= 4096 && width * height <= 8000000;

Future<void> validateEncodedImage(Uint8List bytes) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  try {
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    try {
      if (!imageDimensionsFit(descriptor.width, descriptor.height)) {
        throw StateError('أبعاد الصورة كبيرة لهذه النسخة. الحد 4096 لكل ضلع و8 ملايين بكسل إجمالًا.');
      }
    } finally { descriptor.dispose(); }
  } finally { buffer.dispose(); }
}
